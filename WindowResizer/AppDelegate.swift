//
//  AppDelegate.swift
//  WindowResizer
//
//  Created by Oluwaseun Adetunji on 07/12/2024.
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: NSStatusItem!
  
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
    
    menu.addItem(NSMenuItem.separator())
    
    menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
    
    statusItem.menu = menu
  }
  
  @objc private func quit() {
    NSApp.terminate(nil)
  }
}
