//
//  FocusablePanel.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import AppKit

/// Custom NSPanel that can become key window and receive keyboard focus
class FocusablePanel: NSPanel {

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }

  override func resignKey() {
    super.resignKey()
    orderOut(nil)
  }

  override func cancelOperation(_ sender: Any?) {
    orderOut(nil)
  }

  override var acceptsFirstResponder: Bool {
    true
  }
}
