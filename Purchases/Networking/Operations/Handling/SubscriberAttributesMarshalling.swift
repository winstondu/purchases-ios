//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  SubscriberAttributesMarshalling.swift
//
//  Created by Joshua Liebowitz on 11/18/21.

import Foundation

protocol SubscriberAttributesMarshalling {

    func subscriberAttributesToDict(subscriberAttributes: SubscriberAttributeDict) -> [String: Any]

}

extension SubscriberAttributesMarshalling {

    func subscriberAttributesToDict(subscriberAttributes: SubscriberAttributeDict) -> [String: Any] {
        var attributesByKey: [String: Any] = [:]
        for (key, value) in subscriberAttributes {
            attributesByKey[key] = value.asBackendDictionary()
        }
        return attributesByKey
    }

}
