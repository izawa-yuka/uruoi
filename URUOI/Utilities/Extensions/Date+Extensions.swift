//
//  Date+Extensions.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import Foundation

// MARK: - DateFormatter共通定義
extension DateFormatter {
    /// 日本語の日付フォーマッター（yyyy/MM/dd）
    static let japaneseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()
    
    /// 日本語の時刻フォーマッター（HH:mm）
    static let japaneseTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()
    
    /// 日本語の短い日付フォーマッター（M/d）
    static let japaneseShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()
}

// MARK: - Date便利メソッド
extension Date {
    /// 日本語形式の日付文字列に変換（yyyy/MM/dd）
    func toJapaneseDate() -> String {
        DateFormatter.japaneseDate.string(from: self)
    }
    
    /// 日本語形式の時刻文字列に変換（HH:mm）
    func toJapaneseTime() -> String {
        DateFormatter.japaneseTime.string(from: self)
    }
    
    /// 日本語形式の短い日付文字列に変換（M/d）
    func toJapaneseShortDate() -> String {
        DateFormatter.japaneseShortDate.string(from: self)
    }
}

