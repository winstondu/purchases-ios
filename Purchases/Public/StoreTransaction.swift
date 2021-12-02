//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  StoreTransaction.swift
//
//  Created by Andrés Boedo on 2/12/21.

import Foundation
import StoreKit

/// TypeAlias to StoreKit 1's Transaction type, called `StoreKit/SKPaymentTransaction`
public typealias SK1Transaction = SKPaymentTransaction

/// TypeAlias to StoreKit 2's Transaction type, called `StoreKit.Transaction`
@available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *)
public typealias SK2Transaction = StoreKit.Transaction

/// Abstract class that provides access to all of StoreKit's product type's properties.
@objc(RCStoreTransaction) public class StoreTransaction: NSObject {

    // TODO would it be more useful to expose the product?
    // get logic from skpaymenttransaction+extensions
    // because it comes from the SKPayment, and it might be unexpectedly `nil` in the SKPayment.
    @objc public var productIdentifier: String { }

//    // Only set if state is SKPaymentTransactionFailed
//    @available(iOS 3.0, *)
//    open var error: Error? { get }
//
//
//    // Only valid if state is SKPaymentTransactionStateRestored.
//    @available(iOS 3.0, *)
//    open var original: SKPaymentTransaction? { get }
//
//
//    @available(iOS 3.0, *)
//    open var payment: SKPayment { get }
//
//
//    // Available downloads (SKDownload) for this transaction
//    @available(iOS 6.0, *)
//    open var downloads: [SKDownload] { get }
//
//
//    // The date when the transaction was added to the server queue.  Only valid if state is SKPaymentTransactionStatePurchased or SKPaymentTransactionStateRestored.
//    @available(iOS 3.0, *)
//    open var transactionDate: Date? { get }
//
//
//    // The unique server-provided identifier.  Only valid if state is SKPaymentTransactionStatePurchased or SKPaymentTransactionStateRestored.
//    @available(iOS 3.0, *)
//    open var transactionIdentifier: String? { get }
//
//
//    @available(iOS 3.0, *)
//    open var transactionState: SKPaymentTransactionState { get }
}
