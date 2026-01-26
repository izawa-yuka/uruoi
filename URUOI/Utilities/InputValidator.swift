//
//  InputValidator.swift
//  URUOI
//
//  Created by USER on 2026/01/03.
//

import Foundation

/// 入力値のバリデーションを行うユーティリティ
struct InputValidator {
    
    // MARK: - 器の名前のバリデーション
    
    /// 器の名前が有効かどうかを検証
    /// - Parameter name: 検証する名前
    /// - Returns: 有効な場合はtrue
    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空文字チェック
        guard !trimmed.isEmpty else { return false }
        
        // 長さチェック（1〜20文字）
        guard trimmed.count >= 1 && trimmed.count <= 20 else { return false }
        
        // 制御文字のチェック
        guard trimmed.rangeOfCharacter(from: .controlCharacters) == nil else { return false }
        
        return true
    }
    
    /// 器の名前を検証し、エラーメッセージを返す
    /// - Parameter name: 検証する名前
    /// - Returns: エラーメッセージ（有効な場合はnil）
    static func validateName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "器の名前を入力してください"
        }
        
        if trimmed.count > 20 {
            return "器の名前は20文字以内にしてください"
        }
        
        if trimmed.rangeOfCharacter(from: .controlCharacters) != nil {
            return "使用できない文字が含まれています"
        }
        
        return nil
    }
    
    // MARK: - 重量のバリデーション
    
    /// 重量（グラム）が有効かどうかを検証
    /// - Parameter weight: 検証する重量（g）
    /// - Returns: 有効な場合はtrue
    static func isValidWeight(_ weight: Double) -> Bool {
        // 0以上、50kg（50000g）以下
        return weight >= 0 && weight <= 50000
    }
    
    /// 重量を検証し、エラーメッセージを返す
    /// - Parameter weight: 検証する重量（g）
    /// - Returns: エラーメッセージ（有効な場合はnil）
    static func validateWeight(_ weight: Double) -> String? {
        if weight < 0 {
            return "重量は0以上の値を入力してください"
        }
        
        if weight > 50000 {
            return "重量は50kg（50000g）以下で入力してください"
        }
        
        return nil
    }
    
    // MARK: - 水分量のバリデーション
    
    /// 水分量（ml）が有効かどうかを検証
    /// - Parameter amount: 検証する水分量（ml）
    /// - Returns: 有効な場合はtrue
    static func isValidAmount(_ amount: Int) -> Bool {
        // 1ml以上、3000ml以下
        return amount >= 1 && amount <= 3000
    }
    
    /// 水分量を検証し、エラーメッセージを返す
    /// - Parameter amount: 検証する水分量（ml）
    /// - Returns: エラーメッセージ（有効な場合はnil）
    static func validateAmount(_ amount: Int) -> String? {
        if amount < 1 {
            return "水分量は1ml以上で入力してください"
        }
        
        if amount > 3000 {
            return "水分量は3000ml以下で入力してください"
        }
        
        return nil
    }
    
    // MARK: - 摂取量の整合性チェック
    
    /// 開始重量と終了重量の整合性を検証
    /// - Parameters:
    ///   - startWeight: 開始時の重量（g）
    ///   - endWeight: 終了時の重量（g）
    /// - Returns: エラーメッセージ（有効な場合はnil）
    static func validateWaterConsumption(startWeight: Double, endWeight: Double) -> String? {
        if startWeight <= endWeight {
            return "開始時の重量は終了時より大きい必要があります"
        }
        
        let amount = startWeight - endWeight
        
        if amount > 10000 {
            return "摂取量が異常に大きいです（10L以上）"
        }
        
        return nil
    }
    
    // MARK: - 猫の数のバリデーション
    
    /// 猫の数が有効かどうかを検証
    /// - Parameter count: 検証する猫の数
    /// - Returns: 有効な場合はtrue
    static func isValidCatCount(_ count: Int) -> Bool {
        return count >= 1 && count <= 50
    }
    
    /// 猫の数を検証し、エラーメッセージを返す
    /// - Parameter count: 検証する猫の数
    /// - Returns: エラーメッセージ（有効な場合はnil）
    static func validateCatCount(_ count: Int) -> String? {
        if count < 1 {
            return "猫の数は1匹以上にしてください"
        }
        
        if count > 50 {
            return "猫の数は50匹以下で入力してください"
        }
        
        return nil
    }
    
    // MARK: - 温度のバリデーション
    
    /// 温度が有効かどうかを検証
    /// - Parameter temperature: 検証する温度（℃）
    /// - Returns: 有効な場合はtrue
    static func isValidTemperature(_ temperature: Double) -> Bool {
        return temperature >= -50 && temperature <= 70
    }
    
    /// 温度を検証し、エラーメッセージを返す
    /// - Parameter temperature: 検証する温度（℃）
    /// - Returns: エラーメッセージ（有効な場合はnil）
    static func validateTemperature(_ temperature: Double) -> String? {
        if temperature < -50 || temperature > 70 {
            return "温度は-50℃〜70℃の範囲で入力してください"
        }
        
        return nil
    }
}






