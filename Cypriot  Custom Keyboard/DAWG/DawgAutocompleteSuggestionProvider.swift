//
//  DawgAutocompleteSuggestionProvider.swift
//  Cypriot  Custom Keyboard
//
//  KeyboardKit-facing autocomplete provider backed by the DAWG.
//  Mirrors the contract of CypriotAutocompleteSuggestionProvider:
//    slot 0: verbatim user input (isUnknown=true)
//    slot 1: top autocorrect candidate (willReplace=true if phonetic match)
//    slot 2+: extra suggestions
//

import Foundation
import KeyboardKit


final class DawgAutocompleteSuggestionProvider: AutocompleteSuggestionProvider {

    var locale: Locale = Locale(identifier: "el_GR")
    var canIgnoreWords: Bool = false
    var ignoredWords: [String] = []
    var canLearnWords: Bool = false

    private let reader: DawgReader
    private let folder: PhoneticFolder
    private let suggester: DamerauLevenshteinSuggester

    init(reader: DawgReader, folder: PhoneticFolder) {
        self.reader = reader
        self.folder = folder
        self.suggester = DamerauLevenshteinSuggester(reader: reader)
    }

    /// Synchronous variant — used by tests.
    func autocompleteSuggestions(for text: String,
                                 completion: (AutocompleteResult) -> Void) {
        guard !text.isEmpty else { return completion(.success([])) }
        completion(.success(buildSuggestions(for: text, isFirstWordInSentence: false)))
    }

    func asyncAutocompleteSuggestions(for text: String,
                                      isFirstWordInSentence: Bool,
                                      completion: @escaping AutocompleteResponse) {
        guard !text.isEmpty else { return completion(.success([])) }
        // Run on global queue mirroring the Hunspell provider's pattern.
        DispatchQueue.global().async {
            completion(.success(self.buildSuggestions(for: text,
                                                     isFirstWordInSentence: isFirstWordInSentence)))
        }
    }

    // MARK: - Stub conformance to the AutocompleteSuggestionProvider protocol.

    func hasIgnoredWord(_ word: String) -> Bool { false }
    func ignoreWord(_ word: String) {}
    func removeIgnoredWord(_ word: String) {}
    func hasLearnedWord(_ word: String) -> Bool { false }
    func learnWord(_ word: String) {}
    func unlearnWord(_ word: String) {}

    // MARK: - Suggestion construction

    private func buildSuggestions(for text: String,
                                  isFirstWordInSentence: Bool) -> [CypriotAutocompleteSuggestion] {
        // isFirstWordInSentence is preserved on the call path for parity with
        // the Hunspell provider's contract, even though the DAWG always
        // lowercases for lookup (the engine has only lowercase canonicals,
        // so case-sensitive lookup isn't an option). The signal is wired
        // through so future ranking/gating can use it.
        _ = isFirstWordInSentence

        // Skip purely-numeric / punctuation tokens — otherwise typing "8"
        // greekifies to nothing useful and the suggester returns Greek
        // letters that fold to the empty key (η, ο, …) as edit-1 neighbors.
        // Mirrors the Hunspell provider's identical guard.
        guard CypriotKeyboardHelper.shouldAttemptAutocomplete(text: text) else { return [] }

        // Strip a leading non-letter (".", "(", etc.) before greekify so e.g.
        // ".kalimera" looks up "kalimera" and the punct gets re-prepended on
        // the way out. Matches the Hunspell provider's isPunctFirst handling.
        let isPunctFirst = !(text.first?.isLetter ?? true)
        let textForGreekify = isPunctFirst ? String(text.dropFirst()) : text
        let greek = CypriotKeyboardHelper.greekify(text: textForGreekify)

        // Common-word fast path: if the input is pure-Greek (greekify is a
        // no-op) and a known common word, return verbatim only — no
        // autocorrect alternatives. Mirrors the Hunspell provider's
        // identical short-circuit so users aren't pestered with candidates
        // for words they typed correctly.
        if !isPunctFirst,
           text == greek,
           CypriotKeyboardHelper.isCommonWord(word: text) {
            return [CypriotAutocompleteSuggestion(
                text: text, isAutocomplete: false, isUnknown: true,
                title: text, subtitle: nil,
                additionalInfo: [:]
            )]
        }

        // Capitalization handling, mirroring the Hunspell path:
        // The DAWG is built from lowercase forms, so lookups must be lowercase.
        // We detect input casing, lowercase before folding, recapitalize results
        // to match the user's input style.
        let casing: InputCasing
        let lookupGreek: String
        if greek.isEmpty {
            casing = .lowercase
            lookupGreek = greek
        } else if greek == greek.uppercased() && greek != greek.lowercased() {
            // Entire input is uppercase (and has at least one cased letter).
            casing = .allCaps
            lookupGreek = greek.lowercased()
        } else if greek.first!.isUppercase {
            casing = .firstLetterCap
            lookupGreek = String(greek.first!).lowercased() + greek.dropFirst()
        } else {
            casing = .lowercase
            lookupGreek = greek
        }

        // Greekify alternatives: Greeklish "th" is mapped greedily to θ,
        // but the user might have meant τη (e.g. "afth" → αυτή, not αυθ).
        // Branch at each θ in the greekified form when the input was
        // Greeklish, so the lookup considers both interpretations. Pure
        // Greek input means the user typed the spelling they wanted, so
        // we don't second-guess.
        let isGreeklish = textForGreekify != greek
        let greekVariants: [String] = isGreeklish
            ? Self.greekifyAlternatives(lookupGreek)
            : [lookupGreek]

        // Multi-fold lookup: branch at digraph positions so e.g. `νοιμα`
        // probes both `νoıμα` (οι→ı) and `νoıμα` (ο→o, ι→ı), giving the
        // suggester a chance to find both `νήμα` and `νόημα`.
        var seenFoldKeys = Set<String>()
        var foldKeys: [String] = []
        for variant in greekVariants {
            for key in folder.foldVariants(variant) {
                if seenFoldKeys.insert(key).inserted {
                    foldKeys.append(key)
                }
            }
        }
        // Match the Hunspell provider's length-aware cap so the suggestion
        // bar stays readable: long inputs leave less room per slot, so we
        // show fewer alternatives. Total bar slots = verbatim + candidates.
        let candidateLimit = text.count > 5 ? 2 : 3
        let candidates = suggester.suggest(forKeys: foldKeys, limit: candidateLimit)

        func displayForm(_ canonical: String) -> String {
            let cased: String
            switch casing {
            case .lowercase:
                cased = canonical
            case .firstLetterCap:
                if let first = canonical.first {
                    cased = String(first).uppercased() + canonical.dropFirst()
                } else {
                    cased = canonical
                }
            case .allCaps:
                cased = canonical.uppercased()
            }
            // Re-prepend the leading punct stripped for lookup so the
            // suggestion appears with the same surface form the user typed.
            return isPunctFirst ? String(text.first!) + cased : cased
        }

        var result: [CypriotAutocompleteSuggestion] = []
        result.append(CypriotAutocompleteSuggestion(
            text: text, isAutocomplete: false, isUnknown: true,
            title: text, subtitle: nil,
            additionalInfo: [:]
        ))
        if let top = candidates.first {
            let displayed = displayForm(top.canonical)
            // Gate willReplace through shouldReplace so spacebar only
            // replaces the typed word when the candidate is a close
            // diacritics-only or low-Levenshtein match. Mirrors the
            // Hunspell provider's identical gate; without it, every
            // edit-1 candidate would force-replace the user's input.
            //
            // Multi-variant gating: pass every greekify alternative so
            // greekify-shortening cases (th → θ where the user meant τη,
            // e.g. "afth" → αυτή) aren't rejected by the distance check
            // against just the first interpretation. Variants are rooted
            // at `greek` (case-preserving, post-strip) so the pure-Greek
            // diacritic-only path still matches uppercase Greek input.
            let gateVariants: [String] = isGreeklish
                ? Self.greekifyAlternatives(greek)
                : [greek]
            let willReplace = CypriotKeyboardHelper.shouldReplace(
                text: text, greekVariants: gateVariants, guess: displayed
            )
            result.append(CypriotAutocompleteSuggestion(
                text: displayed, isAutocomplete: false, isUnknown: false,
                title: displayed, subtitle: nil,
                additionalInfo: willReplace ? ["willReplace": true] : [:]
            ))
        }
        for cand in candidates.dropFirst() {
            let displayed = displayForm(cand.canonical)
            result.append(CypriotAutocompleteSuggestion(
                text: displayed, isAutocomplete: false, isUnknown: false,
                title: displayed, subtitle: nil,
                additionalInfo: [:]
            ))
        }
        return result
    }
}

extension DawgAutocompleteSuggestionProvider {
    /// Rules for branching ambiguous Greeklish transliterations into multiple
    /// Greek interpretations. Sorted longest-first so digraphs win over
    /// single-char rules.
    ///
    /// - αφ/εφ/αβ/εβ ⇄ αυ/ευ: Greek's αυ/ευ diphthong sounds like "af/ef"
    ///   before voiceless consonants and "av/ev" before voiced — but
    ///   greekify maps the consonant char-by-char (φ/β), so we branch back
    ///   to the diphthong here. Without this, "Lefkosia" → Λεφκοσια only
    ///   reaches Λευκωσία at edit-2, outside the suggester's edit-1 budget.
    /// - θ ⇄ τη: Greeklish "th" maps greedily to θ but might mean τη
    ///   (e.g. "afth" → αυτή).
    private static let altRules: [(src: String, alts: [String])] = [
        ("αφ", ["αφ", "αυ"]),
        ("Αφ", ["Αφ", "Αυ"]),
        ("εφ", ["εφ", "ευ"]),
        ("Εφ", ["Εφ", "Ευ"]),
        ("αβ", ["αβ", "αυ"]),
        ("Αβ", ["Αβ", "Αυ"]),
        ("εβ", ["εβ", "ευ"]),
        ("Εβ", ["Εβ", "Ευ"]),
        ("θ", ["θ", "τη"]),
        ("Θ", ["Θ", "Τη"]),
    ]

    /// Generate alternative Greek interpretations for ambiguous Greeklish
    /// transliterations. Returns at least the input itself; capped at
    /// `maxVariants` to keep combinatorial explosion in check when many
    /// branchable positions appear in one word.
    static func greekifyAlternatives(_ greek: String, maxVariants: Int = 8) -> [String] {
        let chars = Array(greek)
        var out: [String] = []
        var seen = Set<String>()

        func helper(_ i: Int, _ acc: String) {
            if out.count >= maxVariants { return }
            if i >= chars.count {
                if seen.insert(acc).inserted { out.append(acc) }
                return
            }
            for (src, alts) in altRules {
                let srcChars = Array(src)
                if i + srcChars.count > chars.count { continue }
                var match = true
                for k in 0..<srcChars.count where chars[i + k] != srcChars[k] {
                    match = false
                    break
                }
                if match {
                    for alt in alts {
                        helper(i + srcChars.count, acc + alt)
                    }
                    return
                }
            }
            helper(i + 1, acc + String(chars[i]))
        }
        helper(0, "")
        return out
    }
}

private enum InputCasing {
    case lowercase
    case firstLetterCap
    case allCaps
}
