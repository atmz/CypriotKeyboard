//
//  CypriotKeyboardiPhoneLayoutProvider.swift
//  Cypriot  Custom Keyboard
//
//  Created by Alex Toumazis on 2/23/21.
//

import KeyboardKit

class CypriotKeyboardiPhoneLayoutProvider : iPhoneKeyboardLayoutProvider {
    override func bottomActions(for context: KeyboardContext) -> KeyboardActionRow {
        var result = KeyboardActions()
        let portrait = context.deviceOrientation.isPortrait
        let needsInputSwitcher = context.needsInputModeSwitchKey
        if let action = keyboardSwitchActionForBottomRow(for: context) { result.append(action) }
        if needsInputSwitcher { result.append(.nextKeyboard) }
        result.append(.space)
        result.append(.character("🔄"))
        result.append(.return) // TODO: Should be "primary"
        return result
    }
    
}
