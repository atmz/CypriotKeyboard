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
        //let portrait = context.deviceOrientation.isPortrait
        let needsInputSwitcher = context.needsInputModeSwitchKey
        if let action = keyboardSwitchActionForBottomRow(for: context) { result.append(action) }
        if needsInputSwitcher { result.append(.nextKeyboard) }
        result.append(.character("🔄"))
        result.append(.space)
        result.append(.return) // TODO: Should be "primary"
        return result
    }
    var charButtonWidth: KeyboardLayoutItemWidth { .percentage(0.1) }
    
    override func itemSizeWidth(for context: KeyboardContext, action: KeyboardAction, row: Int, index: Int) -> KeyboardLayoutItemWidth {
        switch context.keyboardType {
            case .alphabetic:
                switch action {
                    case .character: return charButtonWidth
                    default: return super.itemSizeWidth(for: context, action: action, row: row, index: index)
                }
        default:
            return super.itemSizeWidth(for: context, action: action, row: row, index: index)
        }
    }
}
