import XCTest
@testable import CodePlaner

final class PythonProcessManagerTests: XCTestCase {
    private final class TestablePythonProcessManager: PythonProcessManager {
        var availablePorts: Set<Int> = []
        var healthyPorts: Set<Int> = []
        var nextEphemeralPort: Int?

        override func isPortAvailable(_ port: Int) -> Bool {
            availablePorts.contains(port)
        }

        override func isServiceHealthy(on port: Int) -> Bool {
            healthyPorts.contains(port)
        }

        override func ephemeralPort() -> Int? {
            nextEphemeralPort
        }
    }

    func testStopWaitsForManagedProcessToExit() throws {
        let manager = PythonProcessManager(terminationTimeout: 0.2)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 30"]

        try process.run()
        XCTAssertTrue(process.isRunning)

        manager.attachProcessForTesting(process)

        manager.stop(waitUntilStopped: true)

        XCTAssertFalse(process.isRunning)
    }

    func testResolveLaunchTargetReusesHealthyExistingServiceOnConfiguredPort() {
        let manager = TestablePythonProcessManager()
        manager.availablePorts = []
        manager.healthyPorts = [55583]

        XCTAssertEqual(manager.resolveLaunchTarget(preferredPort: 55583), .reuseExisting(55583))
    }

    func testResolveLaunchTargetKeepsConfiguredPortFixedWhenUnavailable() {
        let manager = TestablePythonProcessManager()
        manager.availablePorts = []
        manager.healthyPorts = []
        manager.nextEphemeralPort = 59277

        XCTAssertEqual(manager.resolveLaunchTarget(preferredPort: 55583), .unavailable(55583))
    }

    func testResolveLaunchTargetFallsBackOnlyOnFirstDefaultPort() {
        let manager = TestablePythonProcessManager()
        manager.availablePorts = []
        manager.healthyPorts = []
        manager.nextEphemeralPort = 59277

        XCTAssertEqual(manager.resolveLaunchTarget(preferredPort: 9800), .launch(59277))
    }
}
