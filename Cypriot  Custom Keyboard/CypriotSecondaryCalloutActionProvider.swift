//
//  SwedishSecondaryCalloutActionProvider.swift
//  KeyboardKitPro
//
//  Created by Daniel Saidi on 2021-02-01.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//
import KeyboardKit

/**
 This class provides Swedish secondary callout actions.
 */
public class CypriotSecondaryCalloutActionProvider: BaseSecondaryCalloutActionProvider, LocalizedService {
    
    public let localeKey: String = "el_GR"
    
    public override func secondaryCalloutActions(for action: KeyboardAction) -> [KeyboardAction] {
        var actions = super.secondaryCalloutActions(for: action)
        if action.isΣ {
            actions.insert(.character("σ̌σ̌"), at: 2)
            return actions
        }
        return actions
    }
    
    public override func secondaryCalloutActionString(for char: String) -> String {
        switch char {
        case "-": return "-–—•"
        case "/": return "/\\"
        case "&": return "&§"
        case "”": return "\"”“„»«"
        case ".": return ".…"
        case "?": return "?¿"
        case "!": return "!¡"
        case "'", "’": return "'’‘`"
            
        case "%": return "%‰"
        case "=": return "=≠≈"
        case "ζ": return "ζζ̌"
        case "ψ": return "ψψ̌"
        case "ξ": return "ξξ̌"
        case "σ": return "σςσ̌"
        case "α": return "αά"
        
        default: return ""
        }
    }
}

private extension KeyboardAction {
    
    var isΣ: Bool {
        switch self {
        case .character(let char): return char == "σ"
        default: return false
        }
    }
}
