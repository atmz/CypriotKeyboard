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
    deinit {
        Hunspell_destroy(self.speller)
    }
    
    func autocompleteSuggestions(for text: String, completion: (AutocompleteResult) -> Void) {
        guard text.count > 0 else { return completion(.success([])) }
        completion(.success(self.suggestions(for: text, speller:self.speller, isFirstWordInSentence:false)))
    }
    
    func asyncAutocompleteSuggestions(for text: String, isFirstWordInSentence: Bool, completion: @escaping AutocompleteResponse) {
        guard text.count > 0 else { return completion(.success([])) }
        DispatchQueue.global().async {
            completion(.success(self.suggestions(for: text, speller:self.speller, isFirstWordInSentence:isFirstWordInSentence)))
        }
    }
}

public struct CypriotAutocompleteSuggestion: AutocompleteSuggestion {
    
    public var replacement: String
    public var title: String
    public var subtitle: String?
    public var additionalInfo: [String: Any] 
}


private extension AutocompleteSuggestionProvider {

    
    func shouldReplace(text: String, greekText: String, guess: String)-> Bool{
        // This will only be true if all characters in the word are greek
        if(text == greekText) {
            // In Greek, we only auto-replace accent-only changes
            if CypriotKeyboardHelper.countSyllables(text:text)<2 {
                // if short, don't auto-replace -- one-syllable words don't need accents
                return false
            }
            let accentlessWord = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
            let accentlessGuess = guess.folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
            if(guess != guess.lowercased()) { // guess is not lowercase
                //Special casing for now in case we want to change later
                return accentlessWord.lowercased() == accentlessGuess.lowercased() // If lowercased words are the same without accents
                    && accentlessGuess != guess // and guess has accents,
                    && accentlessWord.lowercased()  == text.lowercased() // and word does not have accents, replace with guess.
            }
            
            return accentlessWord == accentlessGuess   // If words are the same without accents
                && accentlessGuess != guess // and guess has accents,
                && accentlessWord == text // and word does not have accents, replace with guess.
        } else {
            // if Greeklish, we *always* want to auto-replace
            let score = CypriotKeyboardHelper.distanceMeasure(transliteratedWord: guess, greekWord: greekText)
            print(guess,greekText,score)
            return score>=0.6
        }
    }
    
    func suggestions(for text: String, speller:OpaquePointer?, isFirstWordInSentence:Bool) -> [CypriotAutocompleteSuggestion] {
        guard speller != nil else { return [] }
        let greekText = CypriotKeyboardHelper.greekify(text: text)
        var suggestions_ptr: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
        var suggestions_ptr_0 = suggestions_ptr
        
        
        let isCapitalFirst = greekText != greekText.lowercased() && greekText.suffix(greekText.count-1) == greekText.lowercased().suffix(greekText.count-1)
        let shouldCheckLowercase = isFirstWordInSentence && isCapitalFirst //If first word in sentence, treat as lowercase
        
        // 1. Get suggestions from hunspell engine
        let suggestCount = Hunspell_suggest(speller,&suggestions_ptr, shouldCheckLowercase ? greekText.lowercased() : greekText)

        print(greekText, isFirstWordInSentence, shouldCheckLowercase)
        var hunspellSuggestions: [String] = []
        if suggestions_ptr != nil {
            while let s = suggestions_ptr?.pointee, hunspellSuggestions.count<suggestCount {
                var suggestionString = String(cString: s)
                if shouldCheckLowercase { //If we've forced lowercase, fix capitalization
                    suggestionString = suggestionString.prefix(1).uppercased() + suggestionString.suffix(suggestionString.count-1)
                }
                hunspellSuggestions.append( suggestionString )
                suggestions_ptr=suggestions_ptr?.advanced(by: 1)
            }
            Hunspell_free_list(speller,&suggestions_ptr_0, suggestCount)
            print(hunspellSuggestions)
        }
        
        var priorityMatch : String? = nil
        
        if text == greekText {
        // 2a. In greek: determine if any suggestions are eligible for auto-replace, and if so, tag the first as priorityMatch
            for suggestion in hunspellSuggestions {
                if(shouldReplace(text: text, greekText: greekText, guess: suggestion)) {
                    priorityMatch = suggestion
                    break
                }
            }
        } else {
            // 2b. if we're not in greek, we always autoreplace and so we want to bias towards common words if we don't have a good match
            for suggestion in hunspellSuggestions {
                if priorityMatch==nil && CypriotKeyboardHelper.isCommonWord(word:suggestion.lowercased()) {
                    //if common, set priorityMatch
                    priorityMatch = suggestion
                    print("common match", suggestion)
                    break
                }
            }
           // print("greekText", greekText)
            for suggestion in hunspellSuggestions {
                let suggestionToCompare = CypriotKeyboardHelper.countSyllables(text:greekText)<2 ? suggestion.lowercased() : suggestion.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
                //print("suggestionToCompare", suggestionToCompare)
                if greekText.lowercased() == suggestionToCompare {
                    //If is perfect match (in lowercase, without accents), set priorityMatch and break
                    priorityMatch = suggestion
                    print("perfect match", suggestion)
                    break;
                }
            }
        }
        
        // 3: Determine order/how many/which suggestions to show
        let maxSuggestions = text.count>5 ? 2 : 3 //If words are short, we can fit 4 instead of 3
        //TODO: ipad could show even more
        
        
        let suggestionsToShow = min(maxSuggestions, hunspellSuggestions.count) //But, we can't show more suggestions than we have
        //TODO: lots of duplicated code here, should refactor
        switch suggestionsToShow {
        case 3:
            // Common word match or match except for accents, ignore hunspell ordering and suggest it
            if let priorityMatchString = priorityMatch {
                    print(priorityMatchString)
                return [
                    suggestion(text, verbatim:true),
                    suggestion(priorityMatchString, willReplace:shouldReplace(text: text, greekText: greekText, guess: priorityMatchString)),
                    hunspellSuggestions[0] != priorityMatchString ? suggestion(hunspellSuggestions[0]) : suggestion(hunspellSuggestions[1]),
                    hunspellSuggestions[1] != priorityMatchString ? suggestion(hunspellSuggestions[1]) : suggestion(hunspellSuggestions[2])
                ]
            }
            return [
                suggestion(text, verbatim:true),
                suggestion(hunspellSuggestions[0], willReplace:shouldReplace(text: text, greekText: greekText, guess: hunspellSuggestions[0])),
                suggestion(hunspellSuggestions[1]),
                suggestion(hunspellSuggestions[2]),
            ]
            
        case 2:
            // Common word match or match except for accents, ignore hunspell ordering and suggest it
            if let priorityMatchString = priorityMatch {
                    print(priorityMatchString)
                return [
                    suggestion(text, verbatim:true),
                    suggestion(priorityMatchString, willReplace:shouldReplace(text: text, greekText: greekText, guess: priorityMatchString)),
                    hunspellSuggestions[0] != priorityMatchString ? suggestion(hunspellSuggestions[0]) : suggestion(hunspellSuggestions[1])
                ]
            }
            return [
                suggestion(text, verbatim:true),
                suggestion(hunspellSuggestions[0], willReplace:shouldReplace(text: text, greekText: greekText, guess: hunspellSuggestions[0])),
                suggestion(hunspellSuggestions[1])
            ]
                
        case 1:
            return [
                suggestion(text, verbatim:true),
                suggestion(hunspellSuggestions[0], willReplace:shouldReplace(text: text, greekText: greekText, guess: hunspellSuggestions[0]))
            ]
        default:
            return [
                suggestion(text, verbatim:true)
            ]
        }
    }
    
    func suggestion(_ word: String, verbatim: Bool = false, subtitle: String? = nil, willReplace : Bool = false) -> CypriotAutocompleteSuggestion {
        if willReplace {
            return
                CypriotAutocompleteSuggestion(replacement: word, title:(verbatim ? ("\""+word+"\""):word), subtitle: subtitle, additionalInfo:["willReplace":willReplace])
        } else {
           return CypriotAutocompleteSuggestion(replacement: word, title:(verbatim ? ("\""+word+"\""):word), subtitle: subtitle, additionalInfo:[:])
        }
    }
    
    
   
    
}
