//
//  MilpaColor.swift
//  MilpaApp
//
//  Created by Alumno on 17/04/26.
//

import Foundation
import SwiftUI
enum MilpaColor {
    private static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xff) / 255.0,
                green: CGFloat((hex >> 8) & 0xff) / 255.0,
                blue: CGFloat(hex & 0xff) / 255.0,
                alpha: 1.0
            )
        })
    }

    static let cream   = dynamic(light: 0xF0EAD9, dark: 0x1A1915)
    static let cream2  = dynamic(light: 0xE8E0CD, dark: 0x22211D)
    static let paper   = dynamic(light: 0xFAF6EC, dark: 0x11110E)
    
    static let ink     = dynamic(light: 0x1F1D16, dark: 0xF0EAD9)
    static let ink2    = dynamic(light: 0x5B584B, dark: 0xA9A492)
    static let ink3    = dynamic(light: 0x8F8B7A, dark: 0x737063)

    static let green   = dynamic(light: 0x3F5B2E, dark: 0x4D7139)
    static let greenD  = dynamic(light: 0x2A3F1E, dark: 0x7CA461)
    static let greenBg = dynamic(light: 0xDCE3CA, dark: 0x1F2E17)

    static let ocre    = dynamic(light: 0xC68B3C, dark: 0xD89943)
    static let ocreD   = dynamic(light: 0x9A6820, dark: 0xE5AE5E)
    static let ocreBg  = dynamic(light: 0xF1DFBE, dark: 0x422F11)

    static let rust    = dynamic(light: 0xB45227, dark: 0xC95D2E)
    static let rustBg  = dynamic(light: 0xF2D6C2, dark: 0x4A2210)

    static let sky     = dynamic(light: 0x7A9A97, dark: 0x8CBDB9)
    static let skyBg   = dynamic(light: 0xD7E2DF, dark: 0x233735)

    static let corn    = dynamic(light: 0xE4B93B, dark: 0xEBC656)
}
enum MilpaFont {
    // Uses .system variants for full nativity and accessibility
    static func serif(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

