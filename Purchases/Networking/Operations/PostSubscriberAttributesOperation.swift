//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  PostSubscriberAttributesOperation.swift
//
//  Created by Joshua Liebowitz on 11/18/21.

import Foundation

class PostSubscriberAttributesOperation: NetworkOperation {

    let httpClient: HTTPClient
    let authHeaders: [String: String]
    let subscriberAttributesMarshaller: SubscriberAttributesMarshaller
    let subscriberAttributeHandler: SubscriberAttributeHandler

    init(httpClient: HTTPClient,
         authHeaders: [String: String],
         subscriberAttributesMarshaller: SubscriberAttributesMarshaller = SubscriberAttributesMarshaller(),
         subscriberAttributeHandler: SubscriberAttributeHandler = SubscriberAttributeHandler()) {
        self.httpClient = httpClient
        self.authHeaders = authHeaders
        self.subscriberAttributesMarshaller = subscriberAttributesMarshaller
        self.subscriberAttributeHandler = subscriberAttributeHandler
    }

    func post(subscriberAttributes: SubscriberAttributeDict,
              appUserID: String,
              completion: PostRequestResponseHandler?) {
        guard subscriberAttributes.count > 0 else {
            Logger.warn(Strings.attribution.empty_subscriber_attributes)
            completion?(ErrorCode.emptySubscriberAttributes)
            return
        }

        guard let appUserID = try? appUserID.escapedOrError() else {
            completion?(ErrorUtils.missingAppUserIDError())
            return
        }

        let path = "/subscribers/\(appUserID)/attributes"

        let attributesInBackendFormat = self.subscriberAttributesMarshaller
            .subscriberAttributesToDict(subscriberAttributes: subscriberAttributes)
        httpClient.performPOSTRequest(serially: true,
                                      path: path,
                                      requestBody: ["attributes": attributesInBackendFormat],
                                      headers: authHeaders) { statusCode, response, error in
            self.subscriberAttributeHandler.handleSubscriberAttributesResult(statusCode: statusCode,
                                                                             response: response,
                                                                             maybeError: error,
                                                                             completion: completion)
        }
    }

}
