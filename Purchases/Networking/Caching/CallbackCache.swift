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

import UIKit

class CallbackCache<T> where T: CachableCallback {

    var cache: [String: [T]] = [:]
    let callbackQueue: DispatchQueue

    init(callbackQueue: DispatchQueue) {
        self.callbackQueue = callbackQueue
    }

    func add(callback: T) -> CallbackCacheStatus {
        callbackQueue.sync {
            var values = cache[callback.key] ?? []
            let cacheStatus: CallbackCacheStatus = !values.isEmpty ?
                .addedToExistingInFlightList :
                .firstCallbackAddedToList

            values.append(callback)
            cache[callback.key] = values
            return cacheStatus
        }
    }

    func performOnAllItemsAndRemoveFromCache(withKey key: String, _ block: (T) -> Void) {
        callbackQueue.sync {
            guard let items = cache[key] else {
                return
            }

            items.forEach { block($0) }
            cache.removeValue(forKey: key)
        }
    }

}

protocol CachableCallback {

    var key: String { get }

}
