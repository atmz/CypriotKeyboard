import XCTest
@testable import Cypriot_Keyboard

class CypriotKeyboardUtilTests: XCTestCase {

    // MARK: - shouldReplace: σ/ς normalization

    /// Regression: `greekify` outputs medial σ at word-end (e.g. "sintagmatarxis"
    /// → "σινταγματαρχισ"), but canonical Greek words use final ς. Without
    /// normalization the σ/ς difference counts as +1 toward the Levenshtein
    /// gate, pushing legitimate two-edit corrections (ι↔υ, ι↔η in this case)
    /// past the `< 3` threshold.
    func testShouldReplaceNormalizesFinalSigmaInGreeklishBranch() {
        // greekify("sintagmatarxis") = "σινταγματαρχισ" — ends in medial σ (U+03C3).
        // Canonical "συνταγματάρχης" ends in final ς (U+03C2).
        // Diacritic-folded distance: ι→υ, ι→η, σ→ς = 3 (rejected today).
        // After σ↔ς normalization: ι→υ, ι→η = 2 (accepted).
        let text = "sintagmatarxis"
        let greekText = "\u{03C3}\u{03B9}\u{03BD}\u{03C4}\u{03B1}\u{03B3}\u{03BC}\u{03B1}\u{03C4}\u{03B1}\u{03C1}\u{03C7}\u{03B9}\u{03C3}"  // σινταγματαρχισ (medial σ at end)
        let guess = "συνταγματάρχης"
        XCTAssertTrue(
            CypriotKeyboardHelper.shouldReplace(text: text, greekText: greekText, guess: guess),
            "σ↔ς should not be counted as a Levenshtein edit; otherwise legitimate two-edit corrections get rejected"
        )
    }

    /// Sanity: a true distance-3 difference (after σ/ς normalization) still
    /// gets rejected, so we haven't flattened the gate entirely.
    func testShouldReplaceStillRejectsTrueDistanceThree() {
        // greek = "παφοσ" (5 chars, medial σ end). guess "ενοπάφος" (7 chars,
        // final ς) folds to "ενοπαφος". After σ↔ς normalization both end in
        // σ; distance is 3 insertions ("ενο" prefix). Should still reject.
        let text = "Pafos"
        let greekText = "\u{03A0}\u{03B1}\u{03C6}\u{03BF}\u{03C3}"  // Παφοσ
        let guess = "ενοπάφος"  // 3 insertions even after σ↔ς normalization
        XCTAssertFalse(
            CypriotKeyboardHelper.shouldReplace(text: text, greekText: greekText, guess: guess),
            "distance-3 (after normalization) should still be rejected"
        )
    }

    func testShouldReplaceUsesMinimumDistanceAcrossVariants() {
        // "afth" greekifies to αφθ. The αυτή candidate is distance 3 from
        // αφθ but distance 0 from the αυτη greekify-alternative. The gate
        // must use the minimum across alternatives, otherwise valid Greek
        // candidates get rejected for greekify-shortening cases (th → θ
        // where the user meant τη).
        XCTAssertTrue(
            CypriotKeyboardHelper.shouldReplace(
                text: "afth",
                greekVariants: ["αφθ", "αυτη"],
                guess: "αυτή"
            )
        )
    }
}
