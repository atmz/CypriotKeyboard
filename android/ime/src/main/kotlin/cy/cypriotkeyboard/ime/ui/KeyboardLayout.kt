package cy.cypriotkeyboard.ime.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import cy.cypriotkeyboard.ime.layout.KeyAction
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.layout.LayoutSpec

private val KEY_HEIGHT = 46.dp
private val KEY_GAP = 4.dp
private val ROW_GAP = 6.dp
private val KEY_CORNER = 5.dp
private val POPUP_KEY_WIDTH = 44.dp
private val POPUP_KEY_HEIGHT = 50.dp
private val POPUP_PAD = 6.dp

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
                onLongPress = { onKeyLongPress(key) },
                onPopupPick = { ch ->
                    // Synthesise a Character key tap so the popup pick goes
                    // through the same commit + final-sigma + suggest pipeline.
                    onKeyTap(KeySpec(action = KeyAction.Character(ch), label = ch))
                }
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
    onLongPress: () -> Unit,
    onPopupPick: (String) -> Unit
) {
    val isFunction = key.action.isFunctionKey()
    val isSpace = key.action is KeyAction.Space
    val keyColor = when {
        isSpace -> MaterialTheme.colorScheme.surfaceContainerHigh
        isFunction -> MaterialTheme.colorScheme.surfaceContainerHigh
        else -> MaterialTheme.colorScheme.surface
    }
    val labelColor = MaterialTheme.colorScheme.onSurface
    val hasPopup = key.popupChars.size > 1
    var popupVisible by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .weight(weight)
            .fillMaxSize()
            .clip(RoundedCornerShape(KEY_CORNER))
            .background(keyColor)
            .pointerInput(key) {
                detectTapGestures(
                    onTap = { onTap() },
                    onLongPress = {
                        if (hasPopup) popupVisible = true else onLongPress()
                    }
                )
            },
        contentAlignment = Alignment.Center
    ) {
        // lineHeight headroom so combining marks render above the base letter.
        Text(
            text = key.label,
            color = labelColor,
            textAlign = TextAlign.Center,
            fontSize = if (isSpace) 13.sp else if (isFunction) 16.sp else 18.sp,
            lineHeight = if (isSpace) 18.sp else if (isFunction) 22.sp else 26.sp
        )

        if (popupVisible && hasPopup) {
            DiacriticPopup(
                chars = key.popupChars,
                onPick = { picked ->
                    popupVisible = false
                    onPopupPick(picked)
                },
                onDismiss = { popupVisible = false }
            )
        }
    }
}

@Composable
private fun DiacriticPopup(
    chars: List<String>,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit
) {
    // Anchor the popup directly above the key. Compose Popup positions itself
    // relative to the parent; we offset upward by approximately one popup-key
    // height + a small gap so the row of variants sits on top of the original.
    val verticalGapPx = with(androidx.compose.ui.platform.LocalDensity.current) {
        -(POPUP_KEY_HEIGHT + 6.dp).roundToPx()
    }
    Popup(
        alignment = Alignment.TopCenter,
        offset = IntOffset(0, verticalGapPx),
        onDismissRequest = onDismiss,
        properties = PopupProperties(focusable = true)
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(MaterialTheme.colorScheme.surface)
                .padding(POPUP_PAD)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                for (ch in chars) {
                    Box(
                        modifier = Modifier
                            .size(POPUP_KEY_WIDTH, POPUP_KEY_HEIGHT)
                            .clip(RoundedCornerShape(KEY_CORNER))
                            .background(MaterialTheme.colorScheme.surfaceContainer)
                            .pointerInput(ch) {
                                detectTapGestures(onTap = { onPick(ch) })
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = ch,
                            color = MaterialTheme.colorScheme.onSurface,
                            fontSize = 22.sp,
                            lineHeight = 32.sp,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        }
    }
}
