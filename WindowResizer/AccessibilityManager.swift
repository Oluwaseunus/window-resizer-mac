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
  
  func getCurrentScreenPrevious() -> NSScreen? {
    print("getCurrentScreen: Starting screen detection")
    
    // Get the frontmost application
    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
      print("getCurrentScreen: No frontmost application found, falling back to main screen")
      return NSScreen.main
    }
    print("getCurrentScreen: Found frontmost application: \(frontApp.localizedName ?? "unknown")")
    let pid = frontApp.processIdentifier
    
    // Create accessibility element for the app
    let axApp = AXUIElementCreateApplication(pid)
    print("getCurrentScreen: Created AX element for app with PID: \(pid)")
    
    // Get the focused window
    var focusedWindow: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
    
    guard result == .success,
          let window = focusedWindow as! AXUIElement? else {
      print("getCurrentScreen: Failed to get focused window, error: \(result)")
      print("getCurrentScreen: Is accessibility permission granted? Check System Settings -> Privacy & Security -> Accessibility")
      return NSScreen.main
    }
    print("getCurrentScreen: Successfully got focused window")
    
    // Get the window position and size
    var position: CFTypeRef?
    var size: CFTypeRef?
    let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)
    let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size)
    
    guard posResult == .success && sizeResult == .success,
          let axPosition = position as! AXValue?,
          let axSize = size as! AXValue?,
          AXValueGetType(axPosition) == .cgPoint,
          AXValueGetType(axSize) == .cgSize else {
      print("getCurrentScreen: Failed to get window position/size")
      print("getCurrentScreen: Position result: \(posResult), Size result: \(sizeResult)")
      return NSScreen.main
    }
    print("getCurrentScreen: Successfully got window position and size")
    
    var windowPosition = CGPoint.zero
    var windowSize = CGSize.zero
    AXValueGetValue(axPosition, .cgPoint, &windowPosition)
    AXValueGetValue(axSize, .cgSize, &windowSize)
    
    print("getCurrentScreen: Window position: \(windowPosition), size: \(windowSize)")
    
    // Create window rect
    let windowRect = CGRect(origin: windowPosition, size: windowSize)
    
    // Track the screen with maximum overlap
    var maxOverlapArea: CGFloat = 0
    var screenWithMaxOverlap: NSScreen?
    
    // Find the screen with the largest window overlap
    print("getCurrentScreen: Checking overlap with \(NSScreen.screens.count) screens")
    for (index, screen) in NSScreen.screens.enumerated() {
      let intersection = screen.frame.intersection(windowRect)
      let overlapArea = intersection.width * intersection.height
      print("getCurrentScreen: Screen \(index) - Frame: \(screen.frame), Intersection: \(intersection), Overlap area: \(overlapArea)")
      
      if overlapArea > maxOverlapArea {
        maxOverlapArea = overlapArea
        screenWithMaxOverlap = screen
        print("getCurrentScreen: New maximum overlap found with screen \(index)")
      }
    }
    
    if let screen = screenWithMaxOverlap {
      print("getCurrentScreen: Returning screen with maximum overlap area: \(maxOverlapArea)")
      return screen
    } else {
      print("getCurrentScreen: No overlap found with any screen, falling back to first screen or main")
      return NSScreen.screens.first ?? NSScreen.main
    }
  }
  
  func getCurrentScreen() -> NSScreen? {
    print("getCurrentScreen: Starting screen detection")
    
    // Get the frontmost application
    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
      print("getCurrentScreen: No frontmost application found, falling back to main screen")
      return NSScreen.main
    }
    print("getCurrentScreen: Found frontmost application: \(frontApp.localizedName ?? "unknown")")
    let pid = frontApp.processIdentifier
    
    // Create accessibility element for the app
    let axApp = AXUIElementCreateApplication(pid)
    print("getCurrentScreen: Created AX element for app with PID: \(pid)")
    
    // Get the focused window
    var focusedWindow: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
    
    guard result == .success,
          let window = focusedWindow as! AXUIElement? else {
      print("getCurrentScreen: Failed to get focused window, error: \(result)")
      print("getCurrentScreen: Is accessibility permission granted? Check System Settings -> Privacy & Security -> Accessibility")
      return NSScreen.main
    }
    print("getCurrentScreen: Successfully got focused window")
    
    // Get the window position
    var position: CFTypeRef?
    let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)
    
    guard posResult == .success,
          let axPosition = position as! AXValue?,
          AXValueGetType(axPosition) == .cgPoint else {
      print("getCurrentScreen: Failed to get window position")
      print("getCurrentScreen: Position result: \(posResult)")
      return NSScreen.main
    }
    print("getCurrentScreen: Successfully got window position")
    
    var windowPosition = CGPoint.zero
    AXValueGetValue(axPosition, .cgPoint, &windowPosition)
    print("getCurrentScreen: Window position: \(windowPosition)")
    
    // Get the global screen height to convert coordinates
    let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
    
    // Convert AX (top-left) to Cocoa (bottom-left) coordinates
    let cocoaY = mainScreenHeight - windowPosition.y
    let cocoaPosition = CGPoint(x: windowPosition.x, y: cocoaY)
    
    print("getCurrentScreen: Converted position: \(cocoaPosition)")
    
    // Find the screen containing the window's position
    print("getCurrentScreen: Checking \(NSScreen.screens.count) screens")
    for (index, screen) in NSScreen.screens.enumerated() {
      print("getCurrentScreen: Screen \(index) - Frame: \(screen.frame)")
      if screen.frame.contains(cocoaPosition) {
        print("getCurrentScreen: Found window on screen \(index)")
        return screen
      }
    }
    
    // If no screen contains the point, find the closest screen
    print("getCurrentScreen: Window position not found in any screen, finding closest screen")
    var closestScreen = NSScreen.main
    var shortestDistance = CGFloat.infinity
    
    for (index, screen) in NSScreen.screens.enumerated() {
      let screenCenter = CGPoint(
        x: screen.frame.midX,
        y: screen.frame.midY
      )
      
      let distance = hypot(
        cocoaPosition.x - screenCenter.x,
        cocoaPosition.y - screenCenter.y
      )
      
      print("getCurrentScreen: Distance to screen \(index): \(distance)")
      
      if distance < shortestDistance {
        shortestDistance = distance
        closestScreen = screen
      }
    }
    
    print("getCurrentScreen: Returning closest screen")
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
    print("Positioning on screen: \(screen.frame)")
    
    // Use visibleFrame to account for menu bar and dock
    let screenFrame = screen.visibleFrame
    print("Screen visible frame: \(screenFrame)")
    
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
    print("Target size: width=\(targetWidth), height=\(targetHeight)")
    
    var newSize = CGSize(width: targetWidth, height: targetHeight)
    
    if (!centered) { return }
    
    // Calculate X position relative to screen
    let newOriginX = screenFrame.origin.x + (screenFrame.width - targetWidth) / 2
    
    // For Y position: use screen's max Y as reference point and subtract position from top
    let yOffset = (screenFrame.height - targetHeight) / 2
    let newOriginY = -(screenFrame.origin.y + yOffset)
    
    print("Position calculation:")
    print("  Screen origin Y: \(screenFrame.origin.y)")
    print("  Y offset from top: \(yOffset)")
    print("  Final Y position: \(newOriginY)")
    
    var newOrigin = CGPoint(x: newOriginX, y: newOriginY)
    print("Setting window position to: \(newOrigin)")
    
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
  
  private func centerAppWindow(window: AXUIElement) {
    // Get the current screen
    guard let screen = getCurrentScreen() else { return }
    print("Centering window on screen: \(screen.frame)")
    
    // Get current window size
    guard let windowSize = getElementSize(element: window) else { return }
    print("Window size: \(windowSize)")
    
    // Use visibleFrame to account for menu bar and dock
    let screenFrame = screen.visibleFrame
    print("Screen visible frame: \(screenFrame)")
    
    // Calculate center X position
    let newOriginX = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
    
    // Calculate Y position in AX coordinates (top-left origin)
    let newOriginY = -(screenFrame.maxY - ((screenFrame.height - windowSize.height) / 2))
    
    print("Position calculation:")
    print("  Screen frame: \(screenFrame)")
    print("  Final position: (\(newOriginX), \(newOriginY))")
    
    // Create new position
    var newOrigin = CGPoint(x: newOriginX, y: newOriginY)
    
    // Update window position
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &newOrigin)!)
  }
}
