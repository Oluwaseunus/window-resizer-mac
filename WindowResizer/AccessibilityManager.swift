//
//  AccessibilityManager.swift
//  WindowResizer
//
//  Created by Oluwaseun Adetunji on 08/12/2024.
//

import Cocoa
import AppKit
import Foundation
import ApplicationServices

/// AccessibilityManager provides window resizing and centering using Accessibility APIs with correct top-left coordinate handling.
class AccessibilityManager: NSObject {
    static let shared = AccessibilityManager()

    // MARK: - App Exclusion
    private static let excludedAppsKey = "excludedAppBundleIDs"
    private var excludedAppBundleIDs: Set<String> = []

    override init() {
        super.init()
        loadExcludedApps()
    }

    private func loadExcludedApps() {
        if let savedIDs = UserDefaults.standard.array(forKey: Self.excludedAppsKey) as? [String] {
            excludedAppBundleIDs = Set(savedIDs)
        }
    }

    private func saveExcludedApps() {
        UserDefaults.standard.set(Array(excludedAppBundleIDs), forKey: Self.excludedAppsKey)
    }

    func isAppExcluded(_ bundleID: String) -> Bool {
        return excludedAppBundleIDs.contains(bundleID)
    }

    func toggleAppExclusion(bundleID: String) {
        if excludedAppBundleIDs.contains(bundleID) {
            excludedAppBundleIDs.remove(bundleID)
        } else {
            excludedAppBundleIDs.insert(bundleID)
        }
        saveExcludedApps()
    }

    func getFrontmostAppBundleID() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func getFrontmostAppName() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }

    // MARK: - Public Preset Actions
    @objc func almostMaximize() { resizeActiveWindow(preset: .almostMaximize) }
    @objc func reasonableSize() { resizeActiveWindow(preset: .reasonableSize) }
    @objc func normal() { resizeActiveWindow(preset: .normal) }
    @objc func center() { resizeActiveWindow(preset: .center) }
    @objc func full() { resizeActiveWindow(preset: .full) }
    
    // MARK: - Accessibility Permissions
    func checkAndRequestAccessibilityPermissions() {
        if checkAccessibilityPermissions() {
            registerGlobalHotkeys()
            return
        }
        promptForAccessibilityPermissions()
    }
    
    private func checkAccessibilityPermissions() -> Bool {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func promptForAccessibilityPermissions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "This app needs accessibility permissions to resize windows. Please enable permissions in System Preferences."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            pollAccessibilityPermissions()
        }
    }
    
    private func pollAccessibilityPermissions() {
        if checkAccessibilityPermissions() {
            registerGlobalHotkeys()
        }
    }
    
    // MARK: - Window Positioning Helpers
    enum Preset {
        case reasonableSize, almostMaximize, normal, full, center, smaller, larger, taller, shorter
    }
    
    private func getCurrentScreen(for window: AXUIElement? = nil) -> NSScreen? {
        // Try to use window's position if provided
        if let window = window, let windowPoint = getAXWindowPosition(window: window) {
            for screen in NSScreen.screens {
                if screen.frame.contains(windowPoint) { return screen }
            }
        }
        // Fallback to frontmost window or main screen
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return NSScreen.main }
        let pid = frontApp.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let focusedWindow = focusedWindow else { return NSScreen.main }
      let window = focusedWindow as! AXUIElement
        if let windowPoint = getAXWindowPosition(window: window) {
            for screen in NSScreen.screens {
                if screen.frame.contains(windowPoint) { return screen }
            }
        }
        return NSScreen.main
    }
    
    private func getAXWindowPosition(window: AXUIElement) -> CGPoint? {
        var positionValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
           let axValue = positionValue, AXValueGetType(axValue as! AXValue) == .cgPoint {
            var point = CGPoint.zero
          AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
            return point
        }
        return nil
    }
    
    private func getAXWindowSize(window: AXUIElement) -> CGSize? {
          var sizeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let axValue = sizeValue, AXValueGetType(axValue as! AXValue) == .cgSize {
            var size = CGSize.zero
          AXValueGetValue(axValue as! AXValue, .cgSize, &size)
            return size
        }
        return nil
    }
    
    /// Returns AX coordinate (top-left) to center a given window size on the screen
     private func centeredAXOrigin(for windowSize: CGSize, on screen: NSScreen) -> CGPoint {
         let screenFrame = screen.visibleFrame
         // In AX coordinates, origin is top-left; (0,0) is top-left of main screen
         let centerX = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2

         // Convert screen position from Cocoa (bottom-left origin) to AX (top-left origin)
         let mainScreenHeight = NSScreen.main?.frame.height ?? screenFrame.height
         // Screen's top-left Y in AX coordinates
         let screenTopY_AX = mainScreenHeight - (screenFrame.origin.y + screenFrame.height)
         // Center the window vertically within the screen
         let centerY_AX = screenTopY_AX + (screenFrame.height - windowSize.height) / 2

         return CGPoint(x: centerX, y: centerY_AX)
     }
    
    /// Set window position and size in AX coordinates
    private func setAXWindow(window: AXUIElement, origin: CGPoint, size: CGSize) {
        var mutableOrigin = origin
        var mutableSize = size
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &mutableOrigin)!)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &mutableSize)!)
    }
    
    // MARK: - Window Resizing
    private func applyPreset(_ preset: Preset, to window: AXUIElement, on screen: NSScreen) {
        let frame = screen.visibleFrame
        var newSize = CGSize.zero
        switch preset {
        case .reasonableSize:
            newSize.width = min(frame.width * 0.6, 1024)
            newSize.height = min(frame.height * 0.6, 900)
        case .almostMaximize:
            newSize.width = frame.width * 0.9
            newSize.height = frame.height * 0.9
        case .normal:
            newSize.width = frame.width * 0.6
            newSize.height = frame.height * 0.9
        case .full:
            newSize.width = frame.width * 0.95
            newSize.height = frame.height * 0.95
        case .center:
            newSize = getAXWindowSize(window: window) ?? CGSize(width: frame.width * 0.6, height: frame.height * 0.6)
        case .smaller:
            let curr = getAXWindowSize(window: window) ?? CGSize(width: frame.width * 0.6, height: frame.height * 0.6)
            newSize.width = max(curr.width - frame.width * 0.1, 100)
            newSize.height = curr.height
        case .larger:
            let curr = getAXWindowSize(window: window) ?? CGSize(width: frame.width * 0.6, height: frame.height * 0.6)
            newSize.width = min(curr.width + frame.width * 0.1, frame.width * 0.95)
            newSize.height = curr.height
        case .taller:
            let curr = getAXWindowSize(window: window) ?? CGSize(width: frame.width * 0.6, height: frame.height * 0.6)
            newSize.width = curr.width
            newSize.height = min(curr.height + frame.height * 0.1, frame.height * 0.95)
        case .shorter:
            let curr = getAXWindowSize(window: window) ?? CGSize(width: frame.width * 0.6, height: frame.height * 0.6)
            newSize.width = curr.width
            newSize.height = max(curr.height - frame.height * 0.1, 64)
        }
        let newOrigin = centeredAXOrigin(for: newSize, on: screen)
        setAXWindow(window: window, origin: newOrigin, size: newSize)
    }
    
    private func resizeActiveWindow(preset: Preset) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else { return }
        let window = focusedWindow as! AXUIElement
        guard let screen = getCurrentScreen(for: window) else { return }
        applyPreset(preset, to: window, on: screen)
    }
    
    // MARK: - Hotkey Registration
    private func registerGlobalHotkeys() {
        _ = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.control) {
                // Check if current frontmost app is excluded from shortcuts
                if let bundleID = self.getFrontmostAppBundleID(), self.isAppExcluded(bundleID) {
                    return
                }

                if event.modifierFlags.contains(.option) {
                    switch event.charactersIgnoringModifiers {
                    case String(UnicodeScalar(NSLeftArrowFunctionKey)!):
                        self.resizeActiveWindow(preset: .smaller)
                    case String(UnicodeScalar(NSRightArrowFunctionKey)!):
                        self.resizeActiveWindow(preset: .larger)
                    case String(UnicodeScalar(NSUpArrowFunctionKey)!):
                        self.resizeActiveWindow(preset: .taller)
                    case String(UnicodeScalar(NSDownArrowFunctionKey)!):
                        self.resizeActiveWindow(preset: .shorter)
                    default: break
                    }
                }
                switch event.charactersIgnoringModifiers {
                case "n": self.resizeActiveWindow(preset: .normal)
                case "r": self.resizeActiveWindow(preset: .reasonableSize)
                case "m": self.resizeActiveWindow(preset: .almostMaximize)
                case "f": self.resizeActiveWindow(preset: .full)
                case "c": self.resizeActiveWindow(preset: .center)
                default: break
                }
            }
        }
    }
}

