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

    // swiftlint:disable:next cyclomatic_complexity
    func dividingFactor(for fromSubscriptionPeriod: SubscriptionPeriod,
                        as toSubscriptionPeriod: SubscriptionPeriod) -> Decimal {
        switch fromSubscriptionPeriod.unit {
        case .day:
            switch toSubscriptionPeriod.unit {
            case .day: return 1.0
            case .week: return 1 / 7.0
            case .month: return 1 / 30.0
            case .year: return 1 / 365.0
            case .unknown: return 0.0
            }
        case .week:
            switch toSubscriptionPeriod.unit {
            case .day: return  7.0
            case .week: return  1.0
            case .month: return  1 / 4.0
            case .year: return  1 / 52.0
            case .unknown: return 0.0
            }
        case .month:
            switch toSubscriptionPeriod.unit {
            case .day: return 30.0
            case .week: return 4.0
            case .month: return 1.0
            case .year: return 1 / 12.0
            case .unknown: return 0.0
            }
        case .year:
            switch toSubscriptionPeriod.unit {
            case .day: return 365.0
            case .week: return 52.0
            case .month: return 12.0
            case .year: return 1.0
            case .unknown: return 0.0
            }
        case .unknown:
            return 0.0
        }
    }

    func price(for fromSubscriptionPeriod: SubscriptionPeriod,
               as toSubscriptionPeriod: SubscriptionPeriod,
               subscriptionPrice: Decimal) -> Decimal {
        let dividingFactor = dividingFactor(for: fromSubscriptionPeriod, as: toSubscriptionPeriod)
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
