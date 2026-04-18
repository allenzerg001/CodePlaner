import Foundation
import Combine
import Darwin

class PythonProcessManager: ObservableObject {
    enum LaunchTarget: Equatable {
        case launch(Int)
        case reuseExisting(Int)
        case unavailable(Int)
    }

    @Published var isRunning = false
    @Published var lastError: String?
    @Published private(set) var servicePort = 9800
    @Published var localAPIKey = "sk-codingplan-local"

    private let stateQueue = DispatchQueue(label: "com.codingplan.python-process", qos: .userInitiated)
    private let stateQueueKey = DispatchSpecificKey<Void>()
    private var process: Process?
    private var isStarting = false
    private let configManager: ConfigManager?
    private let terminationTimeout: TimeInterval
    private var configCancellable: AnyCancellable?

    init(configManager: ConfigManager? = nil, terminationTimeout: TimeInterval = 2.0) {
        self.configManager = configManager
        self.terminationTimeout = terminationTimeout
        self.servicePort = configManager?.servicePort ?? 9800
        self.localAPIKey = configManager?.localAPIKey ?? "sk-codingplan-local"
        self.stateQueue.setSpecific(key: stateQueueKey, value: ())

        if let config = configManager {
            config.$localAPIKey
                .dropFirst() // Skip the initial value during init
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newKey in
                    self?.localAPIKey = newKey
                }
                .store(in: &cancellables)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    var serviceURL: String {
        "http://127.0.0.1:\(servicePort)"
    }

    var lanServiceURL: String {
        if let lanIP = localLANAddress() {
            return "http://\(lanIP):\(servicePort)"
        }
        return serviceURL
    }

    private func localLANAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var pointer = ifaddr
        while let p = pointer {
            let addr = p.pointee.ifa_addr
            if addr?.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: p.pointee.ifa_name)
                if name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, socklen_t(addr!.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        if ip.hasPrefix("192.168.") || ip.hasPrefix("10.") {
                            return ip
                        }
                    }
                }
            }
            pointer = p.pointee.ifa_next
        }
        return nil
    }

    func start() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.process == nil, !self.isStarting else { return }
            self.isStarting = true
            self.launchService()
        }
    }

    private func launchService() {
        let serviceBaseDir = findServicePath()
        let preferredPort = configManager?.servicePort ?? servicePort
        let launchTarget = resolveLaunchTarget(preferredPort: preferredPort)

        switch launchTarget {
        case .reuseExisting(let port):
            isStarting = false
            DispatchQueue.main.async {
                self.servicePort = port
                self.isRunning = true
                self.lastError = nil
            }
            return
        case .unavailable(let port):
            isStarting = false
            DispatchQueue.main.async {
                self.isRunning = false
                self.lastError = "Configured service port \(port) is unavailable"
            }
            return
        case .launch(let launchPort):
            launchService(on: launchPort, serviceBaseDir: serviceBaseDir)
        }
    }

    private func setupEnvironment(launchPort: Int, serviceHost: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PORT"] = "\(launchPort)"
        env["HOST"] = serviceHost
        
        // Ensure common paths are in PATH
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let commonPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "\(home)/.nvm/current/bin",
            "\(home)/.npm-global/bin",
            "\(home)/.bun/bin"
        ]
        
        let currentPath = env["PATH"] ?? ""
        let additionalPaths = commonPaths.joined(separator: ":")
        env["PATH"] = currentPath.isEmpty ? additionalPaths : "\(additionalPaths):\(currentPath)"
        
        return env
    }

    private func launchService(on launchPort: Int, serviceBaseDir: String) {
        let serviceHost = configManager?.allowLAN == true ? "0.0.0.0" : "127.0.0.1"
        let process = Process()
        let shouldPreferDevelopmentLauncher = isDevelopmentServicePath(serviceBaseDir)

        let nodeBundlePath = (serviceBaseDir as NSString).appendingPathComponent("dist/index.js")
        let executablePath = (serviceBaseDir as NSString).appendingPathComponent("dist/codingplan-service")
        let mainTsPath = (serviceBaseDir as NSString).appendingPathComponent("src/main.ts")

        if FileManager.default.fileExists(atPath: nodeBundlePath) && !shouldPreferDevelopmentLauncher {
            // Run Node.js bundle
            let node = findNodeInterpreter()
            process.executableURL = URL(fileURLWithPath: node)
            process.arguments = [nodeBundlePath, "--host", serviceHost, "--port", "\(launchPort)"]
        } else if FileManager.default.isExecutableFile(atPath: executablePath) && !shouldPreferDevelopmentLauncher {
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = ["--host", serviceHost, "--port", "\(launchPort)"]
        } else if FileManager.default.fileExists(atPath: mainTsPath) {
            // Development mode - prefer bun for running src/main.ts
            let bun = findBunInterpreter()
            process.executableURL = URL(fileURLWithPath: bun)
            process.arguments = ["run", mainTsPath, "--host", serviceHost, "--port", "\(launchPort)"]
        } else {
            let python = findPythonInterpreter(serviceDir: serviceBaseDir)
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = ["-m", "uvicorn", "src.main:app", "--host", serviceHost, "--port", "\(launchPort)"]
        }

        process.currentDirectoryURL = URL(fileURLWithPath: serviceBaseDir)
        process.environment = setupEnvironment(launchPort: launchPort, serviceHost: serviceHost)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { [weak self] terminatedProcess in
            guard let self = self else { return }
            self.stateQueue.async {
                if self.process === terminatedProcess {
                    self.process = nil
                }
                self.isStarting = false
                DispatchQueue.main.async {
                    self.isRunning = false
                    if terminatedProcess.terminationStatus != 0 && self.lastError == nil {
                        self.lastError = "Service exited with code \(terminatedProcess.terminationStatus)"
                    }
                }
            }
        }
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("[CodingPlan Service] \(output)")
            }
        }

        do {
            DispatchQueue.main.async {
                self.servicePort = launchPort
                self.configManager?.setServicePort(launchPort)
            }
            try process.run()
            self.process = process
            self.isStarting = false
            DispatchQueue.main.async {
                self.isRunning = process.isRunning
                self.lastError = nil
            }
        } catch {
            isStarting = false
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
                self.isRunning = false
            }
        }
    }

    func stop(waitUntilStopped: Bool = false) {
        let work: () -> Void = { [weak self] in
            self?.stopOnStateQueue()
        }

        if waitUntilStopped {
            if DispatchQueue.getSpecific(key: stateQueueKey) != nil {
                work()
            } else {
                stateQueue.sync(execute: work)
            }
        } else {
            stateQueue.async(execute: work)
        }
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.start()
        }
    }

    private func findTsxInterpreter() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/tsx",
            "/usr/local/bin/tsx",
            "/usr/bin/tsx",
            "\(home)/.npm-global/bin/tsx",
            "/opt/homebrew/bin/npx", // Fallback to npx tsx if tsx is not in path
        ]

        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }
        
        return "/usr/bin/npx" // Last resort
    }

    private func findNodeInterpreter() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
            "\(home)/.nvm/current/bin/node"
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/usr/bin/node"
    }

    private func findBunInterpreter() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.bun/bin/bun",
            "/opt/homebrew/bin/bun",
            "/usr/local/bin/bun",
            "/usr/bin/bun"
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/usr/local/bin/bun"
    }

    private func findPythonInterpreter(serviceDir: String) -> String {
        // venv inside service directory takes highest priority
        let venvPython = (serviceDir as NSString).appendingPathComponent("venv/bin/python3")
        if FileManager.default.isExecutableFile(atPath: venvPython) {
            return venvPython
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/Works/miniconda3/bin/python3",
            "\(home)/miniconda3/bin/python3",
            "\(home)/anaconda3/bin/python3",
            "\(home)/.pyenv/shims/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/usr/bin/python3"
    }

    private func findServicePath() -> String {
        let appBundle = Bundle.main.bundlePath
        let servicePath = (appBundle as NSString).appendingPathComponent("Contents/Resources/service")

        if FileManager.default.fileExists(atPath: servicePath) {
            return servicePath
        }

        let devPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("service").path

        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        return "."
    }

    private func isDevelopmentServicePath(_ path: String) -> Bool {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let bundleResourcePath = (Bundle.main.bundlePath as NSString).appendingPathComponent("Contents/Resources/service")
        let normalizedBundlePath = URL(fileURLWithPath: bundleResourcePath).standardizedFileURL.path
        return normalizedPath != normalizedBundlePath
    }

    func resolveLaunchTarget(preferredPort: Int) -> LaunchTarget {
        if isPortAvailable(preferredPort) {
            return .launch(preferredPort)
        }

        if isServiceHealthy(on: preferredPort) {
            return .reuseExisting(preferredPort)
        }

        if preferredPort == 9800, let port = ephemeralPort() {
            return .launch(port)
        }

        return .unavailable(preferredPort)
    }

    func isPortAvailable(_ port: Int) -> Bool {
        socketBoundPort(requestedPort: port) != nil
    }

    func ephemeralPort() -> Int? {
        socketBoundPort(requestedPort: 0)
    }

    func isServiceHealthy(on port: Int) -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/admin/status") else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5

        let semaphore = DispatchSemaphore(value: 0)
        var healthy = false

        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) {
                healthy = true
            }
            semaphore.signal()
        }
        task.resume()

        if semaphore.wait(timeout: .now() + 1.0) == .timedOut {
            task.cancel()
            return false
        }

        return healthy
    }

    private func socketBoundPort(requestedPort: Int) -> Int? {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return nil }
        defer { close(socketFD) }

        var reuseAddr: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(requestedPort).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.stride))
            }
        }

        guard bindResult == 0 else { return nil }

        var boundAddress = address
        var length = socklen_t(MemoryLayout<sockaddr_in>.stride)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(socketFD, sockaddrPointer, &length)
            }
        }

        guard nameResult == 0 else { return nil }
        return Int(UInt16(bigEndian: boundAddress.sin_port))
    }

    private func stopOnStateQueue() {
        isStarting = false
        guard let process = self.process else {
            DispatchQueue.main.async {
                self.isRunning = false
            }
            return
        }

        self.process = nil
        process.terminationHandler = nil
        if let pipe = process.standardOutput as? Pipe {
            pipe.fileHandleForReading.readabilityHandler = nil
        }
        if process.standardError as AnyObject !== process.standardOutput as AnyObject,
           let pipe = process.standardError as? Pipe {
            pipe.fileHandleForReading.readabilityHandler = nil
        }

        terminate(process)

        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    private func terminate(_ process: Process) {
        guard process.isRunning else { return }

        process.terminate()
        let deadline = Date().addingTimeInterval(terminationTimeout)

        while process.isRunning && Date() < deadline {
            usleep(50_000)
        }

        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
    }

    deinit {
        stop(waitUntilStopped: true)
    }

    func attachProcessForTesting(_ process: Process) {
        if DispatchQueue.getSpecific(key: stateQueueKey) != nil {
            self.process = process
            self.isStarting = false
        } else {
            stateQueue.sync {
                self.process = process
                self.isStarting = false
            }
        }
        isRunning = process.isRunning
    }
}
