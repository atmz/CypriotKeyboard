//
//  CypriotKeyboardActionHandler.swift
//  Cypriot Keyboard
//
//  Created by Alex Toumazis on 2/8/21.
//

import UIKit
import Foundation
import KeyboardKit


class CypriotKeyboardActionHandler: StandardKeyboardActionHandler {
    
    public private(set) weak var cypriotInputViewController: KeyboardViewController?


     public init(
        inputViewController: KeyboardViewController) {
        self.cypriotInputViewController = inputViewController
        super.init(
            inputViewController: inputViewController
        )
    }
    
    override open func handle(_ gesture: KeyboardGesture, on action: KeyboardAction) {
        
        guard let gestureAction = self.action(for: gesture, on: action) else { return }
        gestureAction(cypriotInputViewController)
        triggerSpaceAutocomplete(for: gesture, on: action)
        handleSwitch(for: gesture, on: action)
        handleS(for: gesture, on: action)
        triggerAccent(for: gesture, on: action)
        triggerAudioFeedback(for: gesture, on: action)
        triggerHapticFeedback(for: gesture, on: action)
        autocompleteAction()
        tryRegisterEmoji(after: gesture, on: action)
        tryEndSentence(after: gesture, on: action)
        tryChangeKeyboardType(after: gesture, on: action)
        tryRegisterEmoji(after: gesture, on: action)
        cypriotInputViewController?.setLastAction(a: action);
    }

    
     func triggerSpaceAutocomplete(for gesture: KeyboardGesture, on action: KeyboardAction) {
        guard let context = cypriotInputViewController?.keyboardContext else { return }
        let text = context.textDocumentProxy.documentContextBeforeInput
        guard let char = text?.last else { return }
        if  (!(action == .character(".")) &&
            !(action == .character(",")) &&
                !(action == .character(";")) &&
                !(action == .character(":")) &&
                !(action == .character("·")) &&
                !(action == .character("!")) &&
                !(action == .character("?")) &&
                !(action == .character("]")) &&
                !(action == .character(")")) &&
                !(action == .character("\"")) &&
                !(action == .space) &&
                !(action == .return)
        )
                { return }
        //todo: also handle punctuation

        
        guard let guess = cypriotInputViewController?.currentGuess else { return }
        guard  guess.additionalInfo.keys.contains("willReplace") else { return }
        
        // if we just did a backspace, we shouldn't autoreplace
        // for the case where we select an autocompletem
         guard cypriotInputViewController?.lastAction != .backspace else {return}

        context.textDocumentProxy.deleteBackward()
        context.textDocumentProxy.replaceCurrentWord(with: guess.text)
        context.textDocumentProxy.insertText(String(char))
    }
    
    func triggerAccent(for gesture: KeyboardGesture, on action: KeyboardAction) {
        guard let context = cypriotInputViewController?.keyboardContext else { return }
        if(
            action == .character("΄") ||
            action == .character("˘") ||
            action == .character(" ̈") ||
            action == .character("΅")
        ) {
            context.textDocumentProxy.deleteBackward()
            let word = context.textDocumentProxy.currentWordPreCursorPart
            guard let char = word?.last else { return }
           // let charString = String(char)
            switch action {
                case .character("˘"):
                if ["σ","ζ","ξ","ψ","ς"].contains(char.lowercased()) {
                    context.textDocumentProxy.insertText("\u{306}")
                }
                case .character(" ̈"):
                    if ["ι","ί","υ","ύ"].contains(char.lowercased()) {
                        context.textDocumentProxy.insertText("\u{308}")
                    }
                case .character("΅"):
                    if ["ι","υ"].contains(char.lowercased()) {
                        context.textDocumentProxy.insertText("\u{308}\u{301}")
                    }
                    else if ["ϊ","ϋ"].contains(char.lowercased()) {
                        context.textDocumentProxy.insertText("\u{301}")
                    }
                    else if ["ί","ύ"].contains(char.lowercased()) {
                        context.textDocumentProxy.insertText("\u{308}")
                    }
                default:
                    if ["α","ε","ι","η","υ","ο","ω","ϋ","ϊ","ὀ"].contains(char.lowercased()) {
                        context.textDocumentProxy.insertText("\u{301}")
                    }
                }
            
        }
    }
    
    func handleSwitch(for gesture: KeyboardGesture, on action: KeyboardAction) {
        guard let context = cypriotInputViewController?.keyboardContext else { return }
        if(action == .character("🔄")) {
            context.textDocumentProxy.deleteBackward()
            if context.locale == Locale.init(identifier: "en_US"){
                context.locale = Locale.init(identifier: "el_GR")
                UserDefaults.standard.setValue(false, forKey: "isLatinKeyboard")
            } else {
                context.locale = Locale.init(identifier: "en_US")
                UserDefaults.standard.setValue(true, forKey: "isLatinKeyboard")
            }
        }
    }

    func handleS(for gesture: KeyboardGesture, on action: KeyboardAction) {
        if(!action.isInputAction || action == .character("🔄")) {
            return
        }
        //todo :: something here breaks inserting letters
        guard let context = cypriotInputViewController?.keyboardContext else { return }
        guard let word = context.textDocumentProxy.currentWordPreCursorPart  else { return }
        guard let char = word.last else { return }
        let wordWithoutChar = word.prefix(word.count-1)
        if char.isLetter {
            // as we type, if letter before last is final s, make it normal s
            // this does have an adge case with cursor movement where it wont work, but close enough
            if wordWithoutChar.last == "ς" {
                context.textDocumentProxy.deleteBackward()
                context.textDocumentProxy.deleteBackward()
                context.textDocumentProxy.insertText("σ")
                context.textDocumentProxy.insertText(String(char))
            }
            if wordWithoutChar.last == "ς̆" {
                context.textDocumentProxy.deleteBackward()
                context.textDocumentProxy.deleteBackward()
                context.textDocumentProxy.insertText("σ̆")
                context.textDocumentProxy.insertText(String(char))
            }
            if context.textDocumentProxy.currentWordPostCursorPart==nil {
                //if we're at the end of a word, turn s into final s
                if char == "σ" {
                    context.textDocumentProxy.deleteBackward()
                    context.textDocumentProxy.insertText("ς")
                }
                if char == "σ̆" {
                    context.textDocumentProxy.deleteBackward()
                    context.textDocumentProxy.insertText("ς̆")
                }
            }
        }
    }
}
