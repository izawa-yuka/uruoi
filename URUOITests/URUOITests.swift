//
//  URUOITests.swift
//  URUOITests
//

import XCTest
@testable import URUOI

final class URUOITests: XCTestCase {
    private var userDefaults: UserDefaults!
    private let pendingOperationsKey = "PendingSyncOperationStoreTests.operations"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "PendingSyncOperationStoreTests")
        userDefaults.removePersistentDomain(forName: "PendingSyncOperationStoreTests")
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "PendingSyncOperationStoreTests")
        userDefaults = nil
        super.tearDown()
    }

    func testTestTargetIsConfigured() {
        XCTAssertTrue(true)
    }

    func testPendingSyncOperationStoreSavesAndLoadsOperations() {
        let store = PendingSyncOperationStore(key: pendingOperationsKey, userDefaults: userDefaults)
        let container = ContainerMaster(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Kitchen",
            emptyWeight: 120,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sortOrder: 2
        )
        let record = WaterRecord(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            containerID: container.id,
            startTime: Date(timeIntervalSince1970: 1_700_000_100),
            startWeight: 500,
            endTime: Date(timeIntervalSince1970: 1_700_000_200),
            endWeight: 420,
            catCount: 2,
            weatherCondition: "sun.max",
            temperature: 24,
            note: "test",
            container: container,
            createdByDeviceID: "test-device"
        )
        let operations: [PendingSyncOperation] = [
            .saveContainer(householdID: "household", container: FirestoreContainer(from: container)),
            .saveRecord(householdID: "household", record: FirestoreRecord(from: record)),
            .deleteContainer(householdID: "household", id: container.id.uuidString),
            .deleteRecord(householdID: "household", id: record.id.uuidString)
        ]

        store.save(operations)

        XCTAssertEqual(store.load(), operations)
    }

    func testPendingSyncOperationStoreRemovesKeyWhenSavingEmptyQueue() {
        let store = PendingSyncOperationStore(key: pendingOperationsKey, userDefaults: userDefaults)
        store.save([
            .deleteRecord(householdID: "household", id: "record-id")
        ])

        store.save([])

        XCTAssertNil(userDefaults.data(forKey: pendingOperationsKey))
        XCTAssertEqual(store.load(), [])
    }

    func testPendingSyncOperationStoreDropsCorruptData() {
        let store = PendingSyncOperationStore(key: pendingOperationsKey, userDefaults: userDefaults)
        userDefaults.set(Data("not-json".utf8), forKey: pendingOperationsKey)

        XCTAssertEqual(store.load(), [])
        XCTAssertNil(userDefaults.data(forKey: pendingOperationsKey))
    }

    func testWaterIntakeCalculatorDistributesMultiDayRecordBeforeCollectionDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let record = WaterRecord(
            containerID: UUID(),
            startTime: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))),
            startWeight: 500,
            endTime: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 4, hour: 9))),
            endWeight: 200,
            catCount: 1
        )
        let interval = DateInterval(
            start: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))),
            end: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 5)))
        )

        let totals = WaterIntakeCalculator.dailyTotals(from: [record], in: interval, calendar: calendar)

        XCTAssertEqual(totals[try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))], 100)
        XCTAssertEqual(totals[try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2)))], 100)
        XCTAssertEqual(totals[try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3)))], 100)
        XCTAssertNil(totals[try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 4)))])
    }

    func testWaterIntakeCalculatorKeepsSameDayRecordOnThatDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let record = WaterRecord(
            containerID: UUID(),
            startTime: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))),
            startWeight: 500,
            endTime: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 18))),
            endWeight: 420,
            catCount: 1
        )
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let interval = DateInterval(
            start: day,
            end: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2)))
        )

        let totals = WaterIntakeCalculator.dailyTotals(from: [record], in: interval, calendar: calendar)

        XCTAssertEqual(totals[day], 80)
    }
}
