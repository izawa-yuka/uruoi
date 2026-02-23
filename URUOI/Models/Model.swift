//
//  Model.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import Foundation
import SwiftData

// MARK: - ContainerMaster
/// ユーザーの水容器を管理するモデル
@Model
final class ContainerMaster {
    var id: UUID
    var name: String
    var emptyWeight: Double // g
    var isArchived: Bool // ソフトデリート用
    var createdAt: Date
    var sortOrder: Int // 並び順（小さい順に表示）
    
    // SwiftDataリレーションシップ: このコンテナに紐づくすべてのレコード
    // カスケード削除: コンテナ削除時に関連レコードも自動削除
    @Relationship(deleteRule: .cascade, inverse: \WaterRecord.container)
    var records: [WaterRecord]? = []
    
    init(id: UUID = UUID(), name: String, emptyWeight: Double, isArchived: Bool = false, createdAt: Date = Date(), sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.emptyWeight = emptyWeight
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
    
    // MARK: - バリデーション
    
    /// 器の名前が有効かどうかを検証
    func validateName() -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 20
    }
    
    /// 空重量が有効かどうかを検証
    func validateEmptyWeight() -> Bool {
        return emptyWeight >= 0 && emptyWeight <= 10000 // 0g〜10kg の範囲
    }
    
    /// すべてのフィールドが有効かどうかを検証
    func isValid() -> Bool {
        return validateName() && validateEmptyWeight()
    }
    
    /// バリデーションエラーメッセージを取得
    func validationErrors() -> [String] {
        var errors: [String] = []
        
        if !validateName() {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("器の名前を入力してください")
            } else if name.count > 20 {
                errors.append("器の名前は20文字以内で入力してください")
            }
        }
        
        if !validateEmptyWeight() {
            if emptyWeight < 0 {
                errors.append("空重量は0以上の値を入力してください")
            } else if emptyWeight > 10000 {
                errors.append("空重量は10000g以下の値を入力してください")
            }
        }
        
        return errors
    }
}

// MARK: - WaterRecord
/// 水の摂取セッションを記録するモデル
@Model
final class WaterRecord: Identifiable {
    var id: UUID
    var containerID: UUID // 後方互換性のため保持（マイグレーション時に有用）
    var startTime: Date
    var startWeight: Double // g
    var endTime: Date? // 終了時までnull
    var endWeight: Double? // 終了時までnull
    var catCount: Int // 記録時の猫の数
    var weatherCondition: String? // SF Symbol名: "sun.max", "cloud.rain"など
    var temperature: Double? // 摂氏温度
    var note: String? // メモ（50文字以内）
    var createdByDeviceID: String? // 記録を作成したデバイスのID（家族共有で使用）
    
    // SwiftDataリレーションシップ: このレコードが属するコンテナ
    var container: ContainerMaster?
    
    // 計算プロパティ: 摂取量（g）
    var amount: Double? {
        guard let endWeight = endWeight else { return nil }
        return startWeight - endWeight
    }
    
    // 計算プロパティ: 1匹あたりの摂取量（g）
    var perCatAmount: Double? {
        guard let amount = amount, catCount > 0 else { return nil }
        return amount / Double(catCount)
    }
    
    init(
        id: UUID = UUID(),
        containerID: UUID,
        startTime: Date,
        startWeight: Double,
        endTime: Date? = nil,
        endWeight: Double? = nil,
        catCount: Int,
        weatherCondition: String? = nil,
        temperature: Double? = nil,
        note: String? = nil,
        container: ContainerMaster? = nil,
        createdByDeviceID: String? = DeviceManager.currentDeviceID
    ) {
        self.id = id
        self.containerID = containerID
        self.startTime = startTime
        self.startWeight = startWeight
        self.endTime = endTime
        self.endWeight = endWeight
        self.catCount = catCount
        self.weatherCondition = weatherCondition
        self.temperature = temperature
        self.note = note
        self.container = container
        self.createdByDeviceID = createdByDeviceID
    }
    
    // MARK: - バリデーション
    
    /// 開始重量が有効かどうかを検証
    func validateStartWeight() -> Bool {
        return startWeight > 0 && startWeight <= 10000 // 0g超〜10kg
    }
    
    /// 終了重量が有効かどうかを検証（終了時のみ）
    func validateEndWeight() -> Bool {
        guard let endWeight = endWeight else { return true } // 未終了の場合は有効
        return endWeight >= 0 && endWeight < startWeight // 開始重量より少ない必要がある
    }
    
    /// 猫の数が有効かどうかを検証
    func validateCatCount() -> Bool {
        return catCount > 0 && catCount <= 99
    }
    
    /// 気温が有効かどうかを検証（オプショナル）
    func validateTemperature() -> Bool {
        guard let temperature = temperature else { return true } // 未入力は有効
        return temperature >= -50 && temperature <= 60 // -50℃〜60℃
    }
    
    /// メモが有効かどうかを検証（オプショナル）
    func validateNote() -> Bool {
        guard let note = note else { return true } // 未入力は有効
        return note.count <= 50
    }
    
    /// すべてのフィールドが有効かどうかを検証
    func isValid() -> Bool {
        return validateStartWeight() &&
               validateEndWeight() &&
               validateCatCount() &&
               validateTemperature() &&
               validateNote()
    }
    
    /// バリデーションエラーメッセージを取得
    func validationErrors() -> [String] {
        var errors: [String] = []
        
        if !validateStartWeight() {
            if startWeight <= 0 {
                errors.append("開始重量は0より大きい値を入力してください")
            } else if startWeight > 10000 {
                errors.append("開始重量は10000g以下の値を入力してください")
            }
        }
        
        if !validateEndWeight() {
            if let endWeight = endWeight {
                if endWeight < 0 {
                    errors.append("終了重量は0以上の値を入力してください")
                } else if endWeight >= startWeight {
                    errors.append("終了重量は開始重量より少ない値を入力してください")
                }
            }
        }
        
        if !validateCatCount() {
            if catCount <= 0 {
                errors.append("猫の数は1以上の値を入力してください")
            } else if catCount > 99 {
                errors.append("猫の数は99以下の値を入力してください")
            }
        }
        
        if !validateTemperature() {
            if let temperature = temperature {
                errors.append("気温は-50℃〜60℃の範囲で入力してください（現在: \(temperature)℃）")
            }
        }
        
        if !validateNote() {
            if let note = note {
                errors.append("メモは50文字以内で入力してください（現在: \(note.count)文字）")
            }
        }
        
        return errors
    }
}

