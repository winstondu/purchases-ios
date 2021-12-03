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

    init(configuration: NetworkConfiguration) {
        self.httpClient = configuration.httpClient
        self.authHeaders = configuration.authHeaders

        super.init()
    }

    class Configuration: NetworkConfiguration {

        let httpClient: HTTPClient
        let authHeaders: [String: String]

        init(httpClient: HTTPClient, authHeaders: [String: String]) {
            self.httpClient = httpClient
            self.authHeaders = authHeaders
        }

    }

    class UserSpecificConfiguration: AppUserConfiguration, NetworkConfiguration {

        let appUserID: String
        let httpClient: HTTPClient
        let authHeaders: [String: String]

        init(httpClient: HTTPClient, authHeaders: [String: String], appUserID: String) {
            self.httpClient = httpClient
            self.authHeaders = authHeaders
            self.appUserID = appUserID
        }

    }

}

protocol AppUserConfiguration {

    var appUserID: String { get }

}

protocol NetworkConfiguration {

    var httpClient: HTTPClient { get }
    var authHeaders: [String: String] { get }

}
