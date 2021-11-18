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

    let httpClient: HTTPClient
    let callbackQueue: DispatchQueue
    private let authHeaders: [String: String]
    private var createAliasCallbacksCache: [String: [PostRequestResponseHandler?]]
    private var customerInfoCallbacksCache: [String: [BackendCustomerInfoResponseHandler]]

    init(httpClient: HTTPClient, authHeaders: [String: String], callbackQueue: DispatchQueue) {
        self.httpClient = httpClient
        self.authHeaders = authHeaders
        self.callbackQueue = callbackQueue
        self.createAliasCallbacksCache = [:]
        self.customerInfoCallbacksCache = [:]
    }

    func createAlias(appUserID: String, newAppUserID: String, completion: PostRequestResponseHandler?) {
        guard let appUserID = try? appUserID.escapedOrError() else {
            completion?(ErrorUtils.missingAppUserIDError())
            return
        }

        let cacheKey = appUserID + newAppUserID
        if add(createAliasCallback: completion, key: cacheKey) == .addedToExistingInFlightList {
            return
        }

        Logger.user(Strings.identity.creating_alias(userA: appUserID, userB: newAppUserID))
        httpClient.performPOSTRequest(serially: true,
                                      path: "/subscribers/\(appUserID)/alias",
                                      requestBody: ["new_app_user_id": newAppUserID],
                                      headers: authHeaders) { statusCode, response, error in

            for callback in self.getCreateAliasCallbacksAndClearCache(forKey: cacheKey) {
                self.handle(response: response, statusCode: statusCode, maybeError: error, completion: callback)
            }
        }

    }

    func getSubscriberData(appUserID: String, completion: @escaping BackendCustomerInfoResponseHandler) {
        guard let appUserID = try? appUserID.escapedOrError() else {
            completion(nil, ErrorUtils.missingAppUserIDError())
            return
        }

        let path = "/subscribers/\(appUserID)"

        if add(callback: completion, key: path) == .addedToExistingInFlightList {
            return
        }

        httpClient.performGETRequest(serially: true,
                                     path: path,
                                     headers: authHeaders) {  [weak self] (statusCode, response, error) in
            guard let self = self else {
                return
            }

            for completion in self.getCustomerInfoCallbacksAndClearCache(forKey: path) {
                self.handle(customerInfoResponse: response,
                            statusCode: statusCode,
                            maybeError: error,
                            completion: completion)
            }
        }
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

        let attributesInBackendFormat = subscriberAttributesToDict(subscriberAttributes: subscriberAttributes)
        httpClient.performPOSTRequest(serially: true,
                                      path: path,
                                      requestBody: ["attributes": attributesInBackendFormat],
                                      headers: authHeaders) { statusCode, response, error in
            self.handleSubscriberAttributesResult(statusCode: statusCode,
                                                  response: response,
                                                  maybeError: error,
                                                  completion: completion)
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

        if add(callback: completion, key: cacheKey) == .addedToExistingInFlightList {
            return
        }

        if let productInfo = productInfo {
            body.merge(productInfo.asDictionary()) { _, new in new }
        }

        if let subscriberAttributesByKey = subscriberAttributesByKey {
            let attributesInBackendFormat = subscriberAttributesToDict(subscriberAttributes: subscriberAttributesByKey)
            body["attributes"] = attributesInBackendFormat
        }

        if let offeringIdentifier = offeringIdentifier {
            body["presented_offering_identifier"] = offeringIdentifier
        }

        httpClient.performPOSTRequest(serially: true,
                                      path: "/receipts",
                                      requestBody: body,
                                      headers: authHeaders) { statusCode, response, error in
            let callbacks = self.getCustomerInfoCallbacksAndClearCache(forKey: cacheKey)
            for callback in callbacks {
                self.handle(customerInfoResponse: response,
                            statusCode: statusCode,
                            maybeError: error,
                            completion: callback)
            }
        }
    }

}

extension SubscribersAPI {

    func add(createAliasCallback: PostRequestResponseHandler?, key: String) -> CallbackCacheStatus {
        return callbackQueue.sync { [self] in
            var callbacksForKey = createAliasCallbacksCache[key] ?? []
            let cacheStatus: CallbackCacheStatus = !callbacksForKey.isEmpty
            ? .addedToExistingInFlightList
            : .firstCallbackAddedToList

            callbacksForKey.append(createAliasCallback)
            createAliasCallbacksCache[key] = callbacksForKey
            return cacheStatus
        }
    }

    func add(callback: @escaping BackendCustomerInfoResponseHandler, key: String) -> CallbackCacheStatus {
        return callbackQueue.sync { [self] in
            var callbacksForKey = customerInfoCallbacksCache[key] ?? []
            let cacheStatus: CallbackCacheStatus = !callbacksForKey.isEmpty
            ? .addedToExistingInFlightList
            : .firstCallbackAddedToList

            callbacksForKey.append(callback)
            customerInfoCallbacksCache[key] = callbacksForKey
            return cacheStatus
        }
    }

    func getCreateAliasCallbacksAndClearCache(forKey key: String) -> [PostRequestResponseHandler?] {
        return callbackQueue.sync { [self] in
            let callbacks = createAliasCallbacksCache.removeValue(forKey: key)
            assert(callbacks != nil)
            return callbacks ?? []
        }
    }

    func getCustomerInfoCallbacksAndClearCache(forKey key: String) -> [BackendCustomerInfoResponseHandler] {
        return callbackQueue.sync { [self] in
            let callbacks = customerInfoCallbacksCache.removeValue(forKey: key)
            assert(callbacks != nil)
            return callbacks ?? []
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

    func parseCustomerInfo(fromMaybeResponse maybeResponse: [String: Any]?) throws -> CustomerInfo {
        guard let customerJson = maybeResponse else {
            throw UnexpectedBackendResponseSubErrorCode.customerInfoResponseMalformed
        }

        do {
            return try CustomerInfo(data: customerJson)
        } catch {
            let parsingError = UnexpectedBackendResponseSubErrorCode.customerInfoResponseParsing
            let subError = parsingError.addingUnderlyingError(error,
                                                              extraContext: customerJson.stringRepresentation)
            throw subError
        }
    }

    // swiftlint:disable:next function_body_length
    func handle(customerInfoResponse maybeResponse: [String: Any]?,
                statusCode: Int,
                maybeError: Error?,
                file: String = #file,
                function: String = #function,
                completion: BackendCustomerInfoResponseHandler) {
        if let error = maybeError {
            completion(nil, ErrorUtils.networkError(withUnderlyingError: error, generatedBy: "\(file) \(function)"))
            return
        }
        let isErrorStatusCode = statusCode >= HTTPStatusCodes.redirect.rawValue

        let maybeCustomerInfoError: Error?
        let maybeCustomerInfo: CustomerInfo?

        if !isErrorStatusCode {
            // Only attempt to parse a response if we don't have an error status code from the backend.
            do {
                maybeCustomerInfo = try parseCustomerInfo(fromMaybeResponse: maybeResponse)
                maybeCustomerInfoError = nil
            } catch let customerInfoError {
                maybeCustomerInfo = nil
                maybeCustomerInfoError = customerInfoError
            }
        } else {
            maybeCustomerInfoError = nil
            maybeCustomerInfo = nil
        }

        if !isErrorStatusCode && maybeCustomerInfo == nil {
            let extraContext = "statusCode: \(statusCode), json:\(maybeResponse.debugDescription)"
            completion(nil, ErrorUtils.unexpectedBackendResponse(withSubError: maybeCustomerInfoError,
                                                                 generatedBy: "\(file) \(function)",
                                                                 extraContext: extraContext))
            return
        }

        let subscriberAttributesErrorInfo = attributesUserInfoFromResponse(response: maybeResponse ?? [:],
                                                                           statusCode: statusCode)

        let hasError = (isErrorStatusCode
                        || subscriberAttributesErrorInfo[Backend.RCAttributeErrorsKey] != nil
                        || maybeCustomerInfoError != nil)

        guard !hasError else {
            let finishable = statusCode < HTTPStatusCodes.internalServerError.rawValue
            var extraUserInfo = [ErrorDetails.finishableKey: finishable] as [String: Any]
            extraUserInfo.merge(subscriberAttributesErrorInfo) { _, new in new }
            let backendErrorCode = BackendErrorCode(maybeCode: maybeResponse?["code"])
            let message = maybeResponse?["message"] as? String
            var responseError = ErrorUtils.backendError(withBackendCode: backendErrorCode,
                                                        backendMessage: message,
                                                        extraUserInfo: extraUserInfo as [NSError.UserInfoKey: Any])
            if let maybeCustomerInfoError = maybeCustomerInfoError {
                responseError = maybeCustomerInfoError
                    .addingUnderlyingError(responseError, extraContext: maybeResponse?.stringRepresentation)
            }

            completion(maybeCustomerInfo, responseError)
            return
        }

        completion(maybeCustomerInfo, nil)
    }

    func subscriberAttributesToDict(subscriberAttributes: SubscriberAttributeDict) -> [String: Any] {
        var attributesByKey: [String: Any] = [:]
        for (key, value) in subscriberAttributes {
            attributesByKey[key] = value.asBackendDictionary()
        }
        return attributesByKey
    }

    func attributesUserInfoFromResponse(response: [String: Any], statusCode: Int) -> [String: Any] {
        var resultDict: [String: Any] = [:]
        let isInternalServerError = statusCode >= HTTPStatusCodes.internalServerError.rawValue
        let isNotFoundError = statusCode == HTTPStatusCodes.notFoundError.rawValue

        let successfullySynced = !(isInternalServerError || isNotFoundError)
        resultDict[Backend.RCSuccessfullySyncedKey as String] = successfullySynced

        let hasAttributesResponseContainerKey = (response[Backend.RCAttributeErrorsResponseKey] != nil)
        let attributesResponseDict = hasAttributesResponseContainerKey
        ? response[Backend.RCAttributeErrorsResponseKey]
        : response

        if let attributesResponseDict = attributesResponseDict as? [String: Any],
           let attributesErrors = attributesResponseDict[Backend.RCAttributeErrorsKey] {
            resultDict[Backend.RCAttributeErrorsKey] = attributesErrors
        }

        return resultDict
    }

    func handleSubscriberAttributesResult(statusCode: Int,
                                          response: [String: Any]?,
                                          maybeError: Error?,
                                          completion: PostRequestResponseHandler?) {
        guard let completion = completion else {
            return
        }

        if let error = maybeError {
            completion(ErrorUtils.networkError(withUnderlyingError: error))
            return
        }

        let responseError: Error?

        if let response = response, statusCode > HTTPStatusCodes.redirect.rawValue {
            let extraUserInfo = attributesUserInfoFromResponse(response: response, statusCode: statusCode)
            let backendErrorCode = BackendErrorCode(maybeCode: response["code"])
            responseError = ErrorUtils.backendError(withBackendCode: backendErrorCode,
                                                    backendMessage: response["message"] as? String,
                                                    extraUserInfo: extraUserInfo as [NSError.UserInfoKey: Any])
        } else {
            responseError = nil
        }

        completion(responseError)
    }

}
