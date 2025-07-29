import Network
import XCTest

import NetworkKit
@testable import NetworkPathMonitor

@MainActor
class NetworkPathMonitorTests: XCTestCase, @unchecked Sendable {
    var monitor: NetworkPathMonitor!
    var customQueue: DispatchQueue!

    override func setUp() async throws {
        try await super.setUp()
        customQueue = DispatchQueue(label: "com.test.networkmonitor")
        monitor = NetworkPathMonitor(queue: customQueue, debounceInterval: .seconds(1.5))
//        monitor = NetworkPathMonitor(queue: customQueue)
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

        var updates: [NetworkPath] = []
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

    @MainActor
    func testPathChangeHandler() async {
        let expectation = XCTestExpectation(description: "Path change handler called")

        await monitor.pathOnChange { _ in
            expectation.fulfill()
        }

        await monitor.fire()

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    @MainActor
    func testPathChangeHandlerPrint() async {
        await monitor.pathOnChange { path in
            print("\(Date().timeIntervalSince1970) - \(path.description)")
        }

        await monitor.fire()
        try? await Task.sleep(nanoseconds: 10000 * 1_000_000_000)
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

    // MARK: - NetworkPath Tests

    func testNetworkTestInitialization() {
        let networkMonitor: NWPathMonitor = .init()
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { @MainActor in
                measureNetworkTestInitialization(path)
            }
        }
        networkMonitor.start(queue: .init(label: "testNetworkTestInitialization"))
    }

    func measureNetworkTestInitialization(_ path: NWPath) {
        measure {
            _ = NetworkPath(nwPath: path)
        }
    }
}
