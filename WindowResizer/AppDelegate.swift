//
//  AppDelegate.swift
//  WindowResizer
//
//  Created by Oluwaseun Adetunji on 07/12/2024.
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  var statusItem: NSStatusItem!
  var excludeAppMenuItem: NSMenuItem!

  func applicationDidFinishLaunching(_ notification: Notification) {
    AccessibilityManager.shared.checkAndRequestAccessibilityPermissions()
    setupMenuBar()
  }
  
  private func setupMenuBar() {
    statusItem = NSStatusBar.system
      .statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "rectangle.expand.vertical",
        accessibilityDescription: "Resize")
    }
    
    let menu = NSMenu()
    
    let menuItem = NSMenuItem(
      title: "Almost Maximize",
      action: #selector(
        AccessibilityManager.shared.almostMaximize
      ),
      keyEquivalent: "m"
    )
    
    menuItem.target = AccessibilityManager.shared
    menu.addItem(menuItem)
    
    let reasonableSize = NSMenuItem(title: "Reasonable Size", action: #selector(AccessibilityManager.shared.reasonableSize), keyEquivalent: "r")
    reasonableSize.target = AccessibilityManager.shared
    menu.addItem(reasonableSize)
    
    let normal = NSMenuItem(title: "Normal", action: #selector(AccessibilityManager.shared.normal), keyEquivalent: "n")
    normal.target = AccessibilityManager.shared
    menu.addItem(normal)
    
    let center = NSMenuItem(
      title: "Center",
      action: #selector (AccessibilityManager.shared.center),
      keyEquivalent: "c")
    center.target = AccessibilityManager.shared
    menu.addItem(center)
    
    let full = NSMenuItem(
      title: "Full",
      action: #selector(AccessibilityManager.shared.full),
      keyEquivalent: "f"
    )
    full.target = AccessibilityManager.shared
    menu.addItem(full)

    menu.addItem(NSMenuItem.separator())

    // Add exclusion toggle menu item
    excludeAppMenuItem = NSMenuItem(title: "", action: #selector(toggleExcludeApp), keyEquivalent: "")
    excludeAppMenuItem.target = self
    menu.addItem(excludeAppMenuItem)

    menu.addItem(NSMenuItem.separator())

    menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

    menu.delegate = self
    statusItem.menu = menu
  }
  
  @objc private func quit() {
    NSApp.terminate(nil)
  }

  @objc private func toggleExcludeApp() {
    guard let bundleID = AccessibilityManager.shared.getFrontmostAppBundleID() else { return }
    AccessibilityManager.shared.toggleAppExclusion(bundleID: bundleID)
  }

  // MARK: - NSMenuDelegate
  func menuNeedsUpdate(_ menu: NSMenu) {
    updateExcludeAppMenuItem()
  }

  private func updateExcludeAppMenuItem() {
    guard let bundleID = AccessibilityManager.shared.getFrontmostAppBundleID(),
          let appName = AccessibilityManager.shared.getFrontmostAppName() else {
      excludeAppMenuItem.isHidden = true
      return
    }

    // Don't show exclusion option for WindowResizer itself
    if bundleID == Bundle.main.bundleIdentifier {
      excludeAppMenuItem.isHidden = true
      return
    }

    excludeAppMenuItem.isHidden = false

    let isExcluded = AccessibilityManager.shared.isAppExcluded(bundleID)
    if isExcluded {
      excludeAppMenuItem.title = "Include \(appName) in shortcuts"
    } else {
      excludeAppMenuItem.title = "Exclude \(appName) from shortcuts"
    }
  }
}
