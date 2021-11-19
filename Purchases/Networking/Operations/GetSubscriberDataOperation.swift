//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  GetSubscriberDataOperation.swift
//
//  Created by Joshua Liebowitz on 11/18/21.

import Foundation

class GetSubscriberDataOperation: NetworkOperation {

    private let customerInfoCallbackCache: CallbackCache<CustomerInfoCallback>
    let httpClient: HTTPClient
    let authHeaders: [String: String]

    init(httpClient: HTTPClient,
         authHeaders: [String: String],
         customerInfoCallbackCache: CallbackCache<CustomerInfoCallback>) {
        self.httpClient = httpClient
        self.authHeaders = authHeaders
        self.customerInfoCallbackCache = customerInfoCallbackCache
    }

    func getSubscriberData(appUserID: String, completion: @escaping BackendCustomerInfoResponseHandler) {
        guard let appUserID = try? appUserID.escapedOrError() else {
            completion(nil, ErrorUtils.missingAppUserIDError())
            return
        }

        let path = "/subscribers/\(appUserID)"
        let callbackObject = CustomerInfoCallback(key: path, callback: completion)
        if customerInfoCallbackCache.add(callback: callbackObject) == .addedToExistingInFlightList {
            return
        }

        httpClient.performGETRequest(serially: true,
                                     path: path,
                                     headers: authHeaders) {  [weak self] (statusCode, response, error) in
            guard let self = self else {
                return
            }

            self.customerInfoCallbackCache.performOnAllItemsAndRemoveFromCache(withKey: path) { callbackObject in
                self.handle(customerInfoResponse: response,
                            statusCode: statusCode,
                            maybeError: error,
                            completion: callbackObject.callback)
            }
        }
    }

}

extension GetSubscriberDataOperation: CustomerInfoResponseHandling {}
