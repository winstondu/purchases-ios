//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  PriceAsPeriodCalculator.swift
//
//  Created by Andrés Boedo on 3/12/21.

import Foundation

struct PriceAsPeriodCalculator {
    private let factorsByStartAndTargetPeriod: [SubscriptionPeriod.PeriodUnit: [SubscriptionPeriod.PeriodUnit: Decimal]] = [
        .day: [
            .day: 1.0,
            .week: 1 / 7.0,
            .month: 1 / 30.0,
            .year: 1 / 365.0
        ],
        .week: [
            .day: 7.0,
            .week: 1.0,
            .month: 1 / 4.0,
            .year: 1 / 52.0
        ],
        .month: [
            .day: 30.0,
            .week: 4.0,
            .month: 1.0,
            .year: 1 / 12.0
        ],
        .year: [
            .day: 365.0,
            .week: 52.0,
            .month: 12.0,
            .year: 1.0
        ]
    ]

    func price(for fromSubscriptionPeriod: SubscriptionPeriod,
               as toSubscriptionPeriod: SubscriptionPeriod,
               subscriptionPrice: Decimal) -> Decimal {
        guard let dividingFactor = factorsByStartAndTargetPeriod[fromSubscriptionPeriod.unit]?[toSubscriptionPeriod.unit] else {
            return 0.0
        }
        let behavior = NSDecimalNumberHandler(roundingMode: .down,
                                              scale: 2,
                                              raiseOnExactness: false,
                                              raiseOnOverflow: false,
                                              raiseOnUnderflow: false,
                                              raiseOnDivideByZero: false)

        let toPrice = (subscriptionPrice as NSDecimalNumber).dividing(by: NSDecimalNumber(decimal: dividingFactor),
                                                                      withBehavior: behavior)
        return toPrice as Decimal
    }

}
