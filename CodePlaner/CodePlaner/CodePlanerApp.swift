//
//  CodePlanerApp.swift
//  CodePlaner
//
//  Created by Allen on 2026/4/16.
//

import SwiftUI

@main
struct CodePlanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let runtime = AppRuntime.shared

    var body: some Scene {
        WindowGroup {
            MainView(config: runtime.configManager, usageService: runtime.usageService)
        }
        .windowStyle(HiddenTitleBarWindowStyle())

        Settings {
            SettingsView(config: runtime.configManager)
        }
    }
}
