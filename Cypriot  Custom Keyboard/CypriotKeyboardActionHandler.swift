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
    
    override open func handle(_ gesture: KeyboardGesture, on action: KeyboardAction, sender: Any?) {
        
        guard let gestureAction = self.action(for: gesture, on: action) else { return }
        gestureAction(cypriotInputViewController)
        //  triggerSpaceAutocomplete(for: gesture, on: action, sender: sender)
        handleSwitch(for: gesture, on: action, sender: sender)
        handleS(for: gesture, on: action, sender: sender)
        triggerAccent(for: gesture, on: action, sender: sender)
        triggerAudioFeedback(for: gesture, on: action, sender: sender)
        triggerHapticFeedback(for: gesture, on: action, sender: sender)
        autocompleteAction()
        tryEndSentence(after: gesture, on: action)
        tryRegisterEmoji(after: gesture, on: action)
        tryEndSentence(after: gesture, on: action)
        tryChangeKeyboardType(after: gesture, on: action)
        tryRegisterEmoji(after: gesture, on: action)
    }

    
     func triggerSpaceAutocomplete(for gesture: KeyboardGesture, on action: KeyboardAction, sender: Any?) {
        if action != .space { return }
        //todo: also handle punctuation
        guard let context = cypriotInputViewController?.keyboardContext else { return }
        
        guard let guess = cypriotInputViewController?.currentGuess else { return }
        guard guess != "" else { return }
        context.textDocumentProxy.deleteBackward()
        context.textDocumentProxy.replaceCurrentWord(with: guess)
        context.textDocumentProxy.insertText(" ")
    }
    
    func triggerAccent(for gesture: KeyboardGesture, on action: KeyboardAction, sender: Any?) {
        guard let context = cypriotInputViewController?.keyboardContext else { return }
        if(action == .character("΄") || action == .character("˘")) {
            context.textDocumentProxy.deleteBackward()
            let word = context.textDocumentProxy.currentWord
            guard let char = word?.last else { return }
            if ["α","ε","ι","η","υ","ο","ω"].contains(char.lowercased()) {
                if var newWord = word  {
                    newWord+="\u{301}"
                    print(newWord)
                    context.textDocumentProxy.replaceCurrentWord(with: newWord)
                   // context.textDocumentProxy.insertText(newchar)
                }
            }
            if ["σ","ζ","ξ","ψ"].contains(char.lowercased()) {
                if var newWord = word  {
                    newWord+="\u{306}"
                    print(newWord)
                    context.textDocumentProxy.replaceCurrentWord(with: newWord)
                   // context.textDocumentProxy.insertText(newchar)
                }
            }
           
        }
    }
    
    func handleSwitch(for gesture: KeyboardGesture, on action: KeyboardAction, sender: Any?) {
        guard let context = cypriotInputViewController?.keyboardContext else { return }
        if(action == .character("🔄")) {
            context.textDocumentProxy.deleteBackward()
            if context.locale == Locale.init(identifier: "en_US"){
                context.locale = Locale.init(identifier: "el_GR")
            } else {
                context.locale = Locale.init(identifier: "en_US")
            }
        }
    }

    func handleS(for gesture: KeyboardGesture, on action: KeyboardAction, sender: Any?) {
        guard let context = cypriotInputViewController?.keyboardContext else { return }
        if let newWord = context.textDocumentProxy.currentWord?.replacingOccurrences(of: "ς", with: "σ") {
            context.textDocumentProxy.replaceCurrentWord(with: newWord)
            }
        if(action == .character("σ")) {
            context.textDocumentProxy.deleteBackward()
            context.textDocumentProxy.insertText("ς")
        }
    }
}
