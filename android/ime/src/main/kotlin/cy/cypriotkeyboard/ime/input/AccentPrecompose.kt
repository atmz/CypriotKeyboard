package cy.cypriotkeyboard.ime.input

/**
 * Prefix dead-key accents the user "arms" by tapping the accent key BEFORE
 * the vowel. The next vowel composes with the armed mark into a single
 * precomposed Unicode character (e.g. tonos + α → ά, U+03AC). This is the
 * Windows/Android Greek-typing convention, in contrast to the iOS post-fix
 * style (vowel first, accent second, two-codepoint cluster α + U+0301).
 *
 * Kouppouia (breve, ˘) stays POST-FIX: the user types the consonant first,
 * then breve. That direction is unchanged from iOS because the breve sits
 * on consonants that have no precomposed Unicode forms anyway, and Cypriots
 * already type it that way on every other Cypriot keyboard.
 */
enum class PrefixAccent { TONOS, DIALYTIKA, TONOS_DIALYTIKA }

/**
 * Resolve a prefix accent + base character to its precomposed form, or
 * null if the combination has no Unicode precomposed character (e.g.
 * tonos on a consonant — the IME caller should fall back to committing
 * the base char unchanged).
 */
fun precomposeAccent(accent: PrefixAccent, base: String): String? = when (accent) {
    PrefixAccent.TONOS -> TONOS_MAP[base]
    PrefixAccent.DIALYTIKA -> DIALYTIKA_MAP[base]
    PrefixAccent.TONOS_DIALYTIKA -> TONOS_DIALYTIKA_MAP[base]
}

private val TONOS_MAP = mapOf(
    // Lowercase vowels
    "α" to "ά",  // U+03AC
    "ε" to "έ",  // U+03AD
    "η" to "ή",  // U+03AE
    "ι" to "ί",  // U+03AF
    "ο" to "ό",  // U+03CC
    "υ" to "ύ",  // U+03CD
    "ω" to "ώ",  // U+03CE
    // Uppercase vowels
    "Α" to "Ά",  // U+0386
    "Ε" to "Έ",  // U+0388
    "Η" to "Ή",  // U+0389
    "Ι" to "Ί",  // U+038A
    "Ο" to "Ό",  // U+038C
    "Υ" to "Ύ",  // U+038E
    "Ω" to "Ώ",  // U+038F
    // Already-dialytika vowels combined with tonos
    "ϊ" to "ΐ",  // U+0390
    "ϋ" to "ΰ",  // U+03B0
)

private val DIALYTIKA_MAP = mapOf(
    "ι" to "ϊ",  // U+03CA
    "υ" to "ϋ",  // U+03CB
    "Ι" to "Ϊ",  // U+03AA
    "Υ" to "Ϋ",  // U+03AB
    // Already-tonos vowels combined with dialytika
    "ί" to "ΐ",  // U+0390
    "ύ" to "ΰ",  // U+03B0
)

private val TONOS_DIALYTIKA_MAP = mapOf(
    "ι" to "ΐ",  // U+0390
    "υ" to "ΰ",  // U+03B0
)
