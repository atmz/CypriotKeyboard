package cy.cypriotkeyboard.ime

import android.content.Context
import android.content.SharedPreferences
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.inputmethod.InputConnection
import android.view.inputmethod.InputMethodManager
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import cy.cypriotkeyboard.ime.BuildConfig
import cy.cypriotkeyboard.ime.input.ActionHandler
import cy.cypriotkeyboard.ime.input.KeyboardController
import cy.cypriotkeyboard.ime.input.KeyboardMode
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.layout.LayoutSpec
import cy.cypriotkeyboard.ime.layout.Layouts
import cy.cypriotkeyboard.ime.layout.shifted
import cy.cypriotkeyboard.ime.suggest.DawgReader
import cy.cypriotkeyboard.ime.suggest.PhoneticFolder
import cy.cypriotkeyboard.ime.suggest.Suggestion
import cy.cypriotkeyboard.ime.suggest.SuggestionEngine
import cy.cypriotkeyboard.ime.ui.KeyboardUiState
import cy.cypriotkeyboard.ime.ui.KeyboardView
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class CypriotInputMethodService :
    InputMethodService(),
    LifecycleOwner,
    ViewModelStoreOwner,
    SavedStateRegistryOwner,
    KeyboardController {

    // ---- Lifecycle plumbing for Compose-in-IME -------------------------

    private val lifecycleRegistry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle get() = lifecycleRegistry

    private val store = ViewModelStore()
    override val viewModelStore: ViewModelStore get() = store

    private val savedStateRegistryController = SavedStateRegistryController.create(this)
    override val savedStateRegistry get() = savedStateRegistryController.savedStateRegistry

    // ---- IME state -----------------------------------------------------

    private lateinit var prefs: SharedPreferences
    private val mainHandler = Handler(Looper.getMainLooper())
    private val workerExec = Executors.newSingleThreadExecutor { r ->
        Thread(r, "cypriot-suggest").apply { isDaemon = true }
    }

    @Volatile private var engine: SuggestionEngine? = null
    private val uiState = mutableStateOf(
        KeyboardUiState(layout = Layouts.greekAlphabetic(), suggestions = emptyList())
    )
    private val handler = ActionHandler(this)
    private val autocompleteToken = AtomicInteger(0)
    private var pendingAutocomplete: Runnable? = null

    private var mode: KeyboardMode = KeyboardMode.ALPHABETIC
    private var isLatin: Boolean = false
    /**
     * Single-shift state. When true, the next Character commit produces an
     * uppercase letter; the action handler clears this flag via [consumeShift]
     * after the commit. Caps-lock not implemented for v1.
     */
    private var shiftActive: Boolean = false

    // ---- Service lifecycle --------------------------------------------

    override fun onCreate() {
        savedStateRegistryController.performAttach()
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        super.onCreate()
        prefs = getSharedPreferences("cypriot_keyboard", Context.MODE_PRIVATE)
        isLatin = prefs.getBoolean(KEY_IS_LATIN, false)
        recomputeLayout()
        loadEngineAsync()
    }

    override fun onCreateInputView(): View {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)

        val composeView = ComposeView(this)
        composeView.setContent {
            KeyboardView(
                state = uiState,
                onSuggestionPick = { s -> applySuggestion(s) },
                onKeyTap = { k -> handler.handle(k) },
                onKeyLongPress = { k -> handleLongPress(k) }
            )
        }

        // Compose's WindowRecomposer queries the lifecycle owner via
        // findViewTreeLifecycleOwner() starting from the window's *root* view
        // (which `InputMethodService.setInputView` wraps around our ComposeView
        // — a LinearLayout with id `parentPanel`). Setting the owners only on
        // the ComposeView crashes because the search starts above it.
        // Install owners on the decor view so the upward walk finds them.
        val decor = window.window?.decorView
        decor?.setViewTreeLifecycleOwner(this)
        decor?.setViewTreeViewModelStoreOwner(this)
        decor?.setViewTreeSavedStateRegistryOwner(this)

        return composeView
    }

    override fun onStartInputView(info: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        // Make sure the host sees el_CY as the active subtype so spell-check
        // and autocorrect-on-host don't treat our Greek output as English.
        applyGreekSubtype()
    }

    override fun onDestroy() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        store.clear()
        workerExec.shutdownNow()
        super.onDestroy()
    }

    // ---- KeyboardController -------------------------------------------

    override fun ic(): InputConnection? = currentInputConnection

    override fun toggleLayoutGreekLatin() {
        isLatin = !isLatin
        prefs.edit().putBoolean(KEY_IS_LATIN, isLatin).apply()
        recomputeLayout()
        // No subtype change here: the OUTPUT is always Cypriot Greek,
        // regardless of input layout. The Latin row is just a Greeklish
        // input method whose committed text is Greek after autocorrect.
    }

    /**
     * Tell the IME framework that we're outputting Greek (`el_CY`). Apps
     * like Chrome read this to pick a spell-check dictionary; without it,
     * Greek words get red-underlined as if they were misspelled English.
     *
     * We always report el_CY — even when the user is on the Latin/Greeklish
     * input row — because the committed text is Greek either way. The
     * en_US subtype declared in xml/method.xml is kept only so the system
     * keyboard picker knows we accept ASCII input.
     */
    private fun applyGreekSubtype() {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager ?: return
        val ourImi = imm.enabledInputMethodList.firstOrNull { it.packageName == packageName } ?: return
        var match: android.view.inputmethod.InputMethodSubtype? = null
        for (i in 0 until ourImi.subtypeCount) {
            val s = ourImi.getSubtypeAt(i)
            @Suppress("DEPRECATION")
            if (s.locale == "el_CY") {
                match = s
                break
            }
        }
        val target = match ?: return
        val token = window.window?.attributes?.token ?: return
        @Suppress("DEPRECATION")
        imm.setInputMethodAndSubtype(token, ourImi.id, target)
    }

    override fun switchToNextIme() {
        // Switch to whichever IME the system thinks comes next. The argument
        // false means "don't restrict to ASCII-capable IMEs".
        val token = window.window?.attributes?.token
        val imm = getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager ?: return
        if (token != null) {
            @Suppress("DEPRECATION")
            imm.switchToNextInputMethod(token, false)
        }
    }

    override fun setMode(mode: KeyboardMode) {
        this.mode = mode
        recomputeLayout()
    }

    override fun toggleShift() {
        shiftActive = !shiftActive
        recomputeLayout()
    }

    override fun consumeShift() {
        if (shiftActive) {
            shiftActive = false
            recomputeLayout()
        }
    }

    override fun refreshLayout() = recomputeLayout()

    override fun requestSuggestions(currentWord: String) {
        // Refresh the layout each keystroke so the breve/tonos accent key swap
        // tracks the previous letter (mirrors iOS alphabeticInputSet).
        recomputeLayout()

        val token = autocompleteToken.incrementAndGet()
        // Cancel any in-flight debounce window.
        pendingAutocomplete?.let { mainHandler.removeCallbacks(it) }
        pendingAutocomplete = null

        // No current word → clear suggestions immediately, no work to schedule.
        if (currentWord.isEmpty()) {
            uiState.value = uiState.value.copy(suggestions = emptyList())
            handler.currentGuess = null
            return
        }
        val r = Runnable {
            val eng = engine ?: return@Runnable
            workerExec.submit {
                val out = try { eng.suggest(currentWord) } catch (t: Throwable) { emptyList() }
                // Race-guard: only post the result back if no newer request has
                // arrived. The check is INSIDE mainHandler.post so it's the very
                // last thing before we mutate UI state — closes the gap between
                // "worker decided to publish" and "main thread updates state".
                mainHandler.post {
                    if (autocompleteToken.get() != token) return@post
                    uiState.value = uiState.value.copy(suggestions = out)
                    handler.currentGuess = out.firstOrNull { it.willReplace }
                    if (BuildConfig.DEBUG) {
                        for (s in out) {
                            val cps = s.text.codePoints().toArray()
                                .joinToString(" ") { "U+%04X".format(it) }
                            Log.d("CypriotIME", "suggest='${s.text}' cps=$cps willReplace=${s.willReplace}")
                        }
                    }
                }
            }
        }
        pendingAutocomplete = r
        mainHandler.postDelayed(r, AUTOCOMPLETE_DEBOUNCE_MS)
    }

    // ---- Helpers -------------------------------------------------------

    private fun recomputeLayout() {
        val base: LayoutSpec = when (mode) {
            KeyboardMode.NUMERIC -> Layouts.numeric()
            KeyboardMode.SYMBOLIC -> Layouts.symbolic()
            KeyboardMode.ALPHABETIC -> {
                if (isLatin) Layouts.latinAlphabetic()
                else Layouts.greekAlphabetic(
                    breveEnabled = previousLetterTakesBreve(),
                    pendingAccent = handler.pendingAccent
                )
            }
        }
        val layout = if (shiftActive) base.shifted() else base
        uiState.value = uiState.value.copy(layout = layout)
    }

    /**
     * iOS shows the breve accent (˘) instead of tonos (΄) on the top row when
     * the previous letter is one of σ ζ ξ ψ ς. Mirror that here by peeking
     * the most recent character before the cursor.
     */
    private fun previousLetterTakesBreve(): Boolean {
        val ic = currentInputConnection ?: return false
        val before = ic.getTextBeforeCursor(1, 0)?.toString() ?: return false
        if (before.isEmpty()) return false
        val ch = before[before.length - 1].lowercaseChar()
        return ch == 'σ' || ch == 'ζ' || ch == 'ξ' || ch == 'ψ' || ch == 'ς'
    }

    private fun applySuggestion(s: Suggestion) {
        val ic = ic() ?: return
        // Replace the current word with the picked suggestion + a space.
        val before = ic.getTextBeforeCursor(64, 0)?.toString() ?: ""
        val word = Regex("[\\p{L}\\p{M}]+$").find(before)?.value ?: ""
        if (word.isNotEmpty()) ic.deleteSurroundingText(word.length, 0)
        ic.commitText(s.text, 1)
        ic.commitText(" ", 1)
        handler.currentGuess = null
        uiState.value = uiState.value.copy(suggestions = emptyList())
    }

    private fun handleLongPress(spec: KeySpec) {
        // v1: long-press is a no-op (popup secondary callout deferred).
        // The 🔄 long-press toggled suggester engine on iOS but Android has
        // only one engine — this is a no-op deliberately.
    }

    private fun loadEngineAsync() {
        workerExec.submit {
            try {
                val dawgBytes = assets.open("el_CY.dawg").use { it.readBytes() }
                val foldJson = assets.open("phonetic_fold.json").use {
                    it.readBytes().toString(Charsets.UTF_8)
                }
                val buf = ByteBuffer.wrap(dawgBytes).order(ByteOrder.LITTLE_ENDIAN)
                val reader = DawgReader.from(buf)
                val folder = PhoneticFolder.fromJson(foldJson)
                engine = SuggestionEngine(reader, folder)
            } catch (e: IOException) {
                // No engine — keyboard still types, just no suggestions.
                engine = null
            } catch (e: Throwable) {
                engine = null
            }
        }
    }

    companion object {
        private const val KEY_IS_LATIN = "isLatinKeyboard"
        private const val AUTOCOMPLETE_DEBOUNCE_MS = 40L
    }
}
