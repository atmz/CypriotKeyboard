package cy.cypriotkeyboard.ime.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import cy.cypriotkeyboard.ime.suggest.Suggestion

private val BAR_HEIGHT = 50.dp

@Composable
fun SuggestionBar(
    suggestions: List<Suggestion>,
    onPick: (Suggestion) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(BAR_HEIGHT)
            .padding(horizontal = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (s in suggestions) {
            SuggestionSlot(s, onPick = { onPick(s) }, modifier = Modifier
                .weight(1f)
                .fillMaxSize())
        }
    }
}

@Composable
private fun SuggestionSlot(
    s: Suggestion,
    onPick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val bg = if (s.willReplace)
        MaterialTheme.colorScheme.surfaceVariant
    else
        Color.Transparent
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(5.dp))
            .background(bg)
            .clickable(onClick = onPick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = s.text,
            color = Color.Black,
            style = MaterialTheme.typography.bodyMedium
        )
    }
}
