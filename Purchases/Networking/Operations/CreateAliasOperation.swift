//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  CreateAliasOperation.swift
//
//  Created by Joshua Liebowitz on 11/18/21.

import Foundation

class CreateAliasOperation: NetworkOperation {

    let aliasCallbackCache: CallbackCache<AliasCallback>
    let createAliasResponseHandler: PostAttributionDataResponseHandler

    init(configuration: Configuration,
         createAliasResponseHandler: PostAttributionDataResponseHandler = PostAttributionDataResponseHandler(),
         aliasCallbackCache: CallbackCache<AliasCallback>) {
        self.createAliasResponseHandler = createAliasResponseHandler
        self.aliasCallbackCache = aliasCallbackCache

        super.init(configuration: configuration)
    }

    override func main() {
        if self.isCancelled {
            return
        }

    }

    func createAlias(appUserID: String, newAppUserID: String, maybeCompletion: PostRequestResponseHandler?) {
        guard let appUserID = try? appUserID.escapedOrError() else {
            maybeCompletion?(ErrorUtils.missingAppUserIDError())
            return
        }

        let cacheKey = appUserID + newAppUserID
        let aliasCallback = AliasCallback(key: cacheKey, callback: maybeCompletion)
        if aliasCallbackCache.add(callback: aliasCallback) == .addedToExistingInFlightList {
            return
        }

        Logger.user(Strings.identity.creating_alias(userA: appUserID, userB: newAppUserID))
        httpClient.performPOSTRequest(serially: true,
                                      path: "/subscribers/\(appUserID)/alias",
                                      requestBody: ["new_app_user_id": newAppUserID],
                                      headers: authHeaders) { statusCode, response, error in
            self.aliasCallbackCache.performOnAllItemsAndRemoveFromCache(withKey: cacheKey) { aliasCallback in

                guard let completion = aliasCallback.callback else {
                    return
                }

                self.createAliasResponseHandler.handle(maybeResponse: response,
                                                       statusCode: statusCode,
                                                       maybeError: error,
                                                       completion: completion)
            }
        }
    }

}
