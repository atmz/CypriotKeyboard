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
        completion(.success(buildSuggestions(for: text)))
    }

    func asyncAutocompleteSuggestions(for text: String,
                                      isFirstWordInSentence: Bool,
                                      completion: @escaping AutocompleteResponse) {
        guard !text.isEmpty else { return completion(.success([])) }
        // Run on global queue mirroring the Hunspell provider's pattern.
        DispatchQueue.global().async {
            completion(.success(self.buildSuggestions(for: text)))
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

    private func buildSuggestions(for text: String) -> [CypriotAutocompleteSuggestion] {
        let greek = CypriotKeyboardHelper.greekify(text: text)

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

        // Multi-fold lookup: branch at digraph positions so e.g. `νοιμα`
        // probes both `νoıμα` (οι→ı) and `νoıμα` (ο→o, ι→ı), giving the
        // suggester a chance to find both `νήμα` and `νόημα`.
        let foldKeys = folder.foldVariants(lookupGreek)
        // Match the Hunspell provider's length-aware cap so the suggestion
        // bar stays readable: long inputs leave less room per slot, so we
        // show fewer alternatives. Total bar slots = verbatim + candidates.
        let candidateLimit = text.count > 5 ? 2 : 3
        let candidates = suggester.suggest(forKeys: foldKeys, limit: candidateLimit)

        func displayForm(_ canonical: String) -> String {
            switch casing {
            case .lowercase:
                return canonical
            case .firstLetterCap:
                guard let first = canonical.first else { return canonical }
                return String(first).uppercased() + canonical.dropFirst()
            case .allCaps:
                return canonical.uppercased()
            }
        }

        var result: [CypriotAutocompleteSuggestion] = []
        result.append(CypriotAutocompleteSuggestion(
            text: text, isAutocomplete: false, isUnknown: true,
            title: text, subtitle: nil,
            additionalInfo: [:]
        ))
        if let top = candidates.first {
            let displayed = displayForm(top.canonical)
            result.append(CypriotAutocompleteSuggestion(
                text: displayed, isAutocomplete: false, isUnknown: false,
                title: displayed, subtitle: nil,
                additionalInfo: ["willReplace": true]
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

private enum InputCasing {
    case lowercase
    case firstLetterCap
    case allCaps
}
