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
typealias IdentifyResponseHandler = (CustomerInfo?, Bool, Error?) -> Void

// swiftlint:disable type_body_length file_length
class Backend {

    static let RCSuccessfullySyncedKey: NSError.UserInfoKey = "rc_successfullySynced"
    static let RCAttributeErrorsKey = "attribute_errors"
    static let RCAttributeErrorsResponseKey = "attributes_error_response"

    private let httpClient: HTTPClient
    private let apiKey: String
    private let callbackQueue = DispatchQueue(label: "Backend callbackQueue")
    private let authHeaders: [String: String]
    private let subscribersAPI: SubscribersAPI
    private var offeringsCallbacksCache: [String: [OfferingsResponseHandler]]
    private var identifyCallbacksCache: [String: [IdentifyResponseHandler]]

    convenience init(apiKey: String,
                     systemInfo: SystemInfo,
                     eTagManager: ETagManager,
                     operationDispatcher: OperationDispatcher) {
        let httpClient = HTTPClient(systemInfo: systemInfo, eTagManager: eTagManager)
        self.init(httpClient: httpClient, apiKey: apiKey)
    }

    required init(httpClient: HTTPClient, apiKey: String) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.offeringsCallbacksCache = [:]
        self.identifyCallbacksCache = [:]
        self.authHeaders = ["Authorization": "Bearer \(apiKey)"]
        self.subscribersAPI = SubscribersAPI(httpClient: httpClient,
                                             authHeaders: self.authHeaders,
                                             callbackQueue: self.callbackQueue)
    }

    func createAlias(appUserID: String, newAppUserID: String, completion: PostRequestResponseHandler?) {
        self.subscribersAPI.createAlias(appUserID: appUserID, newAppUserID: newAppUserID, completion: completion)
    }

    func clearCaches() {
        httpClient.clearCaches()
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

    // swiftlint:disable:next function_parameter_count function_body_length
    func post(offerIdForSigning offerIdentifier: String,
              productIdentifier: String,
              subscriptionGroup: String,
              receiptData: Data,
              appUserID: String,
              completion: @escaping OfferSigningResponseHandler) {
        let fetchToken = receiptData.asFetchToken

        let requestBody: [String: Any] = ["app_user_id": appUserID,
                                          "fetch_token": fetchToken,
                                          "generate_offers": [
                                            ["offer_id": offerIdentifier,
                                             "product_id": productIdentifier,
                                             "subscription_group": subscriptionGroup
                                            ]
                                          ]]

        self.httpClient.performPOSTRequest(serially: true,
                                           path: "/offers",
                                           requestBody: requestBody,
                                           headers: authHeaders) { statusCode, maybeResponse, maybeError in
            if let error = maybeError {
                completion(nil, nil, nil, nil, ErrorUtils.networkError(withUnderlyingError: error))
                return
            }

            guard statusCode < HTTPStatusCodes.redirect.rawValue else {
                let backendCode = BackendErrorCode(maybeCode: maybeResponse?["code"])
                let backendMessage = maybeResponse?["message"] as? String
                let error = ErrorUtils.backendError(withBackendCode: backendCode, backendMessage: backendMessage)
                completion(nil, nil, nil, nil, error)
                return
            }

            guard let response = maybeResponse else {
                let subErrorCode = UnexpectedBackendResponseSubErrorCode.postOfferEmptyResponse
                let error = ErrorUtils.unexpectedBackendResponse(withSubError: subErrorCode)
                Logger.debug(Strings.backendError.offerings_empty_response)
                completion(nil, nil, nil, nil, error)
                return
            }

            guard let offers = response["offers"] as? [[String: Any]] else {
                let subErrorCode = UnexpectedBackendResponseSubErrorCode.postOfferIdBadResponse
                let error = ErrorUtils.unexpectedBackendResponse(withSubError: subErrorCode,
                                                                 extraContext: response.stringRepresentation)
                Logger.debug(Strings.backendError.offerings_response_json_error(response: response))
                completion(nil, nil, nil, nil, error)
                return
            }

            guard offers.count > 0 else {
                let subErrorCode = UnexpectedBackendResponseSubErrorCode.postOfferIdMissingOffersInResponse
                let error = ErrorUtils.unexpectedBackendResponse(withSubError: subErrorCode)
                Logger.debug(Strings.backendError.no_offerings_response_json(response: response))
                completion(nil, nil, nil, nil, error)
                return
            }

            let offer = offers[0]
            if let signatureError = offer["signature_error"] as? [String: Any] {
                let backendCode = BackendErrorCode(maybeCode: signatureError["code"])
                let backendMessage = signatureError["message"] as? String
                let error = ErrorUtils.backendError(withBackendCode: backendCode, backendMessage: backendMessage)
                completion(nil, nil, nil, nil, error)
                return

            } else if let signatureData = offer["signature_data"] as? [String: Any] {
                let signature = signatureData["signature"] as? String
                let keyIdentifier = offer["key_id"] as? String
                let nonceString = signatureData["nonce"] as? String
                let maybeNonce = nonceString.flatMap { UUID(uuidString: $0) }
                let timestamp = signatureData["timestamp"] as? Int

                completion(signature, keyIdentifier, maybeNonce, timestamp, nil)
                return
            } else {
                Logger.error(Strings.backendError.signature_error(maybeSignatureDataString: offer["signature_data"]))
                let subErrorCode = UnexpectedBackendResponseSubErrorCode.postOfferIdSignature
                let signatureError = ErrorUtils.unexpectedBackendResponse(withSubError: subErrorCode)
                completion(nil, nil, nil, nil, signatureError)
                return
            }
        }
    }

    func post(attributionData: [String: Any],
              network: AttributionNetwork,
              appUserID: String,
              completion: PostRequestResponseHandler?) {
        guard let appUserID = try? escapedAppUserID(appUserID: appUserID) else {
            completion?(ErrorUtils.missingAppUserIDError())
            return
        }

        let path = "/subscribers/\(appUserID)/attribution"
        let body: [String: Any] = ["network": network.rawValue, "data": attributionData]
        httpClient.performPOSTRequest(serially: true,
                                      path: path,
                                      requestBody: body,
                                      headers: authHeaders) { statusCode, response, error in
            self.handle(response: response, statusCode: statusCode, maybeError: error, completion: completion)
        }
    }

    func logIn(currentAppUserID: String,
               newAppUserID: String,
               completion: @escaping IdentifyResponseHandler) {

        let cacheKey = currentAppUserID + newAppUserID
        if add(identifyCallback: completion, key: cacheKey) == .addedToExistingInFlightList {
            return
        }

        let requestBody = ["app_user_id": currentAppUserID, "new_app_user_id": newAppUserID]
        httpClient.performPOSTRequest(serially: true,
                                      path: "/subscribers/identify",
                                      requestBody: requestBody,
                                      headers: authHeaders) { statusCode, response, error in
            for callback in self.getIdentifyCallbacksAndClearCache(forKey: cacheKey) {
                self.handleLogin(maybeResponse: response,
                                 statusCode: statusCode,
                                 maybeError: error,
                                 completion: callback)
            }
        }
    }

    func getOfferings(appUserID: String, completion: @escaping OfferingsResponseHandler) {
        guard let appUserID = try? escapedAppUserID(appUserID: appUserID) else {
            completion(nil, ErrorUtils.missingAppUserIDError())
            return
        }

        let path = "/subscribers/\(appUserID)/offerings"
        if add(callback: completion, key: path) == .addedToExistingInFlightList {
            return
        }

        httpClient.performGETRequest(serially: true,
                                     path: path,
                                     headers: authHeaders) { [weak self] (statusCode, maybeResponse, maybeError) in
            guard let self = self else {
                Logger.debug(Strings.backendError.backend_deallocated)
                return
            }

            if maybeError == nil && statusCode < HTTPStatusCodes.redirect.rawValue {
                for callback in self.getOfferingsCallbacksAndClearCache(forKey: path) {
                    callback(maybeResponse, nil)
                }
                return
            }

            let errorForCallbacks: Error
            if let error = maybeError {
                errorForCallbacks = ErrorUtils.networkError(withUnderlyingError: error)
            } else if statusCode >= HTTPStatusCodes.redirect.rawValue {
                let backendCode = BackendErrorCode(maybeCode: maybeResponse?["code"])
                let backendMessage = maybeResponse?["message"] as? String
                errorForCallbacks = ErrorUtils.backendError(withBackendCode: backendCode,
                                                            backendMessage: backendMessage)
            } else {
                let subErrorCode = UnexpectedBackendResponseSubErrorCode.getOfferUnexpectedResponse
                errorForCallbacks = ErrorUtils.unexpectedBackendResponse(withSubError: subErrorCode)
            }

            let responseString = maybeResponse?.debugDescription
            Logger.error(Strings.backendError.unknown_get_offerings_error(statusCode: statusCode,
                                                                          maybeResponseString: responseString))
            for callback in self.getOfferingsCallbacksAndClearCache(forKey: path) {
                callback(nil, errorForCallbacks)
            }
        }
    }

    func getIntroEligibility(appUserID: String,
                             receiptData: Data,
                             productIdentifiers: [String],
                             completion: @escaping IntroEligibilityResponseHandler) {
        guard productIdentifiers.count > 0 else {
            completion([:], nil)
            return
        }

        if receiptData.count == 0 {
            if self.httpClient.systemInfo.isSandbox {
                Logger.appleWarning(Strings.receipt.no_sandbox_receipt_intro_eligibility)
            }

            var eligibilities: [String: IntroEligibility] = [:]

            for productID in productIdentifiers {
                eligibilities[productID] = IntroEligibility(eligibilityStatus: .unknown)
            }

            completion(eligibilities, nil)
            return
        }

        // Closure we can use for both missing appUserID as well as server error where we have an unknown
        // eligibility status.
        let unknownEligibilityClosure: () -> [String: IntroEligibility] = {
            let unknownEligibilities = [IntroEligibility](repeating: IntroEligibility(eligibilityStatus: .unknown),
                                                          count: productIdentifiers.count)
            let productIdentifiersToEligibility = zip(productIdentifiers, unknownEligibilities)
            return Dictionary(uniqueKeysWithValues: productIdentifiersToEligibility)
        }

        guard let appUserID = try? escapedAppUserID(appUserID: appUserID) else {
            completion(unknownEligibilityClosure(), ErrorUtils.missingAppUserIDError())
            return
        }

        let fetchToken = receiptData.asFetchToken
        let path = "/subscribers/\(appUserID)/intro_eligibility"
        let body: [String: Any] = ["product_identifiers": productIdentifiers,
                                   "fetch_token": fetchToken]

        httpClient.performPOSTRequest(serially: true,
                                      path: path,
                                      requestBody: body,
                                      headers: authHeaders) { statusCode, maybeResponse, error in
            let eligibilityResponse = IntroEligibilityResponse(maybeResponse: maybeResponse,
                                                               statusCode: statusCode,
                                                               error: error,
                                                               productIdentifiers: productIdentifiers,
                                                               unknownEligibilityClosure: unknownEligibilityClosure,
                                                               completion: completion)
            self.handleIntroEligibility(response: eligibilityResponse)
        }
    }

}

private extension Backend {

    func handleIntroEligibility(response: IntroEligibilityResponse) {
        var eligibilitiesByProductIdentifier = response.maybeResponse
        if response.statusCode >= HTTPStatusCodes.redirect.rawValue || response.error != nil {
            eligibilitiesByProductIdentifier = [:]
        }

        guard let eligibilitiesByProductIdentifier = eligibilitiesByProductIdentifier else {
            response.completion(response.unknownEligibilityClosure(), nil)
            return
        }

        var eligibilities: [String: IntroEligibility] = [:]
        for productID in response.productIdentifiers {
            let status: IntroEligibilityStatus

            if let eligibility = eligibilitiesByProductIdentifier[productID] as? Bool {
                status = eligibility ? .eligible : .ineligible
            } else {
                status = .unknown
            }

            eligibilities[productID] = IntroEligibility(eligibilityStatus: status)
        }
        response.completion(eligibilities, nil)
    }

    func handleLogin(maybeResponse: [String: Any]?,
                     statusCode: Int,
                     maybeError: Error?,
                     completion: IdentifyResponseHandler) {
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

    func handle(response: [String: Any]?,
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

    func escapedAppUserID(appUserID: String) throws -> String {
        do {
            return try appUserID.escapedOrError()
        } catch {
            throw ErrorUtils.missingAppUserIDError()
        }
    }

    func userInfoAttributes(response: [String: Any], statusCode: Int) -> [String: Any] {
        var resultDict: [String: Any] = [:]

        let isInternalServerError = statusCode >= HTTPStatusCodes.internalServerError.rawValue
        let isNotFoundError = statusCode == HTTPStatusCodes.notFoundError.rawValue
        let successfullySynced = !(isInternalServerError || isNotFoundError)
        resultDict[Backend.RCSuccessfullySyncedKey as String] = successfullySynced

        let attributesResponse = (response[Backend.RCAttributeErrorsResponseKey] as? [String: Any]) ?? response
        resultDict[Backend.RCAttributeErrorsKey] = attributesResponse[Backend.RCAttributeErrorsKey]

        return resultDict
    }

    // MARK: Callback cache management

    func add(callback: @escaping OfferingsResponseHandler, key: String) -> CallbackCacheStatus {
        return callbackQueue.sync { [self] in
            var callbacksForKey = offeringsCallbacksCache[key] ?? []
            let cacheStatus: CallbackCacheStatus = !callbacksForKey.isEmpty
                ? .addedToExistingInFlightList
                : .firstCallbackAddedToList

            callbacksForKey.append(callback)
            offeringsCallbacksCache[key] = callbacksForKey
            return cacheStatus
        }
    }

    func add(identifyCallback: @escaping IdentifyResponseHandler, key: String) -> CallbackCacheStatus {
        return callbackQueue.sync { [self] in
            var callbacksForKey = identifyCallbacksCache[key] ?? []
            let cacheStatus: CallbackCacheStatus = !callbacksForKey.isEmpty
                ? .addedToExistingInFlightList
                : .firstCallbackAddedToList

            callbacksForKey.append(identifyCallback)
            identifyCallbacksCache[key] = callbacksForKey
            return cacheStatus
        }
    }

    func getOfferingsCallbacksAndClearCache(forKey key: String) -> [OfferingsResponseHandler] {
        return callbackQueue.sync { [self] in
            let callbacks = offeringsCallbacksCache.removeValue(forKey: key)
            assert(callbacks != nil)
            return callbacks ?? []
        }
    }

    func getIdentifyCallbacksAndClearCache(forKey key: String) -> [IdentifyResponseHandler] {
        return callbackQueue.sync { [self] in
            let callbacks = identifyCallbacksCache.removeValue(forKey: key)
            assert(callbacks != nil)
            return callbacks ?? []
        }
    }

}

// swiftlint:enable type_body_length file_length
