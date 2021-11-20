//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  PostAttributionDataOperation.swift
//
//  Created by Joshua Liebowitz on 11/19/21.

import Foundation

class PostAttributionDataOperation: NetworkOperation {

    let httpClient: HTTPClient
    let authHeaders: [String: String]

    init(httpClient: HTTPClient, authHeaders: [String: String]) {
        self.httpClient = httpClient
        self.authHeaders = authHeaders
    }

    func post(attributionData: [String: Any],
              network: AttributionNetwork,
              appUserID: String,
              completion: PostRequestResponseHandler?) {
        guard let appUserID = try? appUserID.escapedOrError() else {
            completion?(ErrorUtils.missingAppUserIDError())
            return
        }

        let path = "/subscribers/\(appUserID)/attribution"
        let body: [String: Any] = ["network": network.rawValue, "data": attributionData]
        self.httpClient.performPOSTRequest(serially: true,
                                           path: path,
                                           requestBody: body,
                                           headers: self.authHeaders) { statusCode, response, error in
            self.handle(response: response, statusCode: statusCode, maybeError: error, completion: completion)
        }
    }

    private func handle(response: [String: Any]?,
                        statusCode: Int,
                        maybeError: Error?,
                        completion: PostRequestResponseHandler?) {
        if let error = maybeError {
            completion?(ErrorUtils.networkError(withUnderlyingError: error))
            return
        }

        guard statusCode <= HTTPStatusCodes.redirect.rawValue else {
            let backendErrorCode = BackendErrorCode(maybeCode: response?["code"])
            let message = response?["message"] as? String
            let responseError = ErrorUtils.backendError(withBackendCode: backendErrorCode, backendMessage: message)
            completion?(responseError)
            return
        }

        completion?(nil)
    }

}
