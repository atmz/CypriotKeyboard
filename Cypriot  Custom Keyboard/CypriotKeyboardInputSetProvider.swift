//
//  StandardKeyboardInputSetProvider.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2020-12-01.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//
import Foundation
import KeyboardKit

/**
 This provider is used by default, and provides the standard
 input set for the current locale, if any.
 
 You can inherit and customize this class to create your own
 provider that builds on this foundation.
 
 The dictionaries contain the currently supported input sets.
 They are not part of the protocol, but you can use them and
 extend them in your own subclasses.
 */
open class CypriotKeyboardInputSetProvider: StandardKeyboardInputSetProvider {
    
    public var isLatinInput : Bool { false }
    
    override open func alphabeticInputSet(for context: KeyboardContext) -> AlphabeticKeyboardInputSet {
        return context.primaryLanguage == "en_US" ? .alphabetic_en : .alphabetic_gr
    }
    
}
