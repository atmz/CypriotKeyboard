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
                       "έν",
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
                       "γι",
                       "για",
                       "γιατί",
                       "γινεί",
                       "γράφω",
                       "γράψω",
                       "γυναίκα",
                       "γυναίκες",
                       "γω",
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
                       "εννα",
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
                       "θκυό",
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
                       "καν",
                       "κανένα",
                       "κανέναν",
                       "κανένας",
                       "κατά",
                       "κατάσταση",
                       "καταλάβει",
                       "καταλάβω",
                       "καφέ",
                       "κεφάλι",
                       "κι",
                       "κλπ",
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
                       "παν",
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
                       "τζαι",
                       "τζαιρόν",
                       "τζείνα",
                       "τζείνη",
                       "τζείνην",
                       "τζείνοι",
                       "τζείνον",
                       "τζείνος",
                       "τζείνους",
                       "τζι",
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
                       "υγ",
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
        completion(.success(self.suggestions(for: text, speller:self.speller, commonWords: self.commonWords)))
    }
    
    func asyncAutocompleteSuggestions(for text: String,  completion: @escaping AutocompleteResponse) {
        guard text.count > 0 else { return completion(.success([])) }
        DispatchQueue.global().async {
            completion(.success(self.suggestions(for: text, speller:self.speller, commonWords: self.commonWords)))
        }
    }
}

public struct DemoAutocompleteSuggestion: AutocompleteSuggestion {
    
    public var replacement: String
    public var title: String
    public var subtitle: String?
    public var additionalInfo: [String: Any] { [:] }
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

    
    func suggestions(for text: String, speller:OpaquePointer?, commonWords:[String]) -> [DemoAutocompleteSuggestion] {
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
        var commonMatch : String? = nil
        for suggestion in hunspellSuggestions {
            if commonWords.contains(suggestion) {
                commonMatch = suggestion
                break
            }
        }
        let suggestionsToShow = min(2, hunspellSuggestions.count)
        switch suggestionsToShow {
        case 2:
           /* if let override = getOverrideMatch(for: text)    {
                //e.g. για->["γεια", "για"]
                    if text == override {
                        print("exact match")
                        return [
                            hunspellSuggestions[1] != text ? suggestion(hunspellSuggestions[1]) : suggestion(hunspellSuggestions[2]),
                            suggestion(text, false),
                            hunspellSuggestions[0] != text ? suggestion(hunspellSuggestions[0]) : suggestion(hunspellSuggestions[3]),
                        ]
                    } else {
                        return [
                            suggestion(text, true),
                            suggestion(override, false),
                            hunspellSuggestions[0] != override ? suggestion(hunspellSuggestions[0]) : suggestion(hunspellSuggestions[1])
                        ]
                    }
                } else */
            if let commonMatchString = commonMatch {
                    print("common match")
                    print(commonMatchString)
                return [
                    suggestion(text, true),
                    suggestion(commonMatchString),
                    hunspellSuggestions[0] != commonMatchString ? suggestion(hunspellSuggestions[0]) : suggestion(hunspellSuggestions[1])
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
    
    func suggestion(_ word: String, _ verbatim: Bool = false,_ subtitle: String? = nil) -> DemoAutocompleteSuggestion {
        DemoAutocompleteSuggestion(replacement: word, title:(verbatim ? ("\""+word+"\""):word), subtitle: subtitle)
    }
    
    
    private func greekify(text:String)  -> String {
        return text
            //.replacingOccurrences(of: "sh", with: "σ̆σ̆")
            .replacingOccurrences(of: "sh", with: "σι")
            //.replacingOccurrences(of: "j", with: "τž")
            .replacingOccurrences(of: "j", with: "τζ")
            //.replacingOccurrences(of: "ch", with: "τσ̆")
            .replacingOccurrences(of: "ev", with: "ευ")
            .replacingOccurrences(of: "ps", with: "ψ")
            .replacingOccurrences(of: "ks", with: "ξ")
        //.replacingOccurrences(of: "sh", with: "σι")
            .replacingOccurrences(of: "Th", with: "Θ")
            .replacingOccurrences(of: "Ef", with: "Ευ")
            .replacingOccurrences(of: "Ps", with: "Ψ")
            .replacingOccurrences(of: "Ks", with: "Ξ")
            .replacingOccurrences(of: "Sh", with: "Σι")
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
