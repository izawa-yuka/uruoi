//
//  Color+Extensions.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import SwiftUI

extension Color {
    /// 16進数カラーコードからColorを生成
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - App Brand Colors
    
    /// アプリのメインカラー（ブランドカラー）
    static let appMain = Color(hex: "156EBA")
    
    /// 後方互換性のためのエイリアス
    static let mainAppColor = appMain
    
    /// アラート・警告カラー（オレンジ）
    static let alertOrange = Color(hex: "FF9F43")
    
    /// アラート背景カラー（薄いオレンジ）
    static let alertBackground = Color(hex: "FFF5EC")
    
    /// 背景カラー（グレー）
    static let backgroundGray = Color(hex: "F4F6F9")
    
    /// 非活性ボタン背景カラー
    static let disabledButtonBackground = Color(hex: "ECECEC")
}

