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

        let resultPrice = PriceAsPeriodCalculator().price(for: yearlyPeriod,
                                                             as: monthlyPeriod,
                                                             subscriptionPrice: yearlyPrice)
        expect(resultPrice) == Decimal(10)
    }

    func testMonthlyPriceAsYearlyCalculatedCorrectly() {
        let monthlyPrice: Decimal = 10
        let yearlyPeriod = SubscriptionPeriod(value: 1, unit: .year)

        let monthlyPeriod = SubscriptionPeriod(value: 1, unit: .month)

        let resultPrice = PriceAsPeriodCalculator().price(for: monthlyPeriod,
                                                             as: yearlyPeriod,
                                                             subscriptionPrice: monthlyPrice)
        expect(resultPrice) == Decimal(120)
    }

    func testYearlyPriceAsWeeklyCalculatedCorrectly() {
        let yearlyPrice: Decimal = 120
        let yearlyPeriod = SubscriptionPeriod(value: 1, unit: .year)

        let weeklyPeriod = SubscriptionPeriod(value: 1, unit: .week)

        let resultPrice = PriceAsPeriodCalculator().price(for: yearlyPeriod,
                                                             as: weeklyPeriod,
                                                             subscriptionPrice: yearlyPrice)
        expect(resultPrice) == Decimal(2.3)
    }


    func testYearlyPriceAsBiWeeklyCalculatedCorrectly() {
        let yearlyPrice: Decimal = 100
        let yearlyPeriod = SubscriptionPeriod(value: 1, unit: .year)

        let biWeeklyPeriod = SubscriptionPeriod(value: 2, unit: .week)

        let resultPrice = PriceAsPeriodCalculator().price(for: yearlyPeriod,
                                                             as: biWeeklyPeriod,
                                                             subscriptionPrice: yearlyPrice)
        expect(resultPrice) == Decimal(3.84)
    }

    func testWeeklyPriceAsOthersCalculatedCorrectly() {
        let weeklyPrice: Decimal = 7.99
        let weeklyPeriod = SubscriptionPeriod(value: 1, unit: .week)

        var targetPeriod = SubscriptionPeriod(value: 1, unit: .day)

        var resultPrice = PriceAsPeriodCalculator().price(for: weeklyPeriod,
                                                             as: targetPeriod,
                                                             subscriptionPrice: weeklyPrice)
        expect(resultPrice) == Decimal(1.14)

        targetPeriod = SubscriptionPeriod(value: 1, unit: .week)

        resultPrice = PriceAsPeriodCalculator().price(for: weeklyPeriod,
                                                             as: targetPeriod,
                                                             subscriptionPrice: weeklyPrice)
        expect(resultPrice) == Decimal(7.99)

        targetPeriod = SubscriptionPeriod(value: 1, unit: .month)

        resultPrice = PriceAsPeriodCalculator().price(for: weeklyPeriod,
                                                             as: targetPeriod,
                                                             subscriptionPrice: weeklyPrice)
        expect(resultPrice) == Decimal(31.96)

        targetPeriod = SubscriptionPeriod(value: 3, unit: .month)

        resultPrice = PriceAsPeriodCalculator().price(for: weeklyPeriod,
                                                             as: targetPeriod,
                                                             subscriptionPrice: weeklyPrice)
        expect(resultPrice) == Decimal(95.88)

        targetPeriod = SubscriptionPeriod(value: 1, unit: .year)

        resultPrice = PriceAsPeriodCalculator().price(for: weeklyPeriod,
                                                             as: targetPeriod,
                                                             subscriptionPrice: weeklyPrice)
        expect(resultPrice) == Decimal(415.48)


    }
}
