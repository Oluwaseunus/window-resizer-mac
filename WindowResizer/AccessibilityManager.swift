//
//  AccessibilityManager.swift
//  WindowResizerGPT
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
    
    NSLog(AXIsProcessTrustedWithOptions(options as CFDictionary) ? "yes" : "no")
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
      print("Accessibility permissions granted.")
      registerGlobalHotkeys()
      return
      
    }
  }
  
  private func is16By10(screen: NSScreen) -> Bool {
    return screen.frame.width / screen.frame.height == 1.6
  }
  
  func getCurrentScreen() -> NSScreen? {
    // try to get screen by active window
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
          let windowsInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
      return nil
    }
    
    let pid = frontmostApp.processIdentifier
    
    for window in windowsInfo {
      guard let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
            windowPID == pid,
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
            let x = bounds["X"], let y = bounds["Y"],
            let width = bounds["Width"], let height = bounds["Height"] else {
        continue
      }
      
      let windowRect = CGRect(x: x, y: y, width: width, height: height)
      
      // Now, check if the window intersects with any of the screens
      for screen in NSScreen.screens {
        print(
          "screen: \(screen.localizedName), frame: \(screen.frame), windowRect: \(windowRect), intersects: \(NSIntersectsRect(screen.frame, windowRect))"
        )
        if NSIntersectsRect(screen.frame, windowRect) {
          return screen
        }
      }
    }
    
    // Fallback to the first screen if no match is found
    return NSScreen.screens.first
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
    
    let screenFrame = screen.visibleFrame
    
    var targetWidth: CGFloat = 0, targetHeight: CGFloat = 0
    
    switch preset {
    case "reasonableSize":
      targetWidth = max(screenFrame.width * 0.6, 1024)
      targetHeight = max(screenFrame.height * 0.6, 900)
      break
    case "almostMaximize":
      targetWidth = screenFrame.width * 0.9
      targetHeight = screenFrame.height * 0.9
      break
    case "normal":
      targetWidth = screenFrame.width * 0.6
      targetHeight = screenFrame.height * 0.9
      break
      
    case "center":
      guard let windowElement = getElementSize(element: window) else {return }
      targetWidth = windowElement.width
      targetHeight = windowElement.height
      break
    case "smaller":
      guard let windowElement = getElementSize(element: window) else { return }
      targetWidth = windowElement.width - screenFrame.width * 0.1
      targetHeight = windowElement.height
      break;
      
    case "larger":
      guard let windowElement = getElementSize(element: window) else { return }
      targetWidth = min(
        windowElement.width + screenFrame.width * 0.1,
        screenFrame.width * 0.95
      )
      print("targetWidth: \(targetWidth), desired: \(windowElement.width + screenFrame.width * 0.1), max: \(screenFrame.width * 0.95)")
      targetHeight = windowElement.height
      break
      
    default:
      break
    }
    
    if (targetWidth == 0 && targetHeight == 0) { return }
    
    var newSize = CGSize(width: targetWidth, height: targetHeight)
    
    if (!centered) { return }
    
    // Calculate centered position
    let newOriginX = screenFrame.midX - (targetWidth / 2)
    let newOriginY = is16By10(screen: screen) ? (1.039 * screenFrame.maxY) - ((screenFrame.height + targetHeight) / 2) : screenFrame.maxY + 25 - ((screenFrame.height + targetHeight) / 2)
    
    // Create new position and size structs
    var newOrigin = CGPoint(x: newOriginX, y: newOriginY)
    
    // Update window position and size
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
    print(preset)
    
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
}
