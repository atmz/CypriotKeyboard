//
//  KeyboardViewController.swift
//  KeyboardKitDemo
//
//  Created by Daniel Saidi on 2020-06-10.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//
import UIKit
import KeyboardKit
import SwiftUI
import Combine

/**
 This SwiftUI-based demo keyboard demonstrates how to create
 a keyboard extension using `KeyboardKit` and `SwiftUI`.
 
 This keyboard sends text and emoji inputs to the text proxy,
 copies tapped images to the device's pasteboard, saves long
 pressed images to photos etc. It also adds an auto complete
 toolbar that provides fake suggestions for the current word.
 
 `IMPORTANT` To use this keyboard, you must enable it in the
 system keyboard settings ("Settings/General/Keyboards"). It
 needs full access for haptic and audio feedback, for access
 to the user's photos etc.
 
 If you want to use these features in your own app, you must
 add `RequestsOpenAccess` to the extension's `Info.plist` to
 make it possible to enable full access. To access the photo
 album, you have to add a `NSPhotoLibraryAddUsageDescription`
 key to the `host` application's `Info.plist`.
 */
class KeyboardViewController: KeyboardInputViewController {
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardActionHandler = cyKeyboardActionHandler
        keyboardAppearance = StandardKeyboardAppearance(context: keyboardContext)
        keyboardContext.primaryLanguage = "el_GR"
        keyboardContext.locale = Locale(identifier: "el_GR")
        keyboardContext.locales = [
            keyboardContext.locale
        ]
        keyboardInputSetProvider  = StandardKeyboardInputSetProvider(
            context: keyboardContext,
            providers: [CypriotKeyboardInputSetProvider(context:keyboardContext)]
        )
        keyboardLayoutProvider  = CypriotKeyboardiPhoneLayoutProvider(inputSetProvider: keyboardInputSetProvider)
        // Setup a secondary callout action provider with multiple locales
        keyboardSecondaryCalloutActionProvider = StandardSecondaryCalloutActionProvider(
            context: keyboardContext,
            providers: [
                CypriotSecondaryCalloutActionProvider()])
        
        setup(with: keyboardView)
    }
    
    
    
    // MARK: - Properties
    
   public lazy var cyKeyboardActionHandler = CypriotKeyboardActionHandler(
    inputViewController: self)
    
    private let toastContext = KeyboardToastContext()
    private var keyboardView: some View {

        KeyboardView(
            actionHandler: cyKeyboardActionHandler,
            appearance: keyboardAppearance,
            layoutProvider: keyboardLayoutProvider)
            .environmentObject(toastContext)
    }
    
    public var currentGuess: String = ""
    public var autocompleteCount: Int = 0
    
    // MARK: - Autocomplete
    
    
    private lazy var autocompleteProvider = CypriotAutocompleteSuggestionProvider()
    
    override func performAutocomplete() {
        guard let word = textDocumentProxy.currentWord else { return resetAutocomplete() }
        self.currentGuess = ""
        self.autocompleteCount += 1
        //autompleteLock serves to prevent race conditions/out of order autocompletes by ingoring results if a newer autocomoplete has started
        let autompleteLock = self.autocompleteCount
        autocompleteProvider.asyncAutocompleteSuggestions(for: word) { [weak self] result in
            switch result {
            case .failure(let error): print(error.localizedDescription)
            case .success(let result):
                if self?.autocompleteCount == autompleteLock {
                    self?.autocompleteContext.suggestions = result
                    if result.count>0{
                        if result.count>1 {
                            self?.currentGuess = result[1].replacement
                        } else {
                            self?.currentGuess = result[0].replacement
                        }
                    }
                }
            }
        }
    }
    
    override func resetAutocomplete() {
        autocompleteContext.suggestions = []
    }
    
}
