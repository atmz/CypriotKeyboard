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
        // Rolling two-row buffer: O(min(n,m)) extra memory instead of O(n*m).
        let a = Array(self)
        let b = Array(other)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var prev = Array(0...b.count)
        var curr = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            curr[0] = i
            let ai = a[i - 1]
            for j in 1...b.count {
                if ai == b[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = Swift.min(prev[j], curr[j - 1], prev[j - 1]) + 1
                }
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }

}

class CypriotKeyboardHelper {

    static func shouldReplace(text: String, greekText: String, guess: String) -> Bool {
        if text == greekText {
            // Pure-Greek input: only auto-replace when the difference is purely
            // diacritics, and only for words ≥2 syllables (single-syllable Greek
            // words conventionally don't carry accents).
            if countSyllables(text: text) < 2 { return false }
            let accentlessWord = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
            let accentlessGuess = guess.folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
            if guess != guess.lowercased() {
                return accentlessWord.lowercased() == accentlessGuess.lowercased()
                    && accentlessGuess != guess
                    && accentlessWord.lowercased() == text.lowercased()
            }
            return accentlessWord == accentlessGuess
                && accentlessGuess != guess
                && accentlessWord == text
        }
        // Greeklish input: bias toward auto-replace within Levenshtein distance.
        // Normalise σ ↔ ς before measuring: greekify outputs medial σ at
        // word-end, but canonicals use final ς. Without this, every short
        // Greeklish word with a single other-character mismatch pays a +1
        // distance tax that pushes legitimate corrections past the gate.
        let normalizedGreek = normalizeFinalSigma(
            greekText.lowercased().folding(options: .diacriticInsensitive,
                                           locale: Locale(identifier: "el_GR")))
        let normalizedGuess = normalizeFinalSigma(
            guess.lowercased().folding(options: .diacriticInsensitive,
                                       locale: Locale(identifier: "el_GR")))
        return Double(normalizedGreek.levenshtein(normalizedGuess)) < 3.0
    }

    /// Collapses final ς onto medial σ so the two are treated as equal
    /// during Levenshtein comparison. See `shouldReplace` for rationale.
    private static func normalizeFinalSigma(_ s: String) -> String {
        return s.replacingOccurrences(of: "ς", with: "σ")
    }

    static func shouldAttemptAutocomplete(text: String) -> Bool {
        // Skip autocomplete for tokens with no letters (numbers, bare punctuation).
        // Otherwise the Greeklish branch would happily replace "30" with things like "3η".
        return text.contains(where: { $0.isLetter })
    }

    static func countSyllables(text: String) -> Int {
        var count = 0
        let vowels = "αειυηοωaeiouy"
        var last: Character? = nil
        // Fold diacritics so accented vowels (ά έ ή ί ό ύ ώ) match the
        // unaccented vowel set.
        let folded = text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
        for letter in folded {
            let lastWasVowel = last.map { vowels.contains($0) } ?? false
            if vowels.contains(letter) && !lastWasVowel {
                count+=1
            }
            last = letter
        }
        return count
    }

    static func distanceMeasure(transliteratedWord: String, greekWord: String) -> Double {

        let a = greekWord.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
        let b = transliteratedWord.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "el_GR"))
        let levenshtein=a.levenshtein(b)
        return Double(levenshtein)
    }

    static func greekify(text: String) -> String {
        // Single-pass longest-match scanner. Replaces a chain of ~30
        // replacingOccurrences calls (each allocating a fresh String); now
        // walks the input once with switch-based dispatch over Characters.
        // Priority: 3-char digraphs > 2-char digraphs > single-char map.
        let chars = Array(text)
        var out = ""
        out.reserveCapacity(text.count * 2)
        var i = 0
        let n = chars.count
        while i < n {
            let c0 = chars[i]
            if i + 2 < n, let m = greekifyTrigraph(c0, chars[i + 1], chars[i + 2]) {
                out += m
                i += 3
                continue
            }
            if i + 1 < n, let m = greekifyDigraph(c0, chars[i + 1]) {
                out += m
                i += 2
                continue
            }
            if let m = greekifySingle(c0) {
                out += m
            } else {
                out.append(c0)
            }
            i += 1
        }
        return out
    }

    private static func greekifyTrigraph(_ a: Character, _ b: Character, _ c: Character) -> String? {
        switch (a, b, c) {
        case ("n", "g", "k"), ("N", "G", "K"): return "γκ"
        case ("t", "h", "s"): return "τησ"
        case ("T", "h", "s"), ("T", "H", "S"): return "Τησ"
        default: return nil
        }
    }

    private static func greekifyDigraph(_ a: Character, _ b: Character) -> String? {
        switch (a, b) {
        case ("s", "h"):                return "σ̆"
        case ("S", "h"), ("S", "H"):    return "Σ̆"
        case ("c", "h"):                return "τσ̆"
        case ("C", "h"), ("C", "H"):    return "Τσ̆"
        case ("p", "s"):                return "ψ"
        case ("P", "s"), ("P", "S"):    return "Ψ"
        case ("k", "s"):                return "ξ"
        case ("K", "s"), ("K", "S"):    return "Ξ"
        case ("T", "h"), ("T", "H"):    return "Θ"
        case ("t", "h"):                return "θ"
        case ("y", "i"):                return "γι"
        case ("Y", "i"), ("Y", "I"):    return "Γι"
        case ("n", "g"), ("N", "G"):    return "γκ"
        default: return nil
        }
    }

    private static func greekifySingle(_ c: Character) -> String? {
        switch c {
        case "a": return "α"; case "A": return "Α"
        case "i": return "ι"; case "I": return "Ι"
        case "e": return "ε"; case "E": return "Ε"
        case "o": return "ο"; case "O": return "Ο"
        case "u": return "υ"; case "U": return "Υ"
        case "y": return "υ"; case "Y": return "Υ"
        case "w": return "ω"; case "W": return "Ω"
        case "r": return "ρ"; case "R": return "Ρ"
        case "t": return "τ"; case "T": return "Τ"
        case "p": return "π"; case "P": return "Π"
        case "s": return "σ"; case "S": return "Σ"
        case "d": return "δ"; case "D": return "Δ"
        case "f": return "φ"; case "F": return "Φ"
        case "g": return "γ"; case "G": return "Γ"
        case "h": return "η"; case "H": return "Η"
        case "k": return "κ"; case "K": return "Κ"
        case "l": return "λ"; case "L": return "Λ"
        case "z": return "ζ"; case "Z": return "Ζ"
        case "x": return "χ"; case "X": return "Χ"
        case "c": return "κ"; case "C": return "Κ"
        case "v": return "β"; case "V": return "Β"
        case "b": return "μπ"; case "B": return "Μπ"
        case "n": return "ν"; case "N": return "Ν"
        case "m": return "μ"; case "M": return "Μ"
        case "j": return "τζ̆"; case "J": return "Τζ̆"
        case "3": return "ξ"
        default: return nil
        }
    }
    
    static func isCommonWord(word:String) -> Bool {
        return commonWords.contains(word.lowercased())
    }
    static let commonWords: Set<String> = ["άλλα",
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
