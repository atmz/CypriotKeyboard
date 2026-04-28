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
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cy.cypriotkeyboard.ime.layout.KeyAction
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.layout.LayoutSpec

private val KEY_HEIGHT = 52.dp
private val KEY_GAP = 5.dp
private val ROW_GAP = 8.dp
private val KEY_CORNER = 8.dp

@Composable
fun KeyboardLayoutView(
    spec: LayoutSpec,
    onKeyTap: (KeySpec) -> Unit,
    onKeyLongPress: (KeySpec) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 6.dp),
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

private fun KeyAction.isFunctionKey(): Boolean = when (this) {
    is KeyAction.Character -> false
    KeyAction.Space -> false
    else -> true
}

@Composable
private fun RowScope.KeyButton(
    key: KeySpec,
    weight: Float,
    onTap: () -> Unit,
    onLongPress: () -> Unit
) {
    val isFunction = key.action.isFunctionKey()
    val isSpace = key.action is KeyAction.Space
    val keyColor = when {
        isSpace -> MaterialTheme.colorScheme.surface
        isFunction -> MaterialTheme.colorScheme.surfaceContainerHighest
        else -> MaterialTheme.colorScheme.surface
    }
    val labelColor = MaterialTheme.colorScheme.onSurface
    Surface(
        modifier = Modifier
            .weight(weight)
            .fillMaxSize(),
        color = keyColor,
        shape = RoundedCornerShape(KEY_CORNER),
        tonalElevation = if (isFunction) 0.dp else 1.dp,
        shadowElevation = 1.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(keyColor)
                .clickable(onClick = onTap),
            // long-press is intentionally not wired in v1; popupChars data
            // is preserved on KeySpec for a future popup composable.
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = key.label,
                color = labelColor,
                textAlign = TextAlign.Center,
                fontSize = if (isSpace) 14.sp else if (isFunction) 18.sp else 22.sp
            )
        }
    }
}
