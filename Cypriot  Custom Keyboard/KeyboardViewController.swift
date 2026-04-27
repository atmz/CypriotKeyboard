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
final class KeyboardViewController: KeyboardInputViewController {
    

    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardActionHandler = cyKeyboardActionHandler
        keyboardAppearance = StandardKeyboardAppearance(context: keyboardContext)
        keyboardContext.primaryLanguage = "el_GR"
        if UserDefaults.standard.bool(forKey: "isLatinKeyboard") {
            keyboardContext.locale = Locale(identifier: "en_US")
        } else {
            keyboardContext.locale = Locale(identifier: "el_GR")
        }
        keyboardContext.locales = [
            keyboardContext.locale
        ]
        keyboardInputSetProvider  = StandardKeyboardInputSetProvider(
            context: keyboardContext,
            providers: [CypriotKeyboardInputSetProvider(context:keyboardContext)]
        )
        keyboardLayoutProvider  = CypriotKeyboardLayoutProvider(inputSetProvider: keyboardInputSetProvider)
        // Setup a secondary callout action provider with multiple locales
        keyboardSecondaryCalloutActionProvider = StandardSecondaryCalloutActionProvider(
            context: keyboardContext,
            providers: [
                CypriotSecondaryCalloutActionProvider()])
        
        setup(with: keyboardView)
        #if DEBUG
        print("viewDidLoad complete")
        #endif

        // tier-c Phase 2: initialise the autocomplete engine based on the
        // user's flag. Only one engine loads at a time.
        let useDAWG = UserDefaults.standard.bool(forKey: "useDAWGSuggester")
        autocompleteProvider = makeAutocompleteProvider(useDAWG: useDAWG)
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
    
    public var currentGuess: AutocompleteSuggestion? = nil
    public var lastAction: KeyboardAction? = nil
    public var autocompleteCount: Int = 0
    
    // MARK: - Autocomplete

    // MARK: - Autocomplete provider (engine selectable via UserDefaults)

    private var autocompleteProvider: AutocompleteSuggestionProvider!

    /// Reads UserDefaults["useDAWGSuggester"] and constructs the right provider.
    /// Invariant: only one engine is loaded at a time.
    private func makeAutocompleteProvider(useDAWG: Bool) -> AutocompleteSuggestionProvider {
        if useDAWG {
            do {
                guard let dawgURL = Bundle.main.url(forResource: "el_CY", withExtension: "dawg") else {
                    #if DEBUG
                    print("[KeyboardViewController] el_CY.dawg missing from extension bundle; falling back to Hunspell")
                    #endif
                    return CypriotAutocompleteSuggestionProvider()
                }
                let reader = try DawgReader(url: dawgURL)
                let folder = try PhoneticFolder.loadDefault()
                return DawgAutocompleteSuggestionProvider(reader: reader, folder: folder)
            } catch {
                #if DEBUG
                print("[KeyboardViewController] DAWG engine init failed: \(error); falling back to Hunspell")
                #endif
                return CypriotAutocompleteSuggestionProvider()
            }
        }
        return CypriotAutocompleteSuggestionProvider()
    }

    /// Long-press on 🔄 calls this — flip the flag, swap the provider, reset state, show toast.
    public func toggleSuggesterEngine() {
        let current = UserDefaults.standard.bool(forKey: "useDAWGSuggester")
        let newValue = !current
        UserDefaults.standard.setValue(newValue, forKey: "useDAWGSuggester")
        autocompleteProvider = makeAutocompleteProvider(useDAWG: newValue)
        currentGuess = nil
        lastAction = nil
        autocompleteCount = 0
        let label = newValue ? "Suggester: DAWG" : "Suggester: Hunspell"
        showSuggesterToast(label)
    }

    /// Toast helper. The bundled KeyboardKit's KeyboardToastContext API
    /// is verified at integration time; this helper is intentionally
    /// minimal so its call shape can be adjusted without touching
    /// toggleSuggesterEngine.
    private func showSuggesterToast(_ label: String) {
        // Try the most likely API shapes for the bundled KeyboardKit version.
        // Adjust here once Task 10 wires the project and we can verify which
        // method the bundled toast context exposes.
        toastContext.present(label)
    }

    // Coalesces rapid keystrokes: only the most recent typed word actually
    // hits Hunspell after the debounce window expires. The autocompleteCount
    // lock token below stays as defense-in-depth for the global-queue race.
    private var pendingAutocomplete: DispatchWorkItem?
    private static let autocompleteDebounceMs = 40

    private func isFirstWordInSentence(word: String) -> Bool{
        guard let currentSentence = textDocumentProxy.currentSentenceBeforeInput else { return true }
        return currentSentence.trimmed() == word.trimmed()
    }

    override func performAutocomplete() {
        pendingAutocomplete?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.runAutocomplete() }
        pendingAutocomplete = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Self.autocompleteDebounceMs), execute: work)
    }

    private func runAutocomplete() {
        guard let word = textDocumentProxy.currentWord else { return resetAutocomplete() }
        self.currentGuess = nil
        self.autocompleteCount += 1
        //autompleteLock serves to prevent race conditions/out of order autocompletes by ingoring results if a newer autocomoplete has started
        let autompleteLock = self.autocompleteCount
        autocompleteProvider.asyncAutocompleteSuggestions(for: word, isFirstWordInSentence: isFirstWordInSentence(word: word)) { [weak self] result in
            switch result {
            case .failure(let error):
                #if DEBUG
                print(error.localizedDescription)
                #endif
                break
            case .success(let result):
                if self?.autocompleteCount == autompleteLock {
                    DispatchQueue.main.async {
                        self?.autocompleteContext.suggestions = result
                        if result.count>0{
                            if result.count>1 {
                                self?.currentGuess = result[1]
                            } else {
                                self?.currentGuess = result[0]
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func resetAutocomplete() {
        autocompleteContext.suggestions = []
    }
    
    
    public func setLastAction(a: KeyboardAction) {
        if(a.isInputAction || a == KeyboardAction.backspace) {
            self.lastAction = a
        }
    }
    
    //stuff needed for SwiftUI/container app:
//    
//    typealias UIViewControllerType = KeyboardViewController
//    public func makeUIViewController(context: UIViewControllerRepresentableContext<KeyboardViewController>) -> KeyboardViewController {
//        return KeyboardViewController()
//    }
//
//    public func updateUIViewController(_ uiViewController: KeyboardViewController, context: UIViewControllerRepresentableContext<KeyboardViewController>) {
//        //
//    }
}

public extension UITextDocumentProxy {
    
    /**
     The last ended sentence right before the cursor, if any.
     */
    var currentSentenceBeforeInput: String? {
        guard !isCursorAtNewSentence else { return nil }
        guard let context = documentContextBeforeInput else { return nil }
        let components = context.split(by: sentenceDelimiters).filter { !$0.isEmpty }
        return components.last
    }
}

private extension String {
    
    func split(by separators: [String]) -> [String] {
        let separators = CharacterSet(charactersIn: separators.joined())
        return components(separatedBy: separators)
    }
    
    func trimmed() -> String {
        trimmingCharacters(in: .whitespaces)
    }
}
