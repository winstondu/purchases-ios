//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  CallbackCache.swift
//
//  Created by Joshua Liebowitz on 11/18/21.

import Foundation

class CallbackCache<T> where T: CachableCallback {

    var cachedCallbacksByKey: [String: [T]] = [:]
    let callbackQueue: DispatchQueue

    init(callbackQueue: DispatchQueue) {
        self.callbackQueue = callbackQueue
    }

    func add(callback: T) -> CallbackCacheStatus {
        callbackQueue.sync {
            var values = cachedCallbacksByKey[callback.key] ?? []
            let cacheStatus: CallbackCacheStatus = !values.isEmpty ?
                .addedToExistingInFlightList :
                .firstCallbackAddedToList

            values.append(callback)
            cachedCallbacksByKey[callback.key] = values
            return cacheStatus
        }
    }

    func performOnAllItemsAndRemoveFromCache(withKey key: String, _ block: (T) -> Void) {
        callbackQueue.sync {
            guard let items = cachedCallbacksByKey[key] else {
                return
            }

            items.forEach { block($0) }
            cachedCallbacksByKey.removeValue(forKey: key)
        }
    }

}

protocol CachableCallback {

    var key: String { get }

}
