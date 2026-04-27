//
//  ContentView.swift
//  Cypriot Keyboard
//
//  Created by Alex Toumazis on 2/4/21.
//

import SwiftUI

func isKeyboardExtensionEnabled() -> Bool {
 guard let appBundleIdentifier = Bundle.main.bundleIdentifier else {
     fatalError("isKeyboardExtensionEnabled(): Cannot retrieve bundle identifier.")
 }

 guard let keyboards = UserDefaults.standard.dictionaryRepresentation()["AppleKeyboards"] as? [String] else {
     // There is no key `AppleKeyboards` in NSUserDefaults. That happens sometimes.
     return false
 }
/* https://stackoverflow.com/questions/51896904/ios-how-to-detect-keyboard-change-event
    
     func prepareForKeyboardChangeNotification() {
         NotificationCenter.default.addObserver(self, selector: #selector(changeInputMode), name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
     }

     @objc
     func changeInputMode(notification: NSNotification) {
         let inputMethod = txtInput.textInputMode?.primaryLanguage
         //perform your logic here

     }
 
 */
 let keyboardExtensionBundleIdentifierPrefix = appBundleIdentifier + "."
 for keyboard in keyboards {
     if keyboard.hasPrefix(keyboardExtensionBundleIdentifierPrefix) {
         return true
     }
 }
    return false
}
    
struct ContentView: View {
    @State var textTyped: String = ""
    @State private var showInstall =  !isKeyboardExtensionEnabled()

    var body: some View {
        VStack {
            Text("🇨🇾 Κύπριακο Keyboard")
                .padding()
                .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
            

        if(showInstall) {
            
            Button(NSLocalizedString("1. Open 'Settings'", comment: "1. Open 'Settings'")){
                //App-prefs:root=General&path=Keyboard/KEYBOARDS
                
                let url = URL(string: "App-prefs:root=General&path=Keyboard/KEYBOARDS")!

                // From inside a `UIViewController` method...
                UIApplication.shared.open(url, options: [:]) { (success: Bool) in
                   // ... handle the result
                }
            }
            Text(NSLocalizedString("2. Tap 'General'", comment: "2. Tap 'General'")).padding(.top)
            Text(NSLocalizedString("3. Tap Keyboard", comment: "3. Tap Keyboard")).padding(.top)
            Text(NSLocalizedString("4. Tap Keyboards", comment: "4. Tap Keyboards")).padding(.top)
            Text(NSLocalizedString("5. Tap Add New Keyboard", comment: "5. Tap Add New Keyboard")).padding(.top)
            Text(NSLocalizedString( "6. Tap 'Κυπριακά'", comment: "6. Tap 'Κυπριακά'")).padding(.top)
            Spacer()
        } else {
            Text(NSLocalizedString("Click 🌐 to switch keyboard to the Cypriot Keyboard", comment: "Click 🌐 to switch keyboard to the Cypriot Keyboard")).multilineTextAlignment(.leading).padding()
            Text(NSLocalizedString("Click 🔄 to switch between Latin and Greek alphabets", comment: "Click 🔄 to switch between Latin and Greek alphabets")).multilineTextAlignment(.leading).padding()
            Text(NSLocalizedString( "The bar above the keyboard shows the current suggestions. When you pless 'Space', the middle suggestion will be used", comment: "The bar above the keyboard shows the current suggestions. When you pless 'Space', the middle suggestion will be used")).multilineTextAlignment(.leading).padding()
            TextField(NSLocalizedString("Test Here", comment: "Test Here"), text: $textTyped).padding([ .leading])
            Spacer()
            Text(NSLocalizedString("Alex", comment: "Alex")).font(.footnote).multilineTextAlignment(.leading).padding([.top, .leading, .trailing])
            Text(NSLocalizedString("Credits", comment: "Credits")).font(.footnote).multilineTextAlignment(.leading).padding([.top, .leading, .trailing])
        }
            #if DEBUG
            Divider().padding(.top)
            DAWGSuggesterDebugToggle()
            #endif
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#if DEBUG
private struct DAWGSuggesterDebugToggle: View {
    @State private var useDAWG: Bool = UserDefaults.standard.bool(forKey: "useDAWGSuggester")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBUG").font(.caption).foregroundColor(.secondary)
            Toggle("Use DAWG suggester (experimental)", isOn: $useDAWG)
                .onChange(of: useDAWG) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "useDAWGSuggester")
                }
            Text("Toggling here only updates the container app's UserDefaults. Long-press the 🔄 key inside the keyboard for live-swap.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
#endif
