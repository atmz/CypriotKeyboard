//
//  KeyboardInputSet+Alphabetic.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2020-07-04.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//

import Foundation
import KeyboardKit
/**
 This file contains various alphabetic input sets.
 */
public extension KeyboardInputSet {
    
    static var alphabetic_gr: AlphabeticKeyboardInputSet {
        AlphabeticKeyboardInputSet(inputRows: [
            ["ε","ρ","τ","υ","θ","ι","ο","π","΄"],
            ["α","σ","δ","φ","γ","η","ξ","κ","λ"],
            ["ζ","χ","ψ","ω","β","ν","μ"]
        ])
    }
}
