//
//  ContentView.swift
//  Cypriot Keyboard
//
//  Created by Alex Toumazis on 2/4/21.
//

import SwiftUI

struct ContentView: View {
    @State var textTyped: String = ""
    @State private var showInstall = false
    @State private var showGreek = true

    var body: some View {
        VStack {
            Text("🇨🇾 Κύπριακο Keyboard")
                .padding()
                .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
            if(showGreek){
                Text("Tap 🔄 below to switch to English")
                    .padding()
            } else {
                Text("Πατήστε 🔄 για Κυπριακά")
                    .padding()
            }
            Button("🔄"){showGreek.toggle()}
                .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                .padding()
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/)
            Button(showGreek ? "Εφάρμογη":"Installation"){showInstall=true}
            Spacer(minLength: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/)
            Button(showGreek ? "Χρήση":"Use"){showInstall=false}
            Spacer(minLength: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/)
            }
        .padding()
        if(showInstall) {
            Text(showGreek ? "1. Άνοιξε 'Ρυθμίσεις'" : "1. Open 'Settings'")
            Text(showGreek ? "2. Πάτα 'Γενικά'" : "2. Tap 'General'")
            Text(showGreek ? "3. Πάτα 'Πληκτρολόγιο'" : "3. Tap Keyboard")
            Text(showGreek ? "4.  Πάτα 'Πληκτρολόγια'" : "4. Tap Keyboards")
            Text(showGreek ? "5. Πάτα 'Προσθήκη νέου πληκτρολογίου'" : "5. Tap Add New Keyboard")
            Text(showGreek ? "6. Διάλεξε 'Κυπριακό Keyboard'" : "6. Tap 'Κυπριακό Keyboard'")
        } else {
            Text(showGreek ? "Πάτα 🌐 για να αλλάξεις γλώσσα/πληκτρολόγιο" : "Click 🌐 to switch keyboard to the Cypriot Keyboard").multilineTextAlignment(.leading).padding(.top)
            Text(showGreek ? "Πάτα 🔄 για να αλλάξεις μεταξή Ελληνηκό και Λατιωικό αλφάβητο" : "Click 🔄 to switch between Latin and Greek alphabets").multilineTextAlignment(.leading).padding([.top, .leading, .trailing])
            Text(showGreek ? "Η περιοχή πουπάνω που το πληκτρολόγιο δείχνει προτεινόμενες λέξεις. Όταν πατήσεις Σπαις η μεσαία λεξη διαλέγεται" : "The bar above the keyboard shows the current suggestions. When you pless 'Space', the middle suggestion will be used").multilineTextAlignment(.leading).padding([.top, .leading, .trailing])
        }
            TextField(showGreek ? "Δοκιμάστε δαμέ" : "Test Here", text: $textTyped)
            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
