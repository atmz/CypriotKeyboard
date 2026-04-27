package cy.cypriotkeyboard.ime

import android.inputmethodservice.InputMethodService
import android.view.View
import android.widget.FrameLayout

/**
 * IME service entry point. Stub for Task 2 — fully wired in Task 19.
 * See spec docs/superpowers/specs/2026-04-27-android-port-design.md.
 */
class CypriotInputMethodService : InputMethodService() {

    override fun onCreateInputView(): View {
        return FrameLayout(this)
    }
}
