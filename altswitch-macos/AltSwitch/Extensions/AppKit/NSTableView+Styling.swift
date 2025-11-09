//
//  NSTableView+Styling.swift
//  AltSwitch
//
//  Created for PreferencesView styling
//

import AppKit

extension NSTableView {
  open override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    backgroundColor = NSColor.clear
    enclosingScrollView?.drawsBackground = false
  }
}
