//
//  KeyboardView.swift
//  KeyboardKitDemo
//
//  Created by Daniel Saidi on 2020-06-10.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//

import SwiftUI
import KeyboardKit
import UIKit

/**
 This view is the main view that is used by the extension by
 calling `setup(with:)` in `KeyboardViewController`.
 
 The view will switch over the current keyboard type and add
 the correct keyboard view.
 */
struct KeyboardView: View {
    
    var actionHandler: CypriotKeyboardActionHandler
    var appearance: KeyboardAppearance
    var layoutProvider: KeyboardLayoutProvider
    
    @EnvironmentObject var autocompleteContext: AutocompleteContext
    @EnvironmentObject var keyboardContext: KeyboardContext
    @EnvironmentObject var toastContext: KeyboardToastContext
    
    var body: some View {
        keyboardView.keyboardToast(
            context: toastContext,
            background: toastBackground)
    }
    
    @ViewBuilder
    var keyboardView: some View {
        switch keyboardContext.keyboardType {
        case .alphabetic, .numeric, .symbolic: systemKeyboard
        default: Button("???", action: switchToDefaultKeyboard)
        }
    }
}


// MARK: - Private Views

private extension KeyboardView {
    
    var autocompleteBar: some View {
        AutocompleteToolbar(
            suggestions: autocompleteContext.suggestions,
            buttonBuilder: autocompleteBarButtonBuilder)
            .frame(height: 50)
    }
    
    func autocompleteBarButton(for suggestion: AutocompleteSuggestion) -> AnyView {
        let shouldHighlight = suggestion.additionalInfo.keys.contains("willReplace")
        if shouldHighlight {
            let highlightColor = Color(UIColor.systemGray3)
            return AnyView(VStack(spacing: 0) {
                Text(suggestion.title).font(.callout)
            }.frame(maxWidth: .infinity, maxHeight: 42) .background(RoundedRectangle(cornerRadius: 5.0).fill(highlightColor)))
        } else {
            return AutocompleteToolbar.standardButton(for: suggestion)
        }
      /*
         guard let subtitle = suggestion.subtitle else { return AutocompleteToolbar.standardButton(for: suggestion) }
         return AnyView(VStack(spacing: 0) {
            Text(suggestion.title).font(.callout)
            Text(subtitle).font(.footnote)
        }.frame(maxWidth: .infinity))*/
    }
    
    func autocompleteBarButtonBuilder(suggestion: AutocompleteSuggestion) -> AnyView {
        AnyView(autocompleteBarButton(for: suggestion)
                    .background(Color.clearInteractable))
    }
    
    var systemKeyboard: some View {
        VStack(spacing: 0) {
            autocompleteBar
            SystemKeyboard(
                layout: layoutProvider.keyboardLayout(for: keyboardContext),
                appearance: appearance,
                actionHandler: actionHandler,
                buttonBuilder: buttonBuilder)
        }
    }
    
    var toastBackground: some View {
        Color.white
            .cornerRadius(3)
            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 1, y: 1)
    }
}


// MARK: - Private Functions

private extension KeyboardView {
    
    func buttonBuilder(action: KeyboardAction) -> AnyView {
        switch action {
        case .space: return AnyView(SystemKeyboardSpaceButtonContent(localeText: "English", spaceText: "space"))
        default: return SystemKeyboard.standardButtonBuilder(action: action)
        }
    }
    
    func changeLocale(to locale: LocaleKey) {
        DispatchQueue.main.async {
            KeyboardInputViewController.shared.changeKeyboardLocale(to: locale.locale)
        }
    }
    
    func localeButton(title: String, locale: LocaleKey) -> some View {
        Button(title) {
            changeLocale(to: locale)
        }
    }
    
    func switchToDefaultKeyboard() {
        actionHandler
            .handle(.tap, on: .keyboardType(.alphabetic(.lowercased)))
    }
}
