//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  Backend.swift
//
//  Created by Joshua Liebowitz on 8/2/21.

import Foundation

typealias SubscriberAttributeDict = [String: SubscriberAttribute]
typealias BackendCustomerInfoResponseHandler = (CustomerInfo?, Error?) -> Void
typealias IntroEligibilityResponseHandler = ([String: IntroEligibility], Error?) -> Void
typealias OfferingsResponseHandler = ([String: Any]?, Error?) -> Void
typealias OfferSigningResponseHandler = (String?, String?, UUID?, Int?, Error?) -> Void
typealias PostRequestResponseHandler = (Error?) -> Void
typealias LogInResponseHandler = (CustomerInfo?, Bool, Error?) -> Void

class Backend {

    static let RCSuccessfullySyncedKey: NSError.UserInfoKey = "rc_successfullySynced"
    static let RCAttributeErrorsKey = "attribute_errors"
    static let RCAttributeErrorsResponseKey = "attributes_error_response"

    private let apiKey: String
    private let authHeaders: [String: String]
    private let httpClient: HTTPClient
    private let subscribersAPI: SubscribersAPI
    private let operationQueue: OperationQueue

    private let logInCallbacksCache: CallbackCache<LogInCallback>
    private let offeringsCallbacksCache: CallbackCache<OfferingsCallback>
    private let callbackQueue = DispatchQueue(label: "Backend callbackQueue")

    convenience init(apiKey: String,
                     systemInfo: SystemInfo,
                     eTagManager: ETagManager,
                     operationDispatcher: OperationDispatcher) {
        let httpClient = HTTPClient(systemInfo: systemInfo, eTagManager: eTagManager)
        self.init(httpClient: httpClient, apiKey: apiKey)
    }

    required init(httpClient: HTTPClient, apiKey: String) {
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = 1
        self.operationQueue.name = "Backend Queue"

        self.httpClient = httpClient
        self.apiKey = apiKey
        self.offeringsCallbacksCache = CallbackCache<OfferingsCallback>(callbackQueue: self.callbackQueue)
        self.logInCallbacksCache = CallbackCache<LogInCallback>(callbackQueue: self.callbackQueue)
        self.authHeaders = ["Authorization": "Bearer \(apiKey)"]
        self.subscribersAPI = SubscribersAPI(httpClient: httpClient,
                                             authHeaders: self.authHeaders,
                                             callbackQueue: self.callbackQueue,
                                             operationQueue: self.operationQueue)
    }

    func createAlias(appUserID: String, newAppUserID: String, completion: PostRequestResponseHandler?) {
        self.subscribersAPI.createAlias(appUserID: appUserID, newAppUserID: newAppUserID, completion: completion)
    }

    func clearHTTPClientCaches() {
        self.httpClient.clearCaches()
    }

    func getSubscriberData(appUserID: String, completion: @escaping BackendCustomerInfoResponseHandler) {
        self.subscribersAPI.getSubscriberData(appUserID: appUserID, completion: completion)
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
        self.subscribersAPI.post(receiptData: receiptData,
                                 appUserID: appUserID,
                                 isRestore: isRestore,
                                 productInfo: productInfo,
                                 presentedOfferingIdentifier: offeringIdentifier,
                                 observerMode: observerMode,
                                 subscriberAttributes: subscriberAttributesByKey,
                                 completion: completion)
    }

    func post(subscriberAttributes: SubscriberAttributeDict,
              appUserID: String,
              completion: PostRequestResponseHandler?) {
        self.subscribersAPI.post(subscriberAttributes: subscriberAttributes,
                                 appUserID: appUserID,
                                 completion: completion)
    }

    // swiftlint:disable:next function_parameter_count
    func post(offerIdForSigning offerIdentifier: String,
              productIdentifier: String,
              subscriptionGroup: String,
              receiptData: Data,
              appUserID: String,
              completion: @escaping OfferSigningResponseHandler) {
        let postOfferForSigningOperation = PostOfferForSigningOperation(httpClient: self.httpClient,
                                                                        authHeaders: self.authHeaders)
        self.operationQueue.addOperation {
            postOfferForSigningOperation.post(offerIdForSigning: offerIdentifier,
                                              productIdentifier: productIdentifier,
                                              subscriptionGroup: subscriptionGroup,
                                              receiptData: receiptData,
                                              appUserID: appUserID,
                                              completion: completion)
        }
    }

    func post(attributionData: [String: Any],
              network: AttributionNetwork,
              appUserID: String,
              completion: PostRequestResponseHandler?) {
        let postAttributionDataOperation = PostAttributionDataOperation(httpClient: self.httpClient,
                                                                        authHeaders: self.authHeaders)
        self.operationQueue.addOperation {
            postAttributionDataOperation.post(attributionData: attributionData,
                                              network: network,
                                              appUserID: appUserID,
                                              maybeCompletion: completion)
        }
    }

    func logIn(currentAppUserID: String,
               newAppUserID: String,
               completion: @escaping LogInResponseHandler) {
        let loginOperation = LogInOperation(httpClient: self.httpClient,
                                            authHeaders: self.authHeaders,
                                            loginCallbackCache: self.logInCallbacksCache)
        self.operationQueue.addOperation {
            loginOperation.logIn(currentAppUserID: currentAppUserID, newAppUserID: newAppUserID, completion: completion)
        }

    }

    func getOfferings(appUserID: String, completion: @escaping OfferingsResponseHandler) {
        let getOfferingsOperation = GetOfferingsOperation(httpClient: self.httpClient,
                                                          authHeaders: self.authHeaders,
                                                          offeringsCallbackCache: self.offeringsCallbacksCache)
        self.operationQueue.addOperation {
            getOfferingsOperation.getOfferings(appUserID: appUserID, completion: completion)
        }
    }

    func getIntroEligibility(appUserID: String,
                             receiptData: Data,
                             productIdentifiers: [String],
                             completion: @escaping IntroEligibilityResponseHandler) {
        let getIntroEligibilityOperation = GetIntroEligibilityOperation(httpClient: self.httpClient,
                                                                        authHeaders: self.authHeaders)
        self.operationQueue.addOperation {
            getIntroEligibilityOperation.getIntroEligibility(appUserID: appUserID,
                                                             receiptData: receiptData,
                                                             productIdentifiers: productIdentifiers,
                                                             completion: completion)
        }
    }

}
