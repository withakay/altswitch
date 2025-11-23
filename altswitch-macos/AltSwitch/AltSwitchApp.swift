//
//  AltSwitchApp.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import AppKit
import MacWindowDiscovery
import SwiftUI

@main
struct AltSwitchApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

  // HotkeyCenter will be configured after app initialization

  init() {
    NSLog("AltSwitch: AltSwitchApp.init() called")
    print("🚀 AltSwitchApp.init() called")
  }

  var body: some Scene {
    // Settings window scene - always available for menu bar access
    #if os(macOS)
      let mainViewModel = appDelegate.provideMainViewModel()

      Settings {
        if let settingsViewModel = appDelegate.provideSettingsViewModel() {
          PreferencesView()
            .environment(settingsViewModel)
            .environment(mainViewModel)
        } else {
          Text("Unable to load settings")
            .foregroundColor(.secondary)
        }
      }
    #endif

    // Menu bar extra for status item - only show when enabled
    MenuBarExtra("AltSwitch", systemImage: "command.square", isInserted: $showMenuBarIcon) {
      MenuBarView()
        .environment(mainViewModel)
    }
  }
}

// MARK: - App Delegate
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var mainWindow: NSWindow?
  private(set) internal var mainViewModel: MainViewModel?
  private var settingsManager: SettingsManagerProtocol?
  private var settingsViewModel: SettingsViewModel?

  // Store a weak reference to self instead of relying on NSApp.delegate
  private static weak var _shared: AppDelegate?

  static var shared: AppDelegate? {
    return _shared
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Store reference to self
    AppDelegate._shared = self

    NSLog("AltSwitch: Application launched")

    guard enforceSingleInstance() else { return }

    // Hide from dock
    NSApp.setActivationPolicy(.accessory)

    // Initialize Spaces tracking (ported from AltTab)
    // This sets up space change notifications and initial space mapping
    Spaces.initialize()
    NSLog("AltSwitch: Spaces tracking initialized")

    // Use centralized permission manager - request once at app launch
    let permissionManager = AccessibilityPermissionManager.shared
    let trusted = permissionManager.requestPermissionIfNeeded()
    NSLog("AltSwitch: Initial accessibility check = \(trusted)")

    // Note: We no longer show an alert here
    // AccessibilityPermissionView will handle UI if permissions are not granted

    // Window will be created lazily when first needed (via hotkey or menu bar)
  }

  func applicationWillTerminate(_ notification: Notification) {
    // Cleanup
    mainViewModel = nil
  }

  /// Ensure only one instance of AltSwitch runs at a time.
  private func enforceSingleInstance() -> Bool {
    guard let bundleID = Bundle.main.bundleIdentifier else {
      NSLog("AltSwitch: Missing bundle identifier; cannot enforce single instance")
      return true
    }

    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    guard running.count > 1 else { return true }

    let currentPID = ProcessInfo.processInfo.processIdentifier
    if let existing = running.first(where: { $0.processIdentifier != currentPID }) {
      NSLog("AltSwitch: Existing instance detected (pid \(existing.processIdentifier)); activating and exiting duplicate")
      existing.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
    } else {
      NSLog("AltSwitch: Multiple instances detected; terminating duplicate")
    }

    NSApp.terminate(nil)
    return false
  }

  func provideMainViewModel() -> MainViewModel {
    if let mainViewModel {
      return mainViewModel
    }

    // Initialize services
    let settingsManager = getOrCreateSettingsManager()
    let hotkeyManager: HotkeyManagerProtocol = KeyboardShortcutsHotkeyManager()

    let viewModel = MainViewModel(
      appDiscovery: PackageAppDiscovery(),  // Using MacWindowDiscovery package
      appSwitcher: AppSwitcher.shared,
      fuzzySearch: FuzzySearchService(),
      hotkeyManager: hotkeyManager,
      settingsManager: settingsManager
    )
    mainViewModel = viewModel
    
    // Configure HotkeyCenter with current configuration
    HotkeyCenter.configure(with: viewModel.configuration)
    
    return viewModel
  }

  func provideSettingsViewModel() -> SettingsViewModel? {
    if let settingsViewModel {
      return settingsViewModel
    }

    let settingsManager = getOrCreateSettingsManager()
    let mainVM = provideMainViewModel()

    let viewModel = SettingsViewModel.create(
      with: settingsManager,
      hotkeyManager: mainVM.hotkeyManager
    )
    settingsViewModel = viewModel
    return viewModel
  }

  private func getOrCreateSettingsManager() -> SettingsManagerProtocol {
    if let settingsManager {
      return settingsManager
    }

    let manager: SettingsManagerProtocol
    do {
      manager = try SettingsManager()
    } catch {
      // Fallback to in-memory settings if file initialization fails
      print("Warning: Failed to initialize settings manager: \(error). Using defaults.")
      let fallbackURL = URL(fileURLWithPath: "/tmp/altswitch_settings.yaml")
      do {
        manager = try SettingsManager(configurationFileURL: fallbackURL)
      } catch {
        fatalError("Unable to initialize SettingsManager even with fallback: \(error)")
      }
    }

    settingsManager = manager
    return manager
  }

  private var settingsWindow: NSWindow?

  func openSettings() {
    NSApp.activate(ignoringOtherApps: true)

    if let window = settingsWindow, window.isVisible == false {
      window.makeKeyAndOrderFront(nil)
      return
    }

    let result = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

    if result {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        for window in NSApp.windows {
          if window.title.lowercased().contains("settings") || window.className.contains("Settings")
          {
            self.settingsWindow = window
            break
          }
        }
      }
      return
    }

    createSettingsWindow()
  }

  private func createSettingsWindow() {
    guard let settingsViewModel = provideSettingsViewModel(),
      let mainViewModel = mainViewModel
    else {
      return
    }

    let settingsView = PreferencesView()
      .environment(settingsViewModel)
      .environment(mainViewModel)

    let hostingController = NSHostingController(rootView: settingsView)

    let window = NSWindow(contentViewController: hostingController)
    window.title = "Settings"
    window.styleMask = [.titled, .closable]

    // Fixed size - no resizing
    window.setContentSize(NSSize(width: 600, height: 400))

    window.center()
    window.makeKeyAndOrderFront(nil)

    settingsWindow = window
  }

  func setupMainWindow(forceRecreate: Bool = false) {
    let viewModel = provideMainViewModel()

    if forceRecreate {
      mainWindow?.orderOut(nil)
      mainWindow = nil
    }

    let window = FocusablePanel(
      contentRect: NSRect(
        x: 0,
        y: 0,
        width: AltSwitchConstants.windowWidth,
        height: AltSwitchConstants.windowHeight,

      ),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    window.level = .floating
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.hidesOnDeactivate = false
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.isMovableByWindowBackground = true
    window.identifier = NSUserInterfaceItemIdentifier("main")
    window.acceptsMouseMovedEvents = true
    window.ignoresMouseEvents = false

    window.titleVisibility = .hidden
    window.styleMask.remove(.titled)
    window.backgroundColor = .clear

    let hostingView = NSHostingView(
      rootView: MainWindow()
        .environment(viewModel)
    )
    hostingView.translatesAutoresizingMaskIntoConstraints = false

    let visualEffect = NSVisualEffectView()
    visualEffect.translatesAutoresizingMaskIntoConstraints = false
    visualEffect.material = .hudWindow
    visualEffect.state = .active
    visualEffect.wantsLayer = true
    visualEffect.layer?.cornerRadius = 16.0

    let containerView = NSView(
      frame: NSRect(
        x: 0,
        y: 0,
        width: AltSwitchConstants.windowWidth,
        height: AltSwitchConstants.windowHeight
      )
    )

    containerView.addSubview(visualEffect)
    window.contentView = containerView

    NSLayoutConstraint.activate([
      visualEffect.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      visualEffect.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      visualEffect.topAnchor.constraint(equalTo: containerView.topAnchor),
      visualEffect.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])

    visualEffect.addSubview(hostingView)

    NSLayoutConstraint.activate([
      hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
      hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
    ])

    mainWindow = window
    viewModel.setWindow(window)

  }

}
