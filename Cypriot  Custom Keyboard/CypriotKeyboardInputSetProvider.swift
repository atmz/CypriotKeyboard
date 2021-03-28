//
//  StandardKeyboardInputSetProvider.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2020-12-01.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//
import KeyboardKit
import UIKit

/**
 This provider is used by default, and provides the standard
 input set for the current locale, if any.
 
 You can inherit and customize this class to create your own
 provider that builds on this foundation.
 
 The dictionaries contain the currently supported input sets.
 They are not part of the protocol, but you can use them and
 extend them in your own subclasses.
 */
open class CypriotKeyboardInputSetProvider: KeyboardInputSetProvider, DeviceSpecificInputSetProvider, LocalizedService {
    
    public var device: UIDevice
    
    public var context: KeyboardContext
    
    public var localeKey: String = "el_GR"
    
    public func numericInputSet() -> NumericKeyboardInputSet {
        let phoneCenter: [String] = "-/:·()€&@“".chars
        let padCenter: [String] = "@#€&*()’”+·".chars
        return NumericKeyboardInputSet(rows: [
            row(phone: "1234567890", pad: "1234567890`"),
            row(device.userInterfaceIdiom == .phone ? phoneCenter : padCenter),
            row(phone: ".,;!’", pad: "%_-=/;:,.")
        ])
    }
    
    public func symbolicInputSet() -> SymbolicKeyboardInputSet {
        SymbolicKeyboardInputSet(rows: [
            row(phone: "[]{}#%^*+=", pad: "1234567890´"),
            row(phone: "_\\?~<>$£¥·", pad: "€$£^[]{}—˚…"),
            row(phone: ".,;!’", pad: "§|~≠\\<>!?")
        ])
    }
    
    
    public var isLatinInput : Bool { false }
    
    public init(context: KeyboardContext, device: UIDevice = .current) {
        self.device = device
        self.context = context
    }
    
    public func alphabeticInputSet() -> AlphabeticKeyboardInputSet {
        let lastLetter = context.textDocumentProxy.currentWordPreCursorPart?.last
        return AlphabeticKeyboardInputSet(rows: [
            ["σ","ζ","ξ","ψ","ς"].contains(lastLetter?.lowercased()) ?  row("ερτυθιοπ˘") : row("ερτυθιοπ΄"),
            row("ασδφγηξκλ"),
            row("ζχψωβνμ")
        ])
    }
    
}
