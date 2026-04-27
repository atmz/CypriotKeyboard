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
        // Normalise input: greekify Latin → Greek, then fold to a phonetic key.
        let greek = CypriotKeyboardHelper.greekify(text: text)

        // Capitalization handling, mirroring the Hunspell path:
        // The DAWG is built from lowercase forms, so lookups must be lowercase.
        // We detect a capitalized first letter, lowercase it before folding,
        // and recapitalize results before display.
        let isCapitalFirst: Bool
        let lookupGreek: String
        if let first = greek.first, first.isUppercase {
            isCapitalFirst = true
            lookupGreek = String(first).lowercased() + greek.dropFirst()
        } else {
            isCapitalFirst = false
            lookupGreek = greek
        }

        let foldKey = folder.fold(lookupGreek)

        let candidates = suggester.suggest(forKey: foldKey, limit: 4)

        func displayForm(_ canonical: String) -> String {
            if isCapitalFirst, let first = canonical.first {
                return String(first).uppercased() + canonical.dropFirst()
            }
            return canonical
        }

        var result: [CypriotAutocompleteSuggestion] = []
        // Slot 0: verbatim
        result.append(CypriotAutocompleteSuggestion(
            text: text, isAutocomplete: false, isUnknown: true,
            title: text, subtitle: nil,
            additionalInfo: [:]
        ))
        // Slot 1: top autocorrect candidate. Mark willReplace=true when the
        // candidate is at edit distance 0 OR 1 (i.e. a real phonetic match
        // we'd want to swap in on space).
        if let top = candidates.first {
            let displayed = displayForm(top.canonical)
            result.append(CypriotAutocompleteSuggestion(
                text: displayed, isAutocomplete: false, isUnknown: false,
                title: displayed, subtitle: nil,
                additionalInfo: ["willReplace": true]
            ))
        }
        // Slot 2+: additional candidates (no willReplace)
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
