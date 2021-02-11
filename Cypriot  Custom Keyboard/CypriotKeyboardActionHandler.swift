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
        guard let gestureAction = self.action(for: gesture, on: action, sender: sender) else { return }
        gestureAction()
        triggerAnimation(for: gesture, on: action, sender: sender)
        triggerAudioFeedback(for: gesture, on: action, sender: sender)
        triggerHapticFeedback(for: gesture, on: action, sender: sender)
        triggerAccent(for: gesture, on: action, sender: sender)
        handleS(for: gesture, on: action, sender: sender)
        triggerSpaceAutocomplete(for: gesture, on: action, sender: sender)
        triggerAutocomplete()
        tryEndSentence(after: gesture, on: action)
        tryChangeKeyboardType(after: gesture, on: action)
        tryRegisterEmoji(after: gesture, on: action)
    }

    
     func triggerSpaceAutocomplete(for gesture: KeyboardGesture, on action: KeyboardAction, sender: Any?) {
        if action != .space { return }
        //todo: also handle punctuation
        guard let context = cypriotInputViewController?.context else { return }
        
        guard let guess = cypriotInputViewController?.currentGuess else { return }
        guard guess != "" else { return }
        context.textDocumentProxy.deleteBackward()
        context.textDocumentProxy.replaceCurrentWord(with: guess)
        context.textDocumentProxy.insertText(" ")
    }
    
    func triggerAccent(for gesture: KeyboardGesture, on action: KeyboardAction, sender: Any?) {
        guard let context = cypriotInputViewController?.context else { return }
            if(action == .character("΄")) {
                context.textDocumentProxy.deleteBackward()
                let word = context.textDocumentProxy.trimmedDocumentContextBeforeInput
                guard let char = word?.last else { return }
                let substitutions = [
                    "α": "ά",
                    "ε": "έ",
                    "ι": "ί",
                    "η": "ή",
                    "υ": "ύ",
                    "ο": "ό",
                    "ω": "ώ",
                    "Α": "Ά",
                    "Ε": "Έ",
                    "Ι": "Ί",
                    "Η": "Ή",
                    "Υ": "Ύ",
                    "Ο": "Ό",
                    "Ω": "Ώ",
                ]
                if let newchar = substitutions[String(char)] {
                    context.textDocumentProxy.deleteBackward()
                    context.textDocumentProxy.insertText(newchar)
                } else {
                    //Not sure if this is best behavior, but this matches standard keyboard
                    context.textDocumentProxy.insertText("΄")

                }
            }
    }
    
    func handleS(for gesture: KeyboardGesture, on action: KeyboardAction, sender: Any?) {
        guard let context = cypriotInputViewController?.context else { return }
            //todo: move elswhere
        if(action == .character("🇬🇧")) {
            context.textDocumentProxy.deleteBackward()
            context.primaryLanguage = "en_US"
        }
        if(action == .character("🇬🇷")) {
            context.textDocumentProxy.deleteBackward()
            context.primaryLanguage = "el_GR"
        }
            if(action == .character("σ")) {
                context.textDocumentProxy.deleteBackward()
                context.textDocumentProxy.insertText("ς")
            }
            else {
                //todo: change s after more letters are typed
            }
    }
 
    /*func triggerAccent(for gesture: KeyboardGesture, on action: KeyboardAction, sender: Any?) {
        guard let context = cypriotInputViewController?.context else { return }
        if !isAccentWaiting {
            if(action == .character("΄")) {
                self.isAccentWaiting = true
                context.textDocumentProxy.deleteBackward()
            }
            return
        }
        self.isAccentWaiting = false
        let substitutions = [
            "α": "ά",
            "ε": "έ",
            "ι": "ί",
            "η": "ή",
            "υ": "ύ",
            "ο": "ό",
            "ω": "ώ",
        ]
        for key in substitutions.keys {
            if action == .character(key) {
                    context.textDocumentProxy.deleteBackward()
                    context.textDocumentProxy.insertText("έ")
                    return
                }
        }
    }*/
}
