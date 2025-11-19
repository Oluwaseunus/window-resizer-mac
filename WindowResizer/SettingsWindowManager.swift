//
//  SettingsWindowManager.swift
//  WindowResizer
//
//  Created by Claude Code
//

import AppKit
import SwiftUI

/// Manages the settings window lifecycle, ensuring only one instance exists
class SettingsWindowManager {
    static let shared = SettingsWindowManager()

    private var settingsWindow: NSWindow?

    private init() {}

    /// Opens or focuses the settings window
    func openSettings() {
        if let window = settingsWindow {
            // Window already exists, bring it to front
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Create new settings window
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.setContentSize(NSSize(width: 700, height: 500))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.center()
            window.isReleasedWhenClosed = false

            // Set minimum size
            window.minSize = NSSize(width: 600, height: 400)

            // Observe window closing to clean up reference
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.settingsWindow = nil
            }

            self.settingsWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
