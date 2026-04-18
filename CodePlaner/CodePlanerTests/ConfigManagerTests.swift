import XCTest
@testable import CodePlaner

final class ConfigManagerTests: XCTestCase {
    var tempConfigURL: URL!
    var configManager: ConfigManager!
    var keychain: KeychainManager!
    var keychainServiceName: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempConfigURL = tempDir.appendingPathComponent("test_config_\(UUID().uuidString).json")
        keychainServiceName = "com.codingplan.tests.\(UUID().uuidString)"
        keychain = KeychainManager(service: keychainServiceName)
        
        // Create a dummy config file
        let initialConfig: [String: Any] = [
            "default_provider": "bailian",
            "fallback_enabled": true,
            "providers": [
                "bailian": [
                    "enabled": true,
                    "base_url": "https://api.example.com",
                    "models": ["qwen-max"]
                ]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: initialConfig, options: .prettyPrinted)
        try! data.write(to: tempConfigURL)
        
        configManager = ConfigManager(
            configPath: tempConfigURL.path,
            keychain: keychain
        )
    }

    override func tearDown() {
        _ = keychain.delete(key: "bailian")
        try? FileManager.default.removeItem(at: tempConfigURL)
        super.tearDown()
    }

    func testLoadConfig() {
        XCTAssertEqual(configManager.defaultProvider, "bailian")
        XCTAssertTrue(configManager.fallbackEnabled)
        XCTAssertEqual(configManager.providers.count, 1)
        XCTAssertEqual(configManager.providers.first?.name, "bailian")
        XCTAssertTrue(configManager.providers.first?.enabled ?? false)
    }

    func testUpdateProvider() {
        configManager.updateProvider(name: "bailian", enabled: false)
        XCTAssertFalse(configManager.providers.first?.enabled ?? true)
        
        // Verify persistence
        let reloadedManager = ConfigManager(
            configPath: tempConfigURL.path,
        )
        XCTAssertFalse(reloadedManager.providers.first?.enabled ?? true)
    }

    func testSetDefaultProvider() {
        configManager.setDefaultProvider("deepseek")
        XCTAssertEqual(configManager.defaultProvider, "deepseek")
        
        // Verify persistence
        let reloadedManager = ConfigManager(
            configPath: tempConfigURL.path,
        )
        XCTAssertEqual(reloadedManager.defaultProvider, "deepseek")
    }

    func testSetFallbackEnabled() {
        configManager.setFallbackEnabled(false)
        XCTAssertFalse(configManager.fallbackEnabled)
        
        // Verify persistence
        let reloadedManager = ConfigManager(
            configPath: tempConfigURL.path,
        )
        XCTAssertFalse(reloadedManager.fallbackEnabled)
    }

    func testSetServicePort() {
        configManager.setServicePort(18900)
        XCTAssertEqual(configManager.servicePort, 18900)

        let reloadedManager = ConfigManager(
            configPath: tempConfigURL.path,
            keychain: keychain
        )
        XCTAssertEqual(reloadedManager.servicePort, 18900)
    }

    func testSetAPIKeyPersistsEncryptedValueToConfig() throws {
        configManager.setAPIKey(provider: "bailian", key: "sk-test-key")

        let data = try Data(contentsOf: tempConfigURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let providers = try XCTUnwrap(json?["providers"] as? [String: [String: Any]])
        let bailian = try XCTUnwrap(providers["bailian"])
        let encrypted = try XCTUnwrap(bailian["api_key_encrypted"] as? String)

        XCTAssertFalse(encrypted.isEmpty)
        XCTAssertEqual(keychain.load(key: "bailian"), "sk-test-key")
    }

    func testClearingAPIKeyRemovesEncryptedValueFromConfig() throws {
        configManager.setAPIKey(provider: "bailian", key: "sk-test-key")
        configManager.setAPIKey(provider: "bailian", key: "   ")

        let data = try Data(contentsOf: tempConfigURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let providers = try XCTUnwrap(json?["providers"] as? [String: [String: Any]])
        let bailian = try XCTUnwrap(providers["bailian"])
        let encrypted = bailian["api_key_encrypted"] as? String

        XCTAssertEqual(encrypted, "")
        XCTAssertNil(keychain.load(key: "bailian"))
    }
}
