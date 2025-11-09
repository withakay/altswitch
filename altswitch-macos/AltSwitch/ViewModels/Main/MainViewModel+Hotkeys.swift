import AppKit
import Foundation

@MainActor
extension MainViewModel {
  // MARK: - Selection Shortcuts
  func setupSelectionShortcuts() {
    selectionShortcutMonitors.append(
      NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self else { return event }
        return self.handleSelectionShortcut(event) ? nil : event
      } as Any
    )

    if let globalMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: .keyDown,
      handler: { [weak self] event in
        self?.handleSelectionShortcut(event)
      })
    {
      selectionShortcutMonitors.append(globalMonitor)
    }
  }

  func removeSelectionShortcuts() {
    selectionShortcutMonitors.forEach { monitor in
      NSEvent.removeMonitor(monitor)
    }
    selectionShortcutMonitors.removeAll()
  }

  @discardableResult
  func handleSelectionShortcut(_ event: NSEvent) -> Bool {
    guard isVisible,
      event.modifierFlags.contains(.command),
      let character = event.charactersIgnoringModifiers?.first,
      let number = Int(String(character)),
      (1...9).contains(number)
    else {
      return false
    }

    Task { [weak self] in
      await self?.switchToApp(at: number - 1)
    }
    return true
  }

  // MARK: - Keyboard Handling
  func handleKeyEvent(_ event: NSEvent) -> Bool {
    if event.modifierFlags.contains(.command) {
      if let char = event.charactersIgnoringModifiers?.first,
        let number = Int(String(char)),
        number >= 1 && number <= 9
      {
        Task {
          await self.switchToApp(at: number - 1)
        }
        return true
      }
    }

    switch event.keyCode {
    case 126:  // Up arrow
      selectPrevious()
      return true
    case 125:  // Down arrow
      selectNext()
      return true
    case 36:  // Return key
      Task {
        await switchToSelectedApp()
      }
      return true
    case 53:  // Escape key
      hide()
      return true
    case 15:  // R key
      if event.modifierFlags.contains([.command, .shift]) {
        Task {
          await refreshApps()
        }
        return true
      }
      return false
    default:
      return false
    }
  }

  // MARK: - Hotkey API
  func setHotkeysEnabled(_ enabled: Bool) async {
    await hotkeyManager.setHotkeysEnabled(enabled)
  }

  func getHotkeyStatus() -> [HotkeyType: Bool] {
    var status: [HotkeyType: Bool] = [:]

    if let showHide = configuration.showHideHotkey {
      status[.showHide] = hotkeyManager.isHotkeyRegistered(showHide)
    }
    if let settings = configuration.settingsHotkey {
      status[.settings] = hotkeyManager.isHotkeyRegistered(settings)
    }
    if let refresh = configuration.refreshHotkey {
      status[.refresh] = hotkeyManager.isHotkeyRegistered(refresh)
    }

    return status
  }

  func handleHotkeyError(_ error: Error) {
    lastError = error

    switch error {
    case HotkeyRegistrationError.systemConflict(let combo):
      print("Hotkey conflict detected: \(combo.displayString) conflicts with system shortcut")
    case HotkeyRegistrationError.alreadyRegistered(let combo):
      print("Hotkey already registered: \(combo.displayString)")
    case HotkeyRegistrationError.invalidCombination(let combo):
      print("Invalid hotkey combination: \(combo.displayString)")
    case HotkeyError.systemPermissionDenied:
      print("Permission denied for hotkey registration")
    case HotkeyRegistrationError.registrationFailed(let message):
      print("Hotkey registration failed: \(message)")
    default:
      print("Hotkey error: \(error)")
    }
  }
}
