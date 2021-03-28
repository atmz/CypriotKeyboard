//
//  CypriotKeyboardLayoutProvider.swift
//  Cypriot Keyboard
//
//  Created by Alex Toumazis on 3/25/21.
//

import Foundation
import KeyboardKit

class CypriotKeyboardLayoutProvider : StandardKeyboardLayoutProvider {

    lazy var cyPhoneProvider = CypriotKeyboardiPhoneLayoutProvider(
       inputSetProvider: inputSetProvider,
       dictationReplacement: dictationReplacement)
    lazy var cyPadProvider = CypriotKeyboardiPadLayoutProvider(
       inputSetProvider: inputSetProvider,
       dictationReplacement: dictationReplacement)
    
     override func keyboardLayout(for context: KeyboardContext) -> KeyboardLayout {
        context.device.userInterfaceIdiom == .pad  ?  cyPadProvider.keyboardLayout(for: context) :  cyPhoneProvider.keyboardLayout(for: context)

        }
}

