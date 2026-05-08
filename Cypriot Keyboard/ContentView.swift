import SwiftUI

func isKeyboardExtensionEnabled() -> Bool {
    guard let appBundleIdentifier = Bundle.main.bundleIdentifier else {
        return false
    }
    guard let keyboards = UserDefaults.standard.dictionaryRepresentation()["AppleKeyboards"] as? [String] else {
        return false
    }
    let prefix = appBundleIdentifier + "."
    return keyboards.contains { $0.hasPrefix(prefix) }
}

struct ContentView: View {
    var body: some View {
        OnboardingShell()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
