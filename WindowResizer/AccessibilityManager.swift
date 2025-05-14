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

class AccessibilityManager: NSObject {
  static let shared = AccessibilityManager()
  
  @objc func almostMaximize() {
    resizeActiveWindow(preset: "almostMaximize")
  }
  
  @objc func reasonableSize() {
    resizeActiveWindow(preset: "reasonableSize")
  }
  
  @objc func normal() {
    resizeActiveWindow(preset: "normal")
  }
  
  @objc func center() {
    resizeActiveWindow(preset: "center")
  }
  
  @objc func full()
  {
    resizeActiveWindow(preset: "full")
  }
  
  func checkAndRequestAccessibilityPermissions() {
    // First, check if permissions are already granted
    if checkAccessibilityPermissions() {
      registerGlobalHotkeys()
      return
    }
    
    // If not granted, prompt the user
    promptForAccessibilityPermissions()
  }
  
  private func checkAccessibilityPermissions() -> Bool {
    let options: [String: Any] = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
    ]
    
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
      // Open System Preferences to Security & Privacy
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
      }
      
      // Poll for permissions after opening system preferences
      pollAccessibilityPermissions()
    }
  }
  
  private func pollAccessibilityPermissions() {
    if checkAccessibilityPermissions() {
      // Permissions granted, set up hotkeys
      registerGlobalHotkeys()
      return
    }
  }
  
  private func is16By10(screen: NSScreen) -> Bool {
    return screen.frame.width / screen.frame.height == 1.6
  }
  
  func getCurrentScreen() -> NSScreen? {
    // Get the frontmost application
    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
      return NSScreen.main
    }
    
    let pid = frontApp.processIdentifier
    
    // Create accessibility element for the app
    let axApp = AXUIElementCreateApplication(pid)
    
    // Get the focused window
    var focusedWindow: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
    
    guard result == .success,
          let window = focusedWindow as! AXUIElement? else {
      // Window access failed - might need accessibility permissions
      return NSScreen.main
    }
    
    // Get the window position
    var position: CFTypeRef?
    let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)
    
    guard posResult == .success,
          let axPosition = position as! AXValue?,
          AXValueGetType(axPosition) == .cgPoint else {
      return NSScreen.main
    }
    
    var windowPosition = CGPoint.zero
    AXValueGetValue(axPosition, .cgPoint, &windowPosition)
    
    // Convert AX (top-left) to Cocoa (bottom-left) coordinates
    let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
    let cocoaY = mainScreenHeight - windowPosition.y
    let cocoaPosition = CGPoint(x: windowPosition.x, y: cocoaY)
    
    // Find the screen containing the window's position
    for screen in NSScreen.screens {
      if screen.frame.contains(cocoaPosition) {
        return screen
      }
    }
    
    // If no screen contains the window, find the closest screen
    var closestScreen = NSScreen.main
    var shortestDistance = CGFloat.infinity
    
    for screen in NSScreen.screens {
      let screenCenter = CGPoint(
        x: screen.frame.midX,
        y: screen.frame.midY
      )
      
      let distance = hypot(
        cocoaPosition.x - screenCenter.x,
        cocoaPosition.y - screenCenter.y
      )
      
      if distance < shortestDistance {
        shortestDistance = distance
        closestScreen = screen
      }
    }
    
    return closestScreen
  }
  
  func getElementSize(element: AXUIElement) -> CGSize? {
    let kAXFrameAttribute = "AXFrame" as CFString
    
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXFrameAttribute, &value)
    
    guard result == .success,
          let axValue = value as! AXValue?,  // Use forced cast
          AXValueGetType(axValue) == .cgRect else {
      return nil
    }
    
    var rect = CGRect.zero
    if AXValueGetValue(axValue, .cgRect, &rect) {
      return rect.size
    }
    return nil
  }
  
  private func getNewWindowSize(preset: String, window: AXUIElement, centered: Bool = true) {
    guard let screen = getCurrentScreen() else { return }
    
    // Use visibleFrame to account for menu bar and dock
    let screenFrame = screen.visibleFrame
    
    var targetWidth: CGFloat = 0, targetHeight: CGFloat = 0
    
    switch preset {
    case "reasonableSize":
      targetWidth = min(screenFrame.width * 0.6, 1024)
      targetHeight = min(screenFrame.height * 0.6, 900)
      break
    case "almostMaximize":
      targetWidth = screenFrame.width * 0.9
      targetHeight = screenFrame.height * 0.9
      break
    case "normal":
      targetWidth = screenFrame.width * 0.6
      targetHeight = screenFrame.height * 0.9
      break
    case "full":
      targetWidth = screenFrame.width * 0.95
      targetHeight = screenFrame.height * 0.95
      break
    case "center":
      guard let windowElement = getElementSize(element: window) else { return }
      targetWidth = windowElement.width
      targetHeight = windowElement.height
      break
    case "smaller":
      guard let windowElement = getElementSize(element: window) else { return }
      targetWidth = windowElement.width - screenFrame.width * 0.1
      targetHeight = windowElement.height
      break
    case "larger":
      guard let windowElement = getElementSize(element: window) else { return }
      targetWidth = min(
        windowElement.width + screenFrame.width * 0.1,
        screenFrame.width * 0.95
      )
      targetHeight = windowElement.height
      break
    case "taller":
      guard let windowElement = getElementSize(element: window) else { return }
      targetWidth = windowElement.width
      targetHeight = min(
        windowElement.height + screenFrame.height * 0.1,
        screenFrame.height * 0.95
      )
      break
    case "shorter":
      guard let windowElement = getElementSize(element: window) else { return }
      targetWidth = windowElement.width
      targetHeight = windowElement.height - screenFrame.height * 0.1
      break
    default:
      break
    }
    
    if (targetWidth == 0 && targetHeight == 0) { return }
    
    var newSize = CGSize(width: targetWidth, height: targetHeight)
    
    if (!centered) { return }
    
    // Calculate X position relative to screen
    let newOriginX = screenFrame.origin.x + (screenFrame.width - targetWidth) / 2
    
    // Calculate Y position: use screen's max Y as reference and subtract position from top
    let yOffset = (screenFrame.height - targetHeight) / 2
    let newOriginY = -(screenFrame.origin.y + yOffset)
    
    var newOrigin = CGPoint(x: newOriginX, y: newOriginY)
    
    // Set the window position and size
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &newOrigin)!)
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &newSize)!)
  }
  
  private func registerGlobalHotkeys() {
    _ = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
      if event.modifierFlags.contains(.control) {
        if event.modifierFlags.contains(.option) {
          switch event.charactersIgnoringModifiers {
          case String(UnicodeScalar(NSLeftArrowFunctionKey)!):
            self.resizeActiveWindow(preset: "smaller")
            break
            
          case String(UnicodeScalar(NSRightArrowFunctionKey)!):
            self.resizeActiveWindow(preset: "larger")
            break
            
          case String(UnicodeScalar(NSUpArrowFunctionKey)!):
            self.resizeActiveWindow(preset: "taller")
            break
            
          case String(UnicodeScalar(NSDownArrowFunctionKey)!):
            self.resizeActiveWindow(preset: "shorter")
            break
            
          default:
            break
          }
        }
        
        switch event.charactersIgnoringModifiers {
        case "n":
          self.resizeActiveWindow(preset: "normal")
          break
          
        case "r":
          self.resizeActiveWindow(preset: "reasonableSize")
          break
          
        case "m":
          self.resizeActiveWindow(preset: "almostMaximize")
          break
          
        case "f":
          self.resizeActiveWindow(preset: "full")
          break
          
        case "c":
          self.resizeActiveWindow(preset: "center")
          break
          
        default:
          break
        }
        
      }
    }
  }
  
  private func resizeActiveWindow(preset: String) {
    guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
    let pid = frontApp.processIdentifier
    
    // Create an accessibility application element
    let axApp = AXUIElementCreateApplication(pid)
    
    // Declare a reference for the main window
    var mainWindow: CFTypeRef?
    
    // Try to get the focused window
    let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &mainWindow)
    
    // Ensure the window was retrieved successfully
    guard result == .success else { return }
    let window = mainWindow as! AXUIElement
    
    getNewWindowSize(preset: preset, window: window)
  }
  
  private func centerAppWindow(window: AXUIElement) {
    guard let screen = getCurrentScreen() else { return }
    
    // Get current window size
    guard let windowSize = getElementSize(element: window) else { return }
    
    // Use visibleFrame to account for menu bar and dock
    let screenFrame = screen.visibleFrame
    
    // Calculate center position for both axes
    let newOriginX = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
    let newOriginY = -(screenFrame.maxY - ((screenFrame.height - windowSize.height) / 2))
    
    var newOrigin = CGPoint(x: newOriginX, y: newOriginY)
    
    // Update window position while maintaining its current size
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &newOrigin)!)
  }
}
