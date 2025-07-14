import Network
import XCTest

@testable import NetworkPathMonitor

@MainActor
class NetworkPathMonitorTests: XCTestCase, @unchecked Sendable {
    var monitor: NetworkPathMonitor!
    var customQueue: DispatchQueue!

    override func setUp() async throws {
        try await super.setUp()
        customQueue = DispatchQueue(label: "com.test.networkmonitor")
        monitor = NetworkPathMonitor(queue: customQueue)
    }

    override func tearDown() async throws {
        monitor = nil
        customQueue = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() async {
        let isActive = await monitor.isActive
        XCTAssertFalse(isActive)
        let currentPath = await monitor.currentPath
        XCTAssertNotNil(currentPath)

        // Test with custom debounce interval
        let debounceMonitor = NetworkPathMonitor(debounceInterval: .seconds(1.0))
        let debounceIsActive = await debounceMonitor.isActive
        XCTAssertFalse(debounceIsActive)
    }

    // MARK: - Fire and Invalidate Tests

    func testFireAndInvalidate() async {
        // Test fire
        await monitor.fire()
        let isActiveAfterFire = await monitor.isActive
        XCTAssertTrue(isActiveAfterFire)

        // Test invalidate
        await monitor.invalidate()
        let isActiveAfterInvalidate = await monitor.isActive
        XCTAssertFalse(isActiveAfterInvalidate)

        // Test double fire
        await monitor.fire()
        await monitor.fire() // Should not affect isActive
        let isActiveAfterDoubleFire = await monitor.isActive
        XCTAssertTrue(isActiveAfterDoubleFire)

        // Test double invalidate
        await monitor.invalidate()
        await monitor.invalidate() // Should not affect isActive
        let isActiveAfterDoubleInvalidate = await monitor.isActive
        XCTAssertFalse(isActiveAfterDoubleInvalidate)
    }

    // MARK: - Path Updates Tests

    func testPathUpdatesStream() async {
        await monitor.fire()

        var updates: [NWPath] = []
        let expectation = XCTestExpectation(description: "Receive path updates")

        // Create a task to collect updates
        let task = Task { @MainActor in
            for await update in await self.monitor.pathUpdates {
                updates.append(update)
                if updates.count >= 1 {
                    expectation.fulfill()
                }
            }
        }

        // Wait for updates
        await fulfillment(of: [expectation], timeout: 5.0)

        // Clean up
        task.cancel()
        await monitor.invalidate()

        XCTAssertFalse(updates.isEmpty)
    }

    // MARK: - Path Change Handler Tests

    func testPathChangeHandler() async {
        let expectation = XCTestExpectation(description: "Path change handler called")

        await monitor.pathOnChange { _ in
            expectation.fulfill()
        }

        await monitor.fire()

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // MARK: - Notification Tests

    func testNetworkStatusChangeNotification() async {
        let expectation = XCTestExpectation(
            description: "Network status change notification received")

        // Setup notification observer
        let observer = NotificationCenter.default.addObserver(
            forName: NetworkPathMonitor.networkStatusDidChangeNotification,
            object: nil,
            queue: nil
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["newPath"])
            expectation.fulfill()
        }

        await monitor.fire()

        await fulfillment(of: [expectation], timeout: 5.0)

        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Debounce Tests

    func testDebounceInterval() async throws {
        let debounceMonitor = NetworkPathMonitor(debounceInterval: .seconds(0.5))
        let expectation = XCTestExpectation(description: "Debounced path update")
        var updateCount = 0

        await debounceMonitor.pathOnChange { @MainActor _ in
            updateCount += 1
            if updateCount == 1 {
                expectation.fulfill()
            }
        }

        await debounceMonitor.fire()

        // Wait for debounced updates
        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(updateCount, 1)
    }

    // MARK: - IsSatisfied Tests

    func testIsSatisfiedProperty() async {
        let satisfied = await monitor.isPathSatisfied
        let currentPathSatisfied = await monitor.currentPath.isSatisfied
        XCTAssertEqual(satisfied, currentPathSatisfied)
    }

    // MARK: - IgnoreFirstPathUpdate Tests

    func testIgnoreFirstPathUpdateEnabled() async {
        let ignoreFirstMonitor = NetworkPathMonitor(ignoreFirstPathUpdate: true)
        let expectation = XCTestExpectation(description: "First update should be ignored")
        expectation.isInverted = true // We expect this NOT to be fulfilled

        var updateCount = 0
        await ignoreFirstMonitor.pathOnChange { @MainActor _ in
            updateCount += 1
            expectation.fulfill()
        }

        await ignoreFirstMonitor.fire()

        // Wait briefly to ensure no updates are received
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(updateCount, 0, "First update should be ignored")

        await ignoreFirstMonitor.invalidate()
    }

    func testIgnoreFirstPathUpdateDisabled() async {
        let normalMonitor = NetworkPathMonitor(ignoreFirstPathUpdate: false)
        let expectation = XCTestExpectation(description: "First update should be received")

        var updateCount = 0
        await normalMonitor.pathOnChange { @MainActor _ in
            updateCount += 1
            expectation.fulfill()
        }

        await normalMonitor.fire()

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertEqual(updateCount, 1, "First update should be received")

        await normalMonitor.invalidate()
    }

    func testIgnoreFirstPathUpdateWithAsyncStream() async {
        let ignoreFirstMonitor = NetworkPathMonitor(ignoreFirstPathUpdate: true)
        await ignoreFirstMonitor.fire()

        var updates: [NWPath] = []
        let expectation = XCTestExpectation(description: "First update should be ignored in stream")
        expectation.isInverted = true

        let task = Task { @MainActor in
            for await update in await ignoreFirstMonitor.pathUpdates {
                updates.append(update)
                expectation.fulfill()
                break // Only check for first update
            }
        }

        // Wait briefly to ensure no updates are received
        await fulfillment(of: [expectation], timeout: 1.0)

        task.cancel()
        await ignoreFirstMonitor.invalidate()

        XCTAssertTrue(updates.isEmpty, "No updates should be received in stream when ignoring first update")
    }

    func testIgnoreFirstPathUpdateWithNotification() async {
        let ignoreFirstMonitor = NetworkPathMonitor(ignoreFirstPathUpdate: true)
        let expectation = XCTestExpectation(description: "First notification should be ignored")
        expectation.isInverted = true

        let observer = NotificationCenter.default.addObserver(
            forName: NetworkPathMonitor.networkStatusDidChangeNotification,
            object: ignoreFirstMonitor,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }

        await ignoreFirstMonitor.fire()

        // Wait briefly to ensure no notifications are received
        await fulfillment(of: [expectation], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
        await ignoreFirstMonitor.invalidate()
    }

    func testIgnoreFirstPathUpdateWithDebounce() async {
        let debounceIgnoreMonitor = NetworkPathMonitor(
            debounceInterval: .seconds(0.5),
            ignoreFirstPathUpdate: true
        )
        let expectation = XCTestExpectation(description: "First debounced update should be ignored")
        expectation.isInverted = true

        var updateCount = 0
        await debounceIgnoreMonitor.pathOnChange { @MainActor _ in
            updateCount += 1
            expectation.fulfill()
        }

        await debounceIgnoreMonitor.fire()

        // Wait longer than debounce interval to ensure no updates
        await fulfillment(of: [expectation], timeout: 1.5)

        XCTAssertEqual(updateCount, 0, "First debounced update should be ignored")

        await debounceIgnoreMonitor.invalidate()
    }
}
