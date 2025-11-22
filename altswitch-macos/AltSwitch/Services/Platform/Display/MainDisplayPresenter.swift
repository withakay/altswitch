//
//  MainDisplayPresenter.swift
//  AltSwitch
//
//  Battle-tested pattern for always showing windows on the display with the menu bar.
//

import AppKit
import CoreGraphics
import SwiftUI

// MARK: - Screen helpers

extension NSScreen {
  var displayID: CGDirectDisplayID? {
    (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
      .map { CGDirectDisplayID($0.uint32Value) }
  }

  static var menuBarScreen: NSScreen? {
    let mainID = CGMainDisplayID()
    return NSScreen.screens.first { $0.displayID == mainID }
  }
}

// MARK: - Window positioning

extension NSWindow {
  func move(to screen: NSScreen, centered: Bool = true, animate: Bool = true) {
    precondition(Thread.isMainThread, "NSWindow updates must run on the main thread.")

    // Use screen.frame (full screen including menu bar) for calculations
    // to match AltSwitch's original behavior
    let screenFrame = screen.frame
    var new = frame

    if centered {
      // Horizontal: center in screen
      new.origin.x = screenFrame.midX - new.width / 2

      // Vertical: use AltSwitch's layout rules with configurable margins
      let topMargin = screenFrame.height * AltSwitchConstants.windowVerticalMarginRatio
      new.origin.y = screenFrame.maxY - topMargin - new.height

      // Ensure it doesn't go below bottom margin
      let bottomMargin = screenFrame.height * AltSwitchConstants.windowVerticalMarginRatio
      let minimumY = screenFrame.minY + bottomMargin
      if new.origin.y < minimumY {
        new.origin.y = minimumY
      }
    } else {
      new.origin = NSPoint(x: screenFrame.minX + 20, y: screenFrame.maxY - new.height - 20)
    }

    // Clamp size to fit within visible area
    let vf = screen.visibleFrame
    new.size.width = min(new.size.width, vf.width)
    new.size.height = min(new.size.height, vf.height)

    setFrame(new, display: true, animate: animate)
  }

  fileprivate func moveToMenuBarDisplayIfNeeded(
    enabled: Bool, centered: Bool = true, animate: Bool = true
  ) {
    guard enabled, let target = NSScreen.menuBarScreen else { return }
    move(to: target, centered: centered, animate: animate)
  }
}

// MARK: - App activation (hotkey-friendly)

@MainActor
enum AppActivation {
  static func activate() {
    NSApp.activate(ignoringOtherApps: true)
  }
}

// MARK: - SwiftUI: window resolver

private struct WindowAccessor: NSViewRepresentable {
  let onResolve: (NSWindow?) -> Void

  func makeNSView(context: Context) -> NSView {
    let resolverView = NSView()
    DispatchQueue.main.async { [weak resolverView] in
      onResolve(resolverView?.window)
    }
    return resolverView
  }
  func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - SwiftUI: view modifier

struct PresentOnMainDisplayModifier: ViewModifier {
  @Binding var isEnabled: Bool
  var centered: Bool
  var animate: Bool
  var collectionBehavior: NSWindow.CollectionBehavior?

  @State private var window: NSWindow?
  @State private var lastFrameSize: CGSize = .zero

  func body(content: Content) -> some View {
    content
      .background(
        WindowAccessor { win in
          guard let win = win else { return }
          window = win
          if let behavior = collectionBehavior {
            win.collectionBehavior.insert(behavior)
          }
          placeIfNeeded()
        }
      )
      .onChange(of: isEnabled) { _, _ in
        placeIfNeeded()
      }
      .onReceive(
        NotificationCenter.default.publisher(
          for: NSApplication.didChangeScreenParametersNotification
        )
      ) { _ in
        placeIfNeeded()
      }
    // DISABLED: Size-change repositioning removed to prevent conflicts with imperative positioning
    // The window should only be positioned explicitly via MainDisplayPresenter.present()
    // .background(
    //   GeometryReader { geometry in
    //     Color.clear
    //       .onChange(of: geometry.size) { _, newSize in
    //         // Only reposition if the size actually changed (prevents infinite loops)
    //         guard newSize != lastFrameSize else { return }
    //         lastFrameSize = newSize
    //         // Delay slightly to allow SwiftUI to finish layout
    //         DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
    //           placeIfNeeded()
    //         }
    //       }
    //   }
    // )
  }

  private func placeIfNeeded() {
    guard let win = window else { return }
    guard isEnabled else { return }
    guard let mainScreen = NSScreen.menuBarScreen else { return }
    if Thread.isMainThread {
      win.move(to: mainScreen, centered: centered, animate: animate)
    } else {
      DispatchQueue.main.async {
        win.move(to: mainScreen, centered: centered, animate: animate)
      }
    }
  }
}

extension View {
  func presentOnMainDisplay(
    when isEnabled: Binding<Bool>,
    centered: Bool = true,
    animate: Bool = true,
    collectionBehavior: NSWindow.CollectionBehavior? = .moveToActiveSpace
  ) -> some View {
    modifier(
      PresentOnMainDisplayModifier(
        isEnabled: isEnabled,
        centered: centered,
        animate: animate,
        collectionBehavior: collectionBehavior
      ))
  }
}

// MARK: - Imperative API (useful in hotkey handlers)

@MainActor
enum MainDisplayPresenter {
  static func present(
    window: NSWindow,
    useMainDisplay: Bool,
    centered: Bool = true,
    animate: Bool = true
  ) {
    if useMainDisplay {
      window.moveToMenuBarDisplayIfNeeded(enabled: true, centered: centered, animate: animate)
    }
    AppActivation.activate()
    window.makeKeyAndOrderFront(nil)
  }

  static func present<Content: View>(
    content: Content,
    useMainDisplay: Bool,
    configure: (NSWindow) -> Void = { _ in }
  ) -> NSWindow {
    let host = NSHostingController(rootView: content)
    let win = NSWindow(contentViewController: host)
    configure(win)
    if useMainDisplay {
      win.moveToMenuBarDisplayIfNeeded(enabled: true)
    }
    AppActivation.activate()
    win.makeKeyAndOrderFront(nil)
    return win
  }
}
