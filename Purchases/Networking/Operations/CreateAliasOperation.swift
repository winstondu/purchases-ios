//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  CreateAliasOperation.swift
//
//  Created by Joshua Liebowitz on 11/18/21.

import Foundation

class CreateAliasOperation: NetworkOperation {

    let aliasCallbackCache: CallbackCache<AliasCallback>
    let httpClient: HTTPClient
    let authHeaders: [String: String]

    init(httpClient: HTTPClient,
         authHeaders: [String: String],
         aliasCallbackCache: CallbackCache<AliasCallback>) {
        self.httpClient = httpClient
        self.authHeaders = authHeaders
        self.aliasCallbackCache = aliasCallbackCache
    }

    func createAlias(appUserID: String, newAppUserID: String, completion: PostRequestResponseHandler?) {
        guard let appUserID = try? appUserID.escapedOrError() else {
            completion?(ErrorUtils.missingAppUserIDError())
            return
        }

        let cacheKey = appUserID + newAppUserID
        let aliasCallback = AliasCallback(key: cacheKey, callback: completion)
        if aliasCallbackCache.add(callback: aliasCallback) == .addedToExistingInFlightList {
            return
        }

        Logger.user(Strings.identity.creating_alias(userA: appUserID, userB: newAppUserID))
        httpClient.performPOSTRequest(serially: true,
                                      path: "/subscribers/\(appUserID)/alias",
                                      requestBody: ["new_app_user_id": newAppUserID],
                                      headers: authHeaders) { statusCode, response, error in
            self.aliasCallbackCache.performOnAllItemsAndRemoveFromCache(withKey: cacheKey) { aliasCallback in
                self.handle(response: response,
                            statusCode: statusCode,
                            maybeError: error,
                            completion: aliasCallback.callback)
            }

        }

    }

}

extension CreateAliasOperation {

    func handle(response: [String: Any]?,
                statusCode: Int,
                maybeError: Error?,
                completion: PostRequestResponseHandler?) {
        if let error = maybeError {
            completion?(ErrorUtils.networkError(withUnderlyingError: error))
            return
        }

        guard let completion = completion else {
            return
        }

        guard statusCode <= HTTPStatusCodes.redirect.rawValue else {
            let backendErrorCode = BackendErrorCode(maybeCode: response?["code"])
            let message = response?["message"] as? String
            let responseError = ErrorUtils.backendError(withBackendCode: backendErrorCode, backendMessage: message)
            completion(responseError)
            return
        }

        completion(nil)
    }

}
