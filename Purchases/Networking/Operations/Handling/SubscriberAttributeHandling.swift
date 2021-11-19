//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  SubscriberAttributeHandling.swift
//
//  Created by Joshua Liebowitz on 11/18/21.

import Foundation

protocol SubscriberAttributeHandling: CustomerInfoResponseHandling {

    func handleSubscriberAttributesResult(statusCode: Int,
                                          response: [String: Any]?,
                                          maybeError: Error?,
                                          completion: PostRequestResponseHandler?)

}

extension SubscriberAttributeHandling {

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
