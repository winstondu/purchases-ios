//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  PostReceiptDataOperation.swift
//
//  Created by Joshua Liebowitz on 11/18/21.

import Foundation

class PostReceiptDataOperation: NetworkOperation {

    private let subscriberAttributesMarshaller: SubscriberAttributesMarshaller
    private let customerInfoResponseHandler: CustomerInfoResponseHandler
    private let customerInfoCallbackCache: CallbackCache<CustomerInfoCallback>

    init(configuration: Configuration,
         subscriberAttributesMarshaller: SubscriberAttributesMarshaller = SubscriberAttributesMarshaller(),
         customerInfoResponseHandler: CustomerInfoResponseHandler = CustomerInfoResponseHandler(),
         customerInfoCallbackCache: CallbackCache<CustomerInfoCallback>) {
        self.subscriberAttributesMarshaller = subscriberAttributesMarshaller
        self.customerInfoResponseHandler = customerInfoResponseHandler
        self.customerInfoCallbackCache = customerInfoCallbackCache

        super.init(configuration: configuration)
    }

    // swiftlint:disable:next function_parameter_count
    func post(receiptData: Data,
              appUserID: String,
              isRestore: Bool,
              productInfo: ProductInfo?,
              presentedOfferingIdentifier offeringIdentifier: String?,
              observerMode: Bool,
              subscriberAttributes subscriberAttributesByKey: SubscriberAttributeDict?,
              completion: @escaping BackendCustomerInfoResponseHandler) {
        let fetchToken = receiptData.asFetchToken
        var body: [String: Any] = [
            "fetch_token": fetchToken,
            "app_user_id": appUserID,
            "is_restore": isRestore,
            "observer_mode": observerMode
        ]

        let cacheKey =
        """
        \(appUserID)-\(isRestore)-\(fetchToken)-\(productInfo?.cacheKey ?? "")
        -\(offeringIdentifier ?? "")-\(observerMode)-\(subscriberAttributesByKey?.debugDescription ?? "")"
        """

        let callbackObject = CustomerInfoCallback(key: cacheKey, callback: completion)
        if customerInfoCallbackCache.add(callback: callbackObject) == .addedToExistingInFlightList {
            return
        }

        if let productInfo = productInfo {
            body.merge(productInfo.asDictionary()) { _, new in new }
        }

        if let subscriberAttributesByKey = subscriberAttributesByKey {
            let attributesInBackendFormat = self.subscriberAttributesMarshaller
                .subscriberAttributesToDict(subscriberAttributes: subscriberAttributesByKey)
            body["attributes"] = attributesInBackendFormat
        }

        if let offeringIdentifier = offeringIdentifier {
            body["presented_offering_identifier"] = offeringIdentifier
        }

        httpClient.performPOSTRequest(serially: true,
                                      path: "/receipts",
                                      requestBody: body,
                                      headers: authHeaders) { statusCode, response, error in
            self.customerInfoCallbackCache.performOnAllItemsAndRemoveFromCache(withKey: cacheKey) { callbackObject in
                self.customerInfoResponseHandler.handle(customerInfoResponse: response,
                                                        statusCode: statusCode,
                                                        maybeError: error,
                                                        completion: callbackObject.callback)
            }
        }
    }

}
