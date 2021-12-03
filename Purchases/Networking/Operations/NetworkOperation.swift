//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  NetworkOperation.swift
//
//  Created by Joshua Liebowitz on 11/18/21.

import Foundation

class NetworkOperation: Operation {

    let httpClient: HTTPClient
    let authHeaders: [String: String]

    init(httpClient: HTTPClient, authHeaders: [String: String]) {
        self.httpClient = httpClient
        self.authHeaders = authHeaders

        super.init()
    }

}
