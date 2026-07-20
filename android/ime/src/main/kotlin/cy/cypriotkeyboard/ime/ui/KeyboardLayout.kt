package cy.cypriotkeyboard.ime.ui

import android.view.HapticFeedbackConstants
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
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
private val POPUP_GAP = 6.dp

/**
 * Active diacritic-popup state, hoisted to the keyboard root so the popup
 * can render as an in-tree overlay (not a separate Compose `Popup` window —
 * those steal IME focus and dismiss the keyboard).
 *
 * [anchor] is the long-pressed key's bounds expressed in the same coordinate
 * system as the popup overlay, i.e. relative to the outer Box of
 * KeyboardLayoutView.
 */
private data class ActivePopup(
    val chars: List<String>,
    val anchor: Rect
)

@Composable
fun KeyboardLayoutView(
    spec: LayoutSpec,
    onKeyTap: (KeySpec) -> Unit,
    onKeyLongPress: (KeySpec) -> Unit
) {
    var activePopup by remember { mutableStateOf<ActivePopup?>(null) }
    // The outer Box's position in window-root coordinates. Used to translate
    // each key's positionInRoot() into outer-Box-local coordinates so the
    // popup overlay can be placed via Modifier.offset relative to the Box.
    var rootCoords by remember { mutableStateOf<LayoutCoordinates?>(null) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .onGloballyPositioned { rootCoords = it }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(ROW_GAP)
        ) {
            for (row in spec.rows) {
                KeyRow(
                    keys = row,
                    onKeyTap = { k ->
                        // A normal tap dismisses any open popup first.
                        activePopup = null
                        onKeyTap(k)
                    },
                    onKeyLongPress = onKeyLongPress,
                    onPopupRequested = { chars, keyCoords ->
                        val root = rootCoords
                        if (root != null) {
                            // Translate the key's bounds into outer-Box-local coords.
                            val keyTopLeft = root.localPositionOf(keyCoords, Offset.Zero)
                            val anchor = Rect(
                                offset = keyTopLeft,
                                size = androidx.compose.ui.geometry.Size(
                                    keyCoords.size.width.toFloat(),
                                    keyCoords.size.height.toFloat()
                                )
                            )
                            activePopup = ActivePopup(chars, anchor)
                        }
                    }
                )
            }
        }

        // When a popup is open, lay a tap-eating scrim over the keys so taps
        // outside the popup dismiss it without firing key actions.
        val popup = activePopup
        if (popup != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .zIndex(1f)
                    .pointerInput(popup) {
                        detectTapGestures(onTap = { activePopup = null })
                    }
            )
            DiacriticOverlay(
                popup = popup,
                onPick = { picked ->
                    activePopup = null
                    // Synthesise a Character key tap so the popup pick goes
                    // through the same commit + final-sigma + suggest pipeline.
                    onKeyTap(KeySpec(action = KeyAction.Character(picked), label = picked))
                }
            )
        }
    }
}

@Composable
private fun KeyRow(
    keys: List<KeySpec>,
    onKeyTap: (KeySpec) -> Unit,
    onKeyLongPress: (KeySpec) -> Unit,
    onPopupRequested: (List<String>, LayoutCoordinates) -> Unit
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
                onPopupRequested = onPopupRequested
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
    onPopupRequested: (List<String>, LayoutCoordinates) -> Unit
) {
    val isFunction = key.action.isFunctionKey()
    val isSpace = key.action is KeyAction.Space
    val isEnabled = key.enabled
    val keyColor = when {
        // Armed prefix dead-key (tonos/dialytika waiting for its vowel).
        key.highlighted -> MaterialTheme.colorScheme.primaryContainer
        isSpace -> MaterialTheme.colorScheme.surfaceContainerHigh
        isFunction -> MaterialTheme.colorScheme.surfaceContainerHigh
        else -> MaterialTheme.colorScheme.surface
    }
    val labelColor = if (key.highlighted) MaterialTheme.colorScheme.onPrimaryContainer
        else if (isEnabled) MaterialTheme.colorScheme.onSurface
        // Greek-context disabled state for the breve key when the previous
        // letter doesn't take a breve. ~38% alpha matches Material's standard
        // disabled-control opacity.
        else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
    val hasPopup = key.popupChars.size > 1

    var keyCoords by remember { mutableStateOf<LayoutCoordinates?>(null) }
    val view = LocalView.current

    val tapModifier = if (isEnabled) {
        Modifier.pointerInput(key) {
            detectTapGestures(
                onTap = {
                    // System haptic feedback on every key tap. Respects the
                    // user's "haptic feedback" toggle (Settings → Sound),
                    // requires no permission, and matches the Gboard cadence.
                    view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                    onTap()
                },
                onLongPress = {
                    view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                    if (hasPopup) {
                        keyCoords?.let { onPopupRequested(key.popupChars, it) }
                    } else {
                        onLongPress()
                    }
                }
            )
        }
    } else {
        // No pointerInput → taps and long-presses are silently ignored.
        Modifier
    }

    Box(
        modifier = Modifier
            .weight(weight)
            .fillMaxSize()
            .clip(RoundedCornerShape(KEY_CORNER))
            .background(keyColor)
            .onGloballyPositioned { keyCoords = it }
            .then(tapModifier),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = key.label,
            color = labelColor,
            textAlign = TextAlign.Center,
            fontSize = if (isSpace) 13.sp else if (isFunction) 16.sp else 18.sp,
            lineHeight = if (isSpace) 18.sp else if (isFunction) 22.sp else 26.sp
        )
    }
}

@Composable
private fun DiacriticOverlay(
    popup: ActivePopup,
    onPick: (String) -> Unit
) {
    val density = LocalDensity.current
    val view = LocalView.current
    val popupKeyWidthPx = with(density) { POPUP_KEY_WIDTH.toPx() }
    val popupKeyHeightPx = with(density) { POPUP_KEY_HEIGHT.toPx() }
    val gapPx = with(density) { POPUP_GAP.toPx() }
    val padPx = with(density) { POPUP_PAD.toPx() }
    val betweenPx = with(density) { 4.dp.toPx() }

    val n = popup.chars.size
    val totalWidthPx = padPx * 2 + n * popupKeyWidthPx +
        (n - 1).coerceAtLeast(0) * betweenPx
    val totalHeightPx = popupKeyHeightPx + padPx * 2

    // Center the popup over the anchor key, then clamp into the keyboard width.
    val anchorCenterX = popup.anchor.left + popup.anchor.width / 2f
    val leftPx = (anchorCenterX - totalWidthPx / 2f).coerceAtLeast(0f)
    val topPx = (popup.anchor.top - totalHeightPx - gapPx).coerceAtLeast(0f)

    Box(
        modifier = Modifier
            .offset(
                x = with(density) { leftPx.toDp() },
                y = with(density) { topPx.toDp() }
            )
            .zIndex(2f)
            .clip(RoundedCornerShape(8.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(POPUP_PAD)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            for (ch in popup.chars) {
                Box(
                    modifier = Modifier
                        .size(POPUP_KEY_WIDTH, POPUP_KEY_HEIGHT)
                        .clip(RoundedCornerShape(KEY_CORNER))
                        .background(MaterialTheme.colorScheme.surfaceContainer)
                        .pointerInput(ch) {
                            detectTapGestures(onTap = {
                                view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                                onPick(ch)
                            })
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
