package cy.cypriotkeyboard.ime.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.layout.LayoutSpec

private val KEY_HEIGHT = 50.dp
private val KEY_GAP = 4.dp
private val ROW_GAP = 6.dp

@Composable
fun KeyboardLayoutView(
    spec: LayoutSpec,
    onKeyTap: (KeySpec) -> Unit,
    onKeyLongPress: (KeySpec) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(ROW_GAP)
    ) {
        for (row in spec.rows) {
            KeyRow(row, onKeyTap, onKeyLongPress)
        }
    }
}

@Composable
private fun KeyRow(
    keys: List<KeySpec>,
    onKeyTap: (KeySpec) -> Unit,
    onKeyLongPress: (KeySpec) -> Unit
) {
    val totalUnits = keys.sumOf { it.widthUnits.toDouble() }.toFloat()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(KEY_HEIGHT),
        horizontalArrangement = Arrangement.spacedBy(KEY_GAP)
    ) {
        for (key in keys) {
            KeyButton(
                key = key,
                weight = key.widthUnits / totalUnits,
                onTap = { onKeyTap(key) },
                onLongPress = { onKeyLongPress(key) }
            )
        }
    }
}

@Composable
private fun RowScope.KeyButton(
    key: KeySpec,
    weight: Float,
    onTap: () -> Unit,
    onLongPress: () -> Unit
) {
    val bg = MaterialTheme.colorScheme.surfaceVariant
    Box(
        modifier = Modifier
            .weight(weight)
            .fillMaxSize()
            .clip(RoundedCornerShape(6.dp))
            .background(bg)
            .clickable(onClick = onTap)
            // long-press hookup; Compose has detectTapGestures for this if
            // a richer popup UI is needed later. For v1 the click-only path
            // covers all cases except secondary-callout popups (see notes).
            ,
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = key.label,
            color = Color.Black,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.titleMedium
        )
    }
}
