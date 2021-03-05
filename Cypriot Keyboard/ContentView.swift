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
    @State private var showInstall = !isKeyboardExtensionEnabled()
    @State private var showGreek = true

    var body: some View {
        VStack {
            Text("🇨🇾 Κύπριακο Keyboard")
                .padding()
                .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/)
            Button(NSLocalizedString("Installation", comment: "Installation")){showInstall=true}
            Spacer(minLength: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/)
            Button(NSLocalizedString("Use", comment: "Use")){showInstall=false}
            Spacer(minLength: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/)
            }
        .padding()
        if(showInstall) {
            Text(NSLocalizedString("1. Open 'Settings'", comment: "1. Open 'Settings'")).padding()
            Text(NSLocalizedString("2. Tap 'General'", comment: "2. Tap 'General'")).padding()
            Text(NSLocalizedString("3. Tap Keyboard", comment: "3. Tap Keyboard")).padding()
            Text(NSLocalizedString("4. Tap Keyboards", comment: "4. Tap Keyboards")).padding()
            Text(NSLocalizedString("5. Tap Add New Keyboard", comment: "5. Tap Add New Keyboard")).padding()
            Text(NSLocalizedString( "6. Tap 'Κυπριακά'", comment: "6. Tap 'Κυπριακά'"))
        } else {
            Text(NSLocalizedString("Click 🌐 to switch keyboard to the Cypriot Keyboard", comment: "Click 🌐 to switch keyboard to the Cypriot Keyboard")).multilineTextAlignment(.leading).padding(.top)
            Text(NSLocalizedString("Click 🔄 to switch between Latin and Greek alphabets", comment: "Click 🔄 to switch between Latin and Greek alphabets")).multilineTextAlignment(.leading).padding([.top, .leading, .trailing])
            Text(NSLocalizedString( "The bar above the keyboard shows the current suggestions. When you pless 'Space', the middle suggestion will be used", comment: "The bar above the keyboard shows the current suggestions. When you pless 'Space', the middle suggestion will be used")).multilineTextAlignment(.leading).padding([.top, .leading, .trailing])
        }
            TextField(NSLocalizedString("Test Here", comment: "Test Here"), text: $textTyped).padding([ .leading])
            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
