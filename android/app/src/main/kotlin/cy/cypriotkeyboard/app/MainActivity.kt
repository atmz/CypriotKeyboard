package cy.cypriotkeyboard.app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Home(
                        isImeEnabled = isOurImeEnabled(),
                        onOpenSettings = { openImeSettings() }
                    )
                }
            }
        }
    }

    private fun isOurImeEnabled(): Boolean {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        val ourPackage = packageName
        return imm.enabledInputMethodList.any { it.packageName == ourPackage }
    }

    private fun openImeSettings() {
        // ACTION_INPUT_METHOD_SETTINGS deep-links straight to the on-screen
        // keyboard list — the user just toggles "Cypriot Keyboard" there.
        startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }
}

@Composable
private fun Home(isImeEnabled: Boolean, onOpenSettings: () -> Unit) {
    Column(
        // safeDrawing keeps content out of status bar, navigation bar, and
        // display cutouts (camera notch / hole-punch).
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = 24.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = stringResource(R.string.app_title),
            style = MaterialTheme.typography.headlineMedium
        )
        if (isImeEnabled) {
            Text(stringResource(R.string.usage_globe))
            Text(stringResource(R.string.usage_swap))
            Text(stringResource(R.string.usage_suggestions))
            var typed by remember { mutableStateOf("") }
            TextField(
                value = typed,
                onValueChange = { typed = it },
                label = { Text(stringResource(R.string.test_here_hint)) }
            )
            Text(stringResource(R.string.credits), style = MaterialTheme.typography.bodySmall)
        } else {
            Text(stringResource(R.string.install_intro))
            Button(onClick = onOpenSettings) {
                Text(stringResource(R.string.open_settings))
            }
            Text(
                stringResource(R.string.install_then),
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}
