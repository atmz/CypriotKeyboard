package cy.cypriotkeyboard.app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
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
        startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }
}

@Composable
private fun Home(isImeEnabled: Boolean, onOpenSettings: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
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
            Button(onClick = onOpenSettings) { Text(stringResource(R.string.open_settings)) }
            Text(stringResource(R.string.install_step_2))
            Text(stringResource(R.string.install_step_3))
            Text(stringResource(R.string.install_step_4))
            Text(stringResource(R.string.install_step_5))
            Text(stringResource(R.string.install_step_6))
        }
    }
}
