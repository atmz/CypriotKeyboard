//
//  DemoAutocompleteSuggestionProvider.swift
//  KeyboardKitDemo
//
//  Created by Daniel Saidi on 2019-07-05.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//
import Foundation
import KeyboardKit
import hunspell

/**
 This demo provider simply returns the current word suffixed
 with "ly", "er" and "ter".
 
 This class is shared between the demo app and all keyboards.
 */
class CypriotAutocompleteSuggestionProvider: AutocompleteSuggestionProvider {

    

    
    var speller : OpaquePointer?
    init() {
        
        let dicPath = Bundle.main.path(forResource: "el_CY", ofType: "dic")
        let affPath = Bundle.main.path(forResource: "el_CY", ofType: "aff")
        self.speller = nil
        DispatchQueue.global().async {
            self.speller = Hunspell_create(affPath, dicPath)
        }
    }
    func autocompleteSuggestions(for text: String, completion: (AutocompleteResult) -> Void) {
        guard text.count > 0 else { return completion(.success([])) }
        completion(.success(self.suggestions(for: text, speller:self.speller)))
    }
    
    func asyncAutocompleteSuggestions(for text: String,  completion: @escaping AutocompleteResponse) {
        guard text.count > 0 else { return completion(.success([])) }
        DispatchQueue.global().async {
            completion(.success(self.suggestions(for: text, speller:self.speller)))
        }
    }
}

public struct DemoAutocompleteSuggestion: AutocompleteSuggestion {
    
    public var replacement: String
    public var title: String
    public var subtitle: String?
    public var additionalInfo: [String: Any] { [:] }
}

private extension AutocompleteSuggestionProvider {

    
    func suggestions(for text: String, speller:OpaquePointer?) -> [DemoAutocompleteSuggestion] {
        guard speller != nil else { return [] }
        let greekText = greekify(text: text)
        var suggestions_ptr: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
        let suggestions_ptr_0 = suggestions_ptr
        print(greekText)
        let suggestCount = Hunspell_suggest(speller,&suggestions_ptr, greekText)
        var hunspellSuggestions: [String] = []
        if suggestions_ptr != nil {
            while let s = suggestions_ptr?.pointee, hunspellSuggestions.count<suggestCount {
                hunspellSuggestions.append(String(cString: s))
                    free(s)
                    suggestions_ptr=suggestions_ptr?.advanced(by: 1)
            }
            free(suggestions_ptr_0)
            print(hunspellSuggestions)
        }
        let suggestionsToShow = min(2, hunspellSuggestions.count)
        switch suggestionsToShow {
        case 2:
            if hunspellSuggestions[1]==text {
                //slight hack to cover case where hunspell's second suggestion is
                // an exact match
                //e.g. για->["γεια", "για"]
                return [
                    suggestion(text, true),
                    suggestion(hunspellSuggestions[1]),
                    suggestion(hunspellSuggestions[0])
                ]
            }
            return [
                suggestion(text, true),
                suggestion(hunspellSuggestions[0]),
                suggestion(hunspellSuggestions[1])
            ]
            
        case 1:
            return [
                suggestion(text, true),
                suggestion(hunspellSuggestions[0])
            ]
        default:
            return [
                suggestion(text, true)
            ]
        }
    }
    /*
    func suggestions(for text: String, hunspellSuggestions:[String]) -> [DemoAutocompleteSuggestion] {
        let suggestionsToShow = min(text.count>7 ? 2 : 3, hunspellSuggestions.count)
        switch suggestionsToShow {
        case 3:
            return [
                suggestion(hunspellSuggestions[1]),
                suggestion(hunspellSuggestions[0]), // best suggestion in middle
                suggestion(hunspellSuggestions[2])
            ]
        case 2:
            return [
                suggestion(hunspellSuggestions[0]),
                suggestion(hunspellSuggestions[1])
            ]
            
        case 1:
            return [
                suggestion(hunspellSuggestions[0]),
                suggestion(text, true)
            ]
        default:
            return [
                suggestion(text, true)
            ]
        }
    }
 */
    
    func suggestion(_ word: String, _ verbatim: Bool = false,_ subtitle: String? = nil) -> DemoAutocompleteSuggestion {
        DemoAutocompleteSuggestion(replacement: word, title:(verbatim ? ("\""+word+"\""):word), subtitle: subtitle)
    }
    
    
    private func greekify(text:String)  -> String {
        return text
            .replacingOccurrences(of: "th", with: "θ")
            .replacingOccurrences(of: "ef", with: "ευ")
            .replacingOccurrences(of: "ps", with: "ψ")
            .replacingOccurrences(of: "ks", with: "ξ")
            .replacingOccurrences(of: "sh", with: "σι")
            .replacingOccurrences(of: "a", with: "α")
            .replacingOccurrences(of: "i", with: "ι")
            .replacingOccurrences(of: "e", with: "ε")
            .replacingOccurrences(of: "o", with: "ο")
            .replacingOccurrences(of: "u", with: "υ")
            .replacingOccurrences(of: "y", with: "γ")
            .replacingOccurrences(of: "w", with: "ω")
            .replacingOccurrences(of: "r", with: "ρ")
            .replacingOccurrences(of: "t", with: "τ")
            .replacingOccurrences(of: "p", with: "π")
            .replacingOccurrences(of: "s", with: "σ")
            .replacingOccurrences(of: "d", with: "δ")
            .replacingOccurrences(of: "f", with: "φ")
            .replacingOccurrences(of: "g", with: "γ")
            .replacingOccurrences(of: "h", with: "η")
            .replacingOccurrences(of: "j", with: "τζ")
            .replacingOccurrences(of: "k", with: "κ")
            .replacingOccurrences(of: "l", with: "λ")
            .replacingOccurrences(of: "z", with: "ζ")
            .replacingOccurrences(of: "x", with: "χ")
            .replacingOccurrences(of: "c", with: "κ")
            .replacingOccurrences(of: "v", with: "β")
            .replacingOccurrences(of: "b", with: "μπ")
            .replacingOccurrences(of: "n", with: "ν")
            .replacingOccurrences(of: "m", with: "μ")
            
            .replacingOccurrences(of: "Th", with: "Θ")
            .replacingOccurrences(of: "Ef", with: "Ευ")
            .replacingOccurrences(of: "Ps", with: "Ψ")
            .replacingOccurrences(of: "Ks", with: "Ξ")
            .replacingOccurrences(of: "Sh", with: "Σι")
            .replacingOccurrences(of: "A", with: "Α")
            .replacingOccurrences(of: "I", with: "Ι")
            .replacingOccurrences(of: "E", with: "Ε")
            .replacingOccurrences(of: "O", with: "Ο")
            .replacingOccurrences(of: "U", with: "Υ")
            .replacingOccurrences(of: "Y", with: "Γ")
            .replacingOccurrences(of: "W", with: "Ω")
            .replacingOccurrences(of: "R", with: "Ρ")
            .replacingOccurrences(of: "T", with: "Τ")
            .replacingOccurrences(of: "P", with: "Π")
            .replacingOccurrences(of: "S", with: "Σ")
            .replacingOccurrences(of: "D", with: "Δ")
            .replacingOccurrences(of: "F", with: "Φ")
            .replacingOccurrences(of: "G", with: "Γ")
            .replacingOccurrences(of: "H", with: "Η")
            .replacingOccurrences(of: "J", with: "Τζ")
            .replacingOccurrences(of: "K", with: "Κ")
            .replacingOccurrences(of: "L", with: "Λ")
            .replacingOccurrences(of: "Z", with: "Ζ")
            .replacingOccurrences(of: "X", with: "Χ")
            .replacingOccurrences(of: "C", with: "Κ")
            .replacingOccurrences(of: "V", with: "Β")
            .replacingOccurrences(of: "B", with: "Μπ")
            .replacingOccurrences(of: "N", with: "Ν")
            .replacingOccurrences(of: "M", with: "Μ")
    }
}
