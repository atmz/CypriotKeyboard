package cy.cypriotkeyboard.ime.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.layout.LayoutSpec
import cy.cypriotkeyboard.ime.suggest.Suggestion

data class KeyboardUiState(
    val layout: LayoutSpec,
    val suggestions: List<Suggestion>
)

@Composable
fun KeyboardView(
    state: State<KeyboardUiState>,
    onSuggestionPick: (Suggestion) -> Unit,
    onKeyTap: (KeySpec) -> Unit,
    onKeyLongPress: (KeySpec) -> Unit
) {
    val s by state
    Surface(
        // Slightly tinted tray background. Letter keys sit on top of this with
        // a marginally lighter fill, matching Gboard's "keys-on-tray" look.
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        modifier = Modifier.fillMaxWidth()
    ) {
        // Since targetSdk 35 the IME window is edge-to-edge: the framework no
        // longer keeps the keyboard above the system navigation bar, so the
        // bottom row would sit under the 3-button nav bar (and its
        // collapse-keyboard button). Pad by the nav-bar inset here, inside the
        // Surface, so the tray color also fills the strip behind the bar.
        // Reports 0 on devices where the framework still pads (pre-15).
        Column(modifier = Modifier.fillMaxWidth().navigationBarsPadding()) {
            SuggestionBar(suggestions = s.suggestions, onPick = onSuggestionPick)
            KeyboardLayoutView(
                spec = s.layout,
                onKeyTap = onKeyTap,
                onKeyLongPress = onKeyLongPress
            )
        }
    }
}
