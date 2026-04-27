package cy.cypriotkeyboard.ime.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
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
        color = MaterialTheme.colorScheme.background,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            SuggestionBar(suggestions = s.suggestions, onPick = onSuggestionPick)
            KeyboardLayoutView(
                spec = s.layout,
                onKeyTap = onKeyTap,
                onKeyLongPress = onKeyLongPress
            )
        }
    }
}
