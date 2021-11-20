//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  LogInOperation.swift
//
//  Created by Joshua Liebowitz on 11/19/21.

import Foundation

class LogInOperation: NetworkOperation {

    let httpClient: HTTPClient
    let authHeaders: [String: String]
    private let loginCallbackCache: CallbackCache<LogInCallback>

    init(httpClient: HTTPClient, authHeaders: [String: String], loginCallbackCache: CallbackCache<LogInCallback>) {
        self.httpClient = httpClient
        self.authHeaders = authHeaders
        self.loginCallbackCache = loginCallbackCache
    }

    func logIn(currentAppUserID: String,
               newAppUserID: String,
               completion: @escaping LogInResponseHandler) {
        let cacheKey = currentAppUserID + newAppUserID

        let loginCallback = LogInCallback(key: cacheKey, callback: completion)
        if loginCallbackCache.add(callback: loginCallback) == .addedToExistingInFlightList {
            return
        }

        let requestBody = ["app_user_id": currentAppUserID, "new_app_user_id": newAppUserID]
        self.httpClient.performPOSTRequest(serially: true,
                                           path: "/subscribers/identify",
                                           requestBody: requestBody,
                                           headers: self.authHeaders) { statusCode, response, error in
            self.loginCallbackCache.performOnAllItemsAndRemoveFromCache(withKey: cacheKey) { callbackObject in
                self.handleLogin(maybeResponse: response,
                                 statusCode: statusCode,
                                 maybeError: error,
                                 completion: callbackObject.callback)
            }
        }
    }

    private func handleLogin(maybeResponse: [String: Any]?,
                             statusCode: Int,
                             maybeError: Error?,
                             completion: LogInResponseHandler) {
        if let error = maybeError {
            completion(nil, false, ErrorUtils.networkError(withUnderlyingError: error))
            return
        }

        guard let response = maybeResponse else {
            let subErrorCode = UnexpectedBackendResponseSubErrorCode.loginMissingResponse
            let responseError = ErrorUtils.unexpectedBackendResponse(withSubError: subErrorCode)
            completion(nil, false, responseError)
            return
        }

        if statusCode > HTTPStatusCodes.redirect.rawValue {
            let backendCode = BackendErrorCode(maybeCode: response["code"])
            let backendMessage = response["message"] as? String
            let responsError = ErrorUtils.backendError(withBackendCode: backendCode, backendMessage: backendMessage)
            completion(nil, false, ErrorUtils.networkError(withUnderlyingError: responsError))
            return
        }

        do {
            let customerInfo = try CustomerInfo(data: response)
            let created = statusCode == HTTPStatusCodes.createdSuccess.rawValue
            Logger.user(Strings.identity.login_success)
            completion(customerInfo, created, nil)
        } catch {
            Logger.error(Strings.backendError.customer_info_instantiation_error(maybeResponse: response))
            let subErrorCode = UnexpectedBackendResponseSubErrorCode.loginResponseDecoding
            let responseError = ErrorUtils.unexpectedBackendResponse(withSubError: subErrorCode)
            completion(nil, false, responseError)
        }
    }

}
