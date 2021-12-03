//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  PeriodAsPriceCalculatorTests.swift
//
//  Created by Andrés Boedo on 3/12/21.

import Foundation
import Nimble
@testable import RevenueCat
import XCTest

class PeriodAsPriceCalculatorTests: XCTestCase {

    func testYearlyPriceAsMonthlyCalculatedCorrectly() {
        let yearlyPrice: Decimal = 120
        let yearlyPeriod = SubscriptionPeriod(value: 1, unit: .year)

        let monthlyPeriod = SubscriptionPeriod(value: 1, unit: .month)

        let resultPrice = PriceAsPeriodCalculator().price(for: yearlyPeriod, as: monthlyPeriod, subscriptionPrice: yearlyPrice)
        expect(resultPrice) == 10
    }

    func testMonthlyPriceAsYearlyCalculatedCorrectly() {
        let monthlyPrice: Decimal = 10
        let yearlyPeriod = SubscriptionPeriod(value: 1, unit: .year)

        let monthlyPeriod = SubscriptionPeriod(value: 1, unit: .month)

        let resultPrice = PriceAsPeriodCalculator().price(for: monthlyPeriod, as: yearlyPeriod, subscriptionPrice: monthlyPrice)
        expect(resultPrice) == 120
    }

//    func testYearlyPriceAsMonthlyCalculatedCorrectly() {
//        let yearlyPrice: Decimal = 120
//        let yearlyPeriod = SubscriptionPeriod(value: 1, unit: .year)
//
//        let monthlyPeriod = SubscriptionPeriod(value: 1, unit: .month)
//
//        let resultPrice = PriceAsPeriodCalculator().price(for: yearlyPeriod, as: monthlyPeriod, subscriptionPrice: yearlyPrice)
//        expect(resultPrice) == 10
//    }

}
