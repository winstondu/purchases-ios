//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  SubscribersAPI.swift
//
//  Created by Joshua Liebowitz on 11/17/21.

import Foundation

class SubscribersAPI {

    private let httpClient: HTTPClient
    private let callbackQueue: DispatchQueue
    private let operationQueue: OperationQueue
    private let authHeaders: [String: String]
    private let aliasCallbackCache: CallbackCache<AliasCallback>
    private let customerInfoCallbackCache: CallbackCache<CustomerInfoCallback>

    init(httpClient: HTTPClient,
         authHeaders: [String: String],
         callbackQueue: DispatchQueue,
         operationQueue: OperationQueue) {
        self.httpClient = httpClient
        self.authHeaders = authHeaders
        self.callbackQueue = callbackQueue
        self.operationQueue = operationQueue
        self.aliasCallbackCache = CallbackCache<AliasCallback>(callbackQueue: callbackQueue)
        self.customerInfoCallbackCache = CallbackCache<CustomerInfoCallback>(callbackQueue: callbackQueue)
    }

    func createAlias(appUserID: String, newAppUserID: String, completion: PostRequestResponseHandler?) {
        let operation = CreateAliasOperation(httpClient: self.httpClient,
                                             authHeaders: self.authHeaders,
                                             aliasCallbackCache: self.aliasCallbackCache)
        operationQueue.addOperation {
            operation.createAlias(appUserID: appUserID, newAppUserID: newAppUserID, maybeCompletion: completion)
        }
    }

    func getSubscriberData(appUserID: String, completion: @escaping BackendCustomerInfoResponseHandler) {
        let operation = GetSubscriberDataOperation(httpClient: self.httpClient,
                                                   authHeaders: self.authHeaders,
                                                   customerInfoCallbackCache: self.customerInfoCallbackCache)
        operationQueue.addOperation {
            operation.getSubscriberData(appUserID: appUserID, completion: completion)
        }
    }

    func post(subscriberAttributes: SubscriberAttributeDict,
              appUserID: String,
              completion: PostRequestResponseHandler?) {
        let operation = PostSubscriberAttributesOperation(httpClient: self.httpClient, authHeaders: self.authHeaders)
        operationQueue.addOperation {
            operation.post(subscriberAttributes: subscriberAttributes, appUserID: appUserID, completion: completion)
        }
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
        let operation = PostReceiptDataOperation(httpClient: self.httpClient,
                                                 authHeaders: self.authHeaders,
                                                 customerInfoCallbackCache: self.customerInfoCallbackCache)
        operationQueue.addOperation {
            operation.post(receiptData: receiptData,
                           appUserID: appUserID,
                           isRestore: isRestore,
                           productInfo: productInfo,
                           presentedOfferingIdentifier: offeringIdentifier,
                           observerMode: observerMode,
                           subscriberAttributes: subscriberAttributesByKey,
                           completion: completion)
        }
    }

}
