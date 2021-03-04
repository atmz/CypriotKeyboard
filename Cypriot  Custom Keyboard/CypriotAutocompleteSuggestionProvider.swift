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
    
    
    let commonWords = ["άλλα",
                       "άλλες",
                       "άλλη",
                       "άλλην",
                       "άλλο",
                       "άλλοι",
                       "άλλον",
                       "άλλος",
                       "άλλου",
                       "άλλους",
                       "άμα",
                       "άμαν",
                       "άνθρωποι",
                       "άνθρωπος",
                       "άντρα",
                       "άντρας",
                       "άντρες",
                       "άτε",
                       "άτομα",
                       "άτομο",
                       "έβαλα",
                       "έγινε",
                       "έκαμα",
                       "έκαμεν",
                       "έκαμνεν",
                       "έκανε",
                       "ένα",
                       "έναν",
                       "ένας",
                       "ένι",
                       "έννεν",
                       "έξω",
                       "έπρεπε",
                       "έπρεπεν",
                       "έρκεται",
                       "έρτει",
                       "έσιει",
                       "έσιεις",
                       "έσσω",
                       "έστω",
                       "έτσι",
                       "έχει",
                       "έχεις",
                       "έχουμε",
                       "έχουμεν",
                       "έχουν",
                       "έχω",
                       "ήβρα",
                       "ήδη",
                       "ήθελα",
                       "ήμουν",
                       "ήρτεν",
                       "ήταν",
                       "ίδια",
                       "ίδιο",
                       "ίδιον",
                       "ίντα",
                       "ίσως",
                       "αγάπη",
                       "ακούω",
                       "ακριβώς",
                       "ακόμα",
                       "αλήθκεια",
                       "αλλά",
                       "αλλιώς",
                       "αλλού",
                       "αν",
                       "ανθρώπους",
                       "αντί",
                       "απάντηση",
                       "απέναντι",
                       "απλά",
                       "από",
                       "αρέσει",
                       "αρέσκει",
                       "αρκετά",
                       "αρχή",
                       "ας",
                       "αυτά",
                       "αυτή",
                       "αυτοκίνητο",
                       "αυτό",
                       "αυτόν",
                       "αυτός",
                       "αφού",
                       "βάλει",
                       "βάλω",
                       "βέβαια",
                       "βιβλία",
                       "βιβλίο",
                       "βλέπω",
                       "βράδυ",
                       "γίνει",
                       "γίνεται",
                       "γεναίκα",
                       "γενικά",
                       "για",
                       "γιατί",
                       "γινεί",
                       "γράφω",
                       "γράψω",
                       "γυναίκα",
                       "γυναίκες",
                       "γύρω",
                       "δέκα",
                       "δίπλα",
                       "δίχα",
                       "δαμέ",
                       "δε",
                       "δείτε",
                       "δει",
                       "δεις",
                       "δεν",
                       "δηλαδή",
                       "διά",
                       "διακοπές",
                       "δικά",
                       "δική",
                       "δικό",
                       "διότι",
                       "δουλειά",
                       "δουλειάν",
                       "δουλειές",
                       "δρόμο",
                       "δω",
                       "δύο",
                       "είδα",
                       "είμαι",
                       "είμαστε",
                       "είμαστεν",
                       "είναι",
                       "είπα",
                       "είπαμεν",
                       "είπε",
                       "είπεν",
                       "είσαι",
                       "είσιεν",
                       "είτε",
                       "είχα",
                       "είχαν",
                       "είχε",
                       "εαυτό",
                       "εγίνην",
                       "εγώ",
                       "εδώ",
                       "ειδικά",
                       "εις",
                       "εκάμαν",
                       "εκατάλαβα",
                       "εκεί",
                       "εκτός",
                       "ελάλεν",
                       "ελληνικά",
                       "εμένα",
                       "εμέναν",
                       "εμείς",
                       "εν",
                       "εννά",
                       "εντάξει",
                       "εντελώς",
                       "ενός",
                       "ενώ",
                       "επίσης",
                       "επειδή",
                       "επιτέλους",
                       "εσύ",
                       "ευρώ",
                       "ζωή",
                       "ζωήν",
                       "ζωής",
                       "ημέραν",
                       "θέλει",
                       "θέλεις",
                       "θέλουν",
                       "θέλω",
                       "θέμα",
                       "θέση",
                       "θα",
                       "θκυο",
                       "θωρεί",
                       "θωρώ",
                       "ιδέα",
                       "ιστορία",
                       "κάθε",
                       "κάμει",
                       "κάμεις",
                       "κάμνει",
                       "κάμνεις",
                       "κάμνουν",
                       "κάμνω",
                       "κάμουμεν",
                       "κάμουν",
                       "κάμω",
                       "κάνει",
                       "κάνεις",
                       "κάνουν",
                       "κάνω",
                       "κάποια",
                       "κάποιο",
                       "κάποιοι",
                       "κάποιον",
                       "κάποιος",
                       "κάποτε",
                       "κάπου",
                       "κάπως",
                       "κάτι",
                       "κάτω",
                       "καθόλου",
                       "καθώς",
                       "και",
                       "καιρό",
                       "καλά",
                       "καλή",
                       "καλλύττερα",
                       "καλό",
                       "καλόν",
                       "καμιά",
                       "καμιάν",
                       "κανένα",
                       "κανέναν",
                       "κανένας",
                       "κατά",
                       "κατάσταση",
                       "καταλάβει",
                       "καταλάβω",
                       "καφέ",
                       "κεφάλι",
                       "κοινωνία",
                       "κοντά",
                       "κοπελλούθκια",
                       "κουβέντα",
                       "κράτος",
                       "κρίση",
                       "κυπριακά",
                       "κυρία",
                       "κόρη",
                       "κόσμο",
                       "κόσμον",
                       "κόσμος",
                       "κόσμου",
                       "κόφτει",
                       "κύπρο",
                       "κύριε",
                       "λάθος",
                       "λέει",
                       "λένε",
                       "λέξεις",
                       "λέξη",
                       "λέω",
                       "λίγο",
                       "λαλεί",
                       "λαλείς",
                       "λαλείτε",
                       "λαλούν",
                       "λαλώ",
                       "λεπτά",
                       "λες",
                       "λεφτά",
                       "λλία",
                       "λλίο",
                       "λλίον",
                       "λοιπόν",
                       "λόγια",
                       "λόγο",
                       "λόγω",
                       "λύση",
                       "μάλιστα",
                       "μάλλον",
                       "μάνα",
                       "μάτια",
                       "μένα",
                       "μέρα",
                       "μέρες",
                       "μέρος",
                       "μέσα",
                       "μέτρα",
                       "μέχρι",
                       "μήνα",
                       "μήνες",
                       "μα",
                       "μαζί",
                       "μαζίν",
                       "μακριά",
                       "μαλακίες",
                       "μαλλιά",
                       "μας",
                       "με",
                       "μεγάλη",
                       "μεγάλο",
                       "μεν",
                       "μες",
                       "μετά",
                       "μεταξύ",
                       "μη",
                       "μην",
                       "μια",
                       "μιαν",
                       "μιας",
                       "μικρή",
                       "μιλά",
                       "μμάθκια",
                       "μου",
                       "μουσική",
                       "μπλα",
                       "μπλογκ",
                       "μπορεί",
                       "μπορείς",
                       "μπορούν",
                       "μπορώ",
                       "μπροστά",
                       "μυαλό",
                       "μωρά",
                       "μωρό",
                       "μωρόν",
                       "μόλις",
                       "μόνη",
                       "μόνο",
                       "μόνον",
                       "μόνος",
                       "νέα",
                       "να",
                       "ναι",
                       "ναν",
                       "νερό",
                       "νερόν",
                       "νεύρα",
                       "νιώθω",
                       "νομίζω",
                       "νου",
                       "νύχτα",
                       "ξέρει",
                       "ξέρεις",
                       "ξέρετε",
                       "ξέρουν",
                       "ξέρω",
                       "ξανά",
                       "οι",
                       "οικογένεια",
                       "ολάν",
                       "οποία",
                       "οποίο",
                       "οπότε",
                       "ούλλα",
                       "ούλλες",
                       "ούλλη",
                       "ούλλοι",
                       "ούλλους",
                       "ούτε",
                       "πάει",
                       "πάεις",
                       "πάλε",
                       "πάμε",
                       "πάντα",
                       "πάνω",
                       "πάρα",
                       "πάρει",
                       "πάω",
                       "πέντε",
                       "πίσω",
                       "παίζει",
                       "παιδί",
                       "παιδιά",
                       "παλιά",
                       "παρά",
                       "παρέα",
                       "παραπάνω",
                       "πας",
                       "πει",
                       "πεις",
                       "πελλάρες",
                       "περάσει",
                       "περίπου",
                       "περνά",
                       "πιάννει",
                       "πιο",
                       "πλάσμαν",
                       "πλάσματα",
                       "πλέον",
                       "ποδά",
                       "ποια",
                       "ποιος",
                       "πολλά",
                       "πολλές",
                       "πολλή",
                       "πολύ",
                       "πον",
                       "ποστ",
                       "ποτέ",
                       "ποττέ",
                       "που",
                       "πουπάνω",
                       "πους",
                       "πούμε",
                       "πούμεν",
                       "πράγματα",
                       "πράμα",
                       "πράμαν",
                       "πράματα",
                       "πρέπει",
                       "πραγματικά",
                       "πραγματικότητα",
                       "πριν",
                       "προς",
                       "πρωί",
                       "πρόβλημα",
                       "πρόβλημαν",
                       "πρώτα",
                       "πρώτη",
                       "πρώτο",
                       "πρώτον",
                       "πω",
                       "πως",
                       "πόλη",
                       "πόρτα",
                       "πόσα",
                       "πόσο",
                       "πόσον",
                       "πότε",
                       "πώς",
                       "ρε",
                       "ριάλλια",
                       "ρούχα",
                       "σήμερα",
                       "σαν",
                       "σας",
                       "σε",
                       "σειρά",
                       "σημαίνει",
                       "σημασία",
                       "σιγά",
                       "σου",
                       "σπίτι",
                       "σπίτιν",
                       "στα",
                       "στες",
                       "στη",
                       "στην",
                       "στιγμή",
                       "στις",
                       "στο",
                       "στον",
                       "στους",
                       "συζήτηση",
                       "συνέχεια",
                       "σχέση",
                       "σχεδόν",
                       "σύστημα",
                       "τέλεια",
                       "τέλος",
                       "τέλοσπάντων",
                       "τίποτα",
                       "τίποτε",
                       "τα",
                       "ταινία",
                       "ταινίες",
                       "τελευταία",
                       "τελικά",
                       "τες",
                       "τζ̆αι",
                       "τζ̆αιρόν",
                       "τζ̆είνα",
                       "τζ̆είνη",
                       "τζ̆είνην",
                       "τζ̆είνοι",
                       "τζ̆είνον",
                       "τζ̆είνος",
                       "τζ̆είνους",
                       "τζ̆ι",
                       "τζιαι",
                       "τζιαιρόν",
                       "τζιαμέ",
                       "τη",
                       "τηλέφωνο",
                       "τηλεόραση",
                       "την",
                       "της",
                       "τι",
                       "τις",
                       "το",
                       "τον",
                       "του",
                       "τουλάχιστον",
                       "τους",
                       "τούτα",
                       "τούτες",
                       "τούτη",
                       "τούτην",
                       "τούτο",
                       "τούτοι",
                       "τούτον",
                       "τρία",
                       "τρεις",
                       "τρόπο",
                       "των",
                       "τωρά",
                       "τόπον",
                       "τόσα",
                       "τόσο",
                       "τόσον",
                       "τότε",
                       "τύπος",
                       "τύπου",
                       "τώρα",
                       "υπάρχει",
                       "υπάρχουν",
                       "φάει",
                       "φάση",
                       "φίλη",
                       "φίλοι",
                       "φίλους",
                       "φαίνεται",
                       "φκάλλει",
                       "φορά",
                       "φοράν",
                       "φορές",
                       "φυσικά",
                       "φωνή",
                       "φωτογραφίες",
                       "χέρι",
                       "χέρια",
                       "χαρά",
                       "χρειάζεται",
                       "χρονών",
                       "χρόνια",
                       "χρόνο",
                       "χρόνον",
                       "χωρίς",
                       "χωρκόν",
                       "χώρα",
                       "ωραία",
                       "ως",
                       "όλα",
                       "όλες",
                       "όλη",
                       "όλο",
                       "όλοι",
                       "όλους",
                       "όμως",
                       "όνομα",
                       "όποτε",
                       "όπου",
                       "όπως",
                       "όσα",
                       "όσο",
                       "όσον",
                       "όταν",
                       "ότι",
                       "όχι",
                       "ύστερα",
                       "ύφος",
                       "ώρα",
                       "ώραν",
                       "ώρες",
                       "ώσπου"]
    
    
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
        completion(.success(self.suggestions(for: text, speller:self.speller, isFirstWordInSentence:false, commonWords: self.commonWords)))
    }
    
    func asyncAutocompleteSuggestions(for text: String, isFirstWordInSentence: Bool, completion: @escaping AutocompleteResponse) {
        guard text.count > 0 else { return completion(.success([])) }
        DispatchQueue.global().async {
            completion(.success(self.suggestions(for: text, speller:self.speller, isFirstWordInSentence:isFirstWordInSentence, commonWords: self.commonWords)))
        }
    }
}

public struct CypriotAutocompleteSuggestion: AutocompleteSuggestion {
    
    public var replacement: String
    public var title: String
    public var subtitle: String?
    public var additionalInfo: [String: Any] 
}

func getOverrideMatch(for text:String) -> String?{
    let overrides = [
        "me":"με",
        "με":"με",
        "gia":"για",
        "yia":"για",
        "για":"για",
        "na":"να",
        "να":"να",
        "sou":"σου",
        "σου":"σου",
        "mou":"μου",
        "μου":"μου",
        "pou":"που",
        "που":"που",
        "en":"εν",
        "εν":"εν",
        "η":"η",
        "h":"η",
        "ο":"ο",
        "o":"ο",
    ]
    if let override = overrides[text] {
        return override
    }
    return nil
}

private extension AutocompleteSuggestionProvider {

    func countSyllables(text: String) -> Int {
        var count = 0
        let vowels = "αειυηοω"
        var last=Character(" ")
        for letter in text {
            if vowels.contains(letter) && !vowels.contains(last) {
                count+=1
            }
            last = letter
        }
        return count
            
        
    }
    
    func shouldReplace(text: String, greekText: String, guess: String)-> Bool{
        // we don't have context here, this will only be true if all characters in the
        // word are greek
        if(text == greekText) {
            // Only replace in Greek if accent-only change, and >1 syllable
            if countSyllables(text:text)<2 {
                return false
            }
            let accentlessWord = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
            let accentlessGuess = guess.folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
            // If words are the same without accents, and guess has accents, replace
            // with guess.
            return accentlessWord == accentlessGuess && accentlessGuess != guess
        } else {
            return true
        }
    }
    
    func suggestions(for text: String, speller:OpaquePointer?, isFirstWordInSentence:Bool, commonWords:[String]) -> [CypriotAutocompleteSuggestion] {
        guard speller != nil else { return [] }
        let greekText = greekify(text: text)
        var suggestions_ptr: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
        let suggestions_ptr_0 = suggestions_ptr
        
        /* Three cases to consider:
         a) If word is lowercase, check lowercase suggestions
         b) if word is not the first word in the sentence and starts with an uppercase letter,
         check 'proper noun' suggestions
         c) For first word in sentence, we can't tell so check both and interleave
         */
        let isCapitalFirst = greekText != greekText.lowercased() && greekText.suffix(greekText.count-1) == greekText.lowercased().suffix(greekText.count-1)
        let shouldCheckLowercase = isFirstWordInSentence && isCapitalFirst
        
        let suggestCount = Hunspell_suggest(speller,&suggestions_ptr, greekText)
        
        print(greekText, isFirstWordInSentence, shouldCheckLowercase)
        var hunspellSuggestions: [String] = []
        if suggestions_ptr != nil {
            while let s = suggestions_ptr?.pointee, hunspellSuggestions.count<suggestCount {
                hunspellSuggestions.append( String(cString: s))
                free(s)
                suggestions_ptr=suggestions_ptr?.advanced(by: 1)
            }
            free(suggestions_ptr_0)
            print(hunspellSuggestions)
        }
        // Case where we also should check lowercase
        if(shouldCheckLowercase) {
            var suggestions_ptr: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
            let suggestions_ptr_0_lowercase = suggestions_ptr
            let suggestCount = Hunspell_suggest(speller,&suggestions_ptr, greekText.lowercased())
            if suggestions_ptr != nil {
                var i = 0
                while let s = suggestions_ptr?.pointee, i<suggestCount {
                    var suggestionString = String(cString: s)
                    suggestionString = suggestionString.prefix(1).uppercased() + suggestionString.suffix(suggestionString.count-1)
                        // Interleave lowercase/uppercase suggestions
                        hunspellSuggestions.insert(suggestionString, at: i*2)
                        free(s)
                        suggestions_ptr=suggestions_ptr?.advanced(by: 1)
                        i+=1
                }
                free(suggestions_ptr_0_lowercase)
                print(hunspellSuggestions)
            }
        }
        
        var priorityMatch : String? = nil
        
        for suggestion in hunspellSuggestions {
            if(shouldReplace(text: text, greekText: greekText, guess: suggestion)) {
                priorityMatch = suggestion
                break
            }
        }
        if text != greekText {
            //if we're not in greek, there will be more variation and we use common words
            for suggestion in hunspellSuggestions {
                if commonWords.contains(suggestion.lowercased()) {
                    priorityMatch = suggestion
                    break
                }
            }
        }
        let suggestionsToShow = min(2, hunspellSuggestions.count)
        switch suggestionsToShow {
        case 2:
            // Common word match or match except for accents, ignore hunspell ordering and suggest it
            if let priorityMatchString = priorityMatch {
                    print("common match")
                    print(priorityMatchString)
                return [
                    suggestion(text, verbatim:true),
                    suggestion(priorityMatchString, willReplace:shouldReplace(text: text, greekText: greekText, guess: priorityMatchString)),
                    hunspellSuggestions[0] != priorityMatchString ? suggestion(hunspellSuggestions[0]) : suggestion(hunspellSuggestions[1])
                ]
            // Second suggestion is exact match except for accents, use it
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
    
    
    private func greekify(text:String)  -> String {
        return text
            .replacingOccurrences(of: "sh", with: "σ̆")
            .replacingOccurrences(of: "Sh", with: "Σ̆")
            
            .replacingOccurrences(of: "ch", with: "τσ̆")
            .replacingOccurrences(of: "Ch", with: "Τσ̆")
            
            .replacingOccurrences(of: "ps", with: "ψ")
            .replacingOccurrences(of: "Ps", with: "Ψ")
            .replacingOccurrences(of: "ks", with: "ξ")
            .replacingOccurrences(of: "Ks", with: "Ξ")
            
            .replacingOccurrences(of: "Th", with: "Θ")
            .replacingOccurrences(of: "th", with: "θ")
            
            .replacingOccurrences(of: "j", with: "τζ̆")
            .replacingOccurrences(of: "J", with: "Τζ̆")
            
            .replacingOccurrences(of: "a", with: "α")
            .replacingOccurrences(of: "A", with: "Α")
            
            .replacingOccurrences(of: "i", with: "ι")
            .replacingOccurrences(of: "I", with: "Ι")
            
            .replacingOccurrences(of: "e", with: "ε")
            .replacingOccurrences(of: "E", with: "Ε")
            
            .replacingOccurrences(of: "o", with: "ο")
            .replacingOccurrences(of: "O", with: "Ο")
            
            .replacingOccurrences(of: "u", with: "υ")
            .replacingOccurrences(of: "U", with: "Υ")
            
            .replacingOccurrences(of: "y", with: "γ")
            .replacingOccurrences(of: "Y", with: "Γ")
            
            .replacingOccurrences(of: "w", with: "ω")
            .replacingOccurrences(of: "W", with: "Ω")
            
            .replacingOccurrences(of: "r", with: "ρ")
            .replacingOccurrences(of: "R", with: "Ρ")
            
            .replacingOccurrences(of: "t", with: "τ")
            .replacingOccurrences(of: "T", with: "Τ")
            
            .replacingOccurrences(of: "p", with: "π")
            .replacingOccurrences(of: "P", with: "Π")
            
            .replacingOccurrences(of: "s", with: "σ")
            .replacingOccurrences(of: "S", with: "Σ")
            
            .replacingOccurrences(of: "d", with: "δ")
            .replacingOccurrences(of: "D", with: "Δ")
            
            .replacingOccurrences(of: "f", with: "φ")
            .replacingOccurrences(of: "F", with: "Φ")
            
            .replacingOccurrences(of: "g", with: "γ")
            .replacingOccurrences(of: "G", with: "Γ")
            
            .replacingOccurrences(of: "h", with: "η")
            .replacingOccurrences(of: "H", with: "Η")
            
            .replacingOccurrences(of: "k", with: "κ")
            .replacingOccurrences(of: "K", with: "Κ")
            
            .replacingOccurrences(of: "l", with: "λ")
            .replacingOccurrences(of: "L", with: "Λ")
            
            .replacingOccurrences(of: "z", with: "ζ")
            .replacingOccurrences(of: "Z", with: "Ζ")
            
            .replacingOccurrences(of: "x", with: "χ")
            .replacingOccurrences(of: "X", with: "Χ")
            
            .replacingOccurrences(of: "c", with: "κ")
            .replacingOccurrences(of: "C", with: "Κ")
            
            .replacingOccurrences(of: "v", with: "β")
            .replacingOccurrences(of: "V", with: "Β")
            
            .replacingOccurrences(of: "b", with: "μπ")
            .replacingOccurrences(of: "B", with: "Μπ")
            
            .replacingOccurrences(of: "n", with: "ν")
            .replacingOccurrences(of: "N", with: "Ν")
            
            .replacingOccurrences(of: "m", with: "μ")
            .replacingOccurrences(of: "M", with: "Μ")
            
    }
    
}
