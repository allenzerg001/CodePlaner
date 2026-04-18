import Foundation
import Combine

final class AppRuntime: ObservableObject {
    static let shared = AppRuntime()

    let configManager: ConfigManager
    let usageService: UsageStatsService
    let pythonManager: PythonProcessManager

    private init() {
        self.configManager = ConfigManager()
        self.usageService = UsageStatsService()
        self.pythonManager = PythonProcessManager(configManager: configManager)
    }
}
