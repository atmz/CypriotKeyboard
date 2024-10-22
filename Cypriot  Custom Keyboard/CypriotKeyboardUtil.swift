//
//  CypriotKeyboardUtil.swift
//  Cypriot Keyboard
//
//  Created by Alex Toumazis on 3/16/21.
//

import Foundation


extension String {
    subscript(index: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: index)]
    }
    public func levenshtein(_ other: String) -> Int {
        let sCount = self.count
        let oCount = other.count

        guard sCount != 0 else {
            return oCount
        }

        guard oCount != 0 else {
            return sCount
        }

        let line : [Int]  = Array(repeating: 0, count: oCount + 1)
        var mat : [[Int]] = Array(repeating: line, count: sCount + 1)

        for i in 0...sCount {
            mat[i][0] = i
        }

        for j in 0...oCount {
            mat[0][j] = j
        }

        for j in 1...oCount {
            for i in 1...sCount {
                if self[i - 1] == other[j - 1] {
                    mat[i][j] = mat[i - 1][j - 1]       // no operation
                }
                else {
                    let del = mat[i - 1][j] + 1         // deletion
                    let ins = mat[i][j - 1] + 1         // insertion
                    let sub = mat[i - 1][j - 1] + 1     // substitution
                    mat[i][j] = min(min(del, ins), sub)
                }
            }
        }

        return mat[sCount][oCount]
    }

}

class CypriotKeyboardHelper {
    
    static func countSyllables(text: String) -> Int {
        var count = 0
        let vowels = "αειυηοω"
        var last=Character("Q")
        for letter in text.lowercased() {
            if vowels.contains(letter) && !vowels.contains(last) {
                count+=1
            }
            last = letter
        }
        return count
    }
    
    static private func normalizeGreekWord(greekWord: String)-> String{
        // Convert greek word to something more comparable with a transliterated string.
        // Implementation details linked to greekify, since it will be comparing against greekify strings
        return greekWord
            .lowercased()
            //First, check for compound letters that can be reduced to 'i' or 'e' before we remove tonous
            .replacingOccurrences(of: "ει", with: "ι")
            .replacingOccurrences(of: "εί", with: "ι")
            .replacingOccurrences(of: "οι", with: "ι")
            .replacingOccurrences(of: "οί", with: "ι")
            // get rid of tonous
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
            //replace other letters
            .replacingOccurrences(of: "η", with: "ι")
    }
    
    
    static func distanceMeasure(transliteratedWord: String, greekWord: String) -> Double {
        
        let a = greekWord.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
        let b = transliteratedWord.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
/*
         var score = 0.0

        let aCount = a.count
        let bCount = b.count
        if (aCount < 1 || bCount < 1) {
            return 0.0
        }
        
        for i in 1...aCount {
            if i <= bCount && a[i - 1] == b[i - 1] {
                score+=1
            }
        }
        return score/Double(aCount)*/
        let levenshtein=a.levenshtein(b)
        return Double(levenshtein)
    }
    
    static func getOverrideMatch(for text:String) -> String?{
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
    
    static func greekify(text:String)  -> String {
 
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
            
        //"γι" is pronounced "yi", but other uses of "γ" are "g"s
            .replacingOccurrences(of: "yi", with: "γι")
            .replacingOccurrences(of: "Yi", with: "Γι")
    
            .replacingOccurrences(of: "ngk", with: "γκ")
            .replacingOccurrences(of: "ng", with: "γκ")
            
            //th can be theta or τη - todo: better solution
            .replacingOccurrences(of: "ths", with: "τησ")
            .replacingOccurrences(of: "Ths", with: "Τησ")
        
            
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
            
            .replacingOccurrences(of: "y", with: "υ")
            .replacingOccurrences(of: "Y", with: "Υ")
             
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
            
            .replacingOccurrences(of: "3", with: "ξ")
             
     }
    
    static func isCommonWord(word:String) -> Bool {
        return commonWords.contains(word.lowercased())
    }
    static let commonWords = ["άλλα",
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
}
