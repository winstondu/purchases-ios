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
    let postAttributionDataResponseHandler: PostAttributionDataResponseHandler

    init(httpClient: HTTPClient,
         authHeaders: [String: String],
         // swiftlint:disable:next line_length
         postAttributionDataResponseHandler: PostAttributionDataResponseHandler = PostAttributionDataResponseHandler()) {
        self.httpClient = httpClient
        self.authHeaders = authHeaders
        self.postAttributionDataResponseHandler = postAttributionDataResponseHandler
    }

    func post(attributionData: [String: Any],
              network: AttributionNetwork,
              appUserID: String,
              maybeCompletion: PostRequestResponseHandler?) {
        guard let appUserID = try? appUserID.escapedOrError() else {
            maybeCompletion?(ErrorUtils.missingAppUserIDError())
            return
        }

        let path = "/subscribers/\(appUserID)/attribution"
        let body: [String: Any] = ["network": network.rawValue, "data": attributionData]
        self.httpClient.performPOSTRequest(serially: true,
                                           path: path,
                                           requestBody: body,
                                           headers: self.authHeaders) { statusCode, response, error in
            guard let completion = maybeCompletion else {
                return
            }

            self.postAttributionDataResponseHandler.handle(maybeResponse: response,
                                                           statusCode: statusCode,
                                                           maybeError: error,
                                                           completion: completion)
        }
    }

}
