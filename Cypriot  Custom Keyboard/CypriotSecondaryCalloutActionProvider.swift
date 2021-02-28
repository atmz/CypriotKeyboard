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
        if action.isσLower {
            actions.insert(.character("σ̆σ̆"), at: 3)
            actions.insert(.character("ς̆"), at: 4)
            return actions
        }
        if action.isιLower {
            actions.insert(.character("ι-"), at: 2)
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
        case "ζ": return "ζζ̆"
        case "ψ": return "ψψ̆"
        case "ξ": return "ξξ̌"
        case "σ": return "σςσ̆"
        case "α": return "αά"
        case "ο": return "οόὀὄ"
        case "ι" : return "ιί"
        
        default: return ""
        }
    }
}

private extension KeyboardAction {
    
    var isσLower: Bool {
        switch self {
        case .character(let char): return char == "σ"
        default: return false
        }
    }
    var isιLower: Bool {
        switch self {
        case .character(let char): return char == "ι"
        default: return false
        }
    }
}
