//
//  SettingsViewModel.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import Foundation
import SwiftData

@Observable
final class SettingsViewModel {
    var modelContext: ModelContext?
    var lastError: String?
    var showError: Bool = false
    
    // MARK: - Sync Helpers
    private func getHouseholdID() -> String? {
        return UserDefaults.standard.string(forKey: "householdID")
    }
    
    func addContainer(name: String, emptyWeight: Double, modelContext: ModelContext) {
        let newContainer = ContainerMaster(name: name, emptyWeight: emptyWeight)
        modelContext.insert(newContainer)
        try? modelContext.save()
        
        // Sync
        if let householdID = getHouseholdID(), !householdID.isEmpty {
            DataSyncService.shared.saveContainer(newContainer, householdID: householdID)
        }
    }
    
    func deleteContainer(_ container: ContainerMaster, modelContext: ModelContext) {
        container.isArchived = true
        try? modelContext.save()
        
        // Sync (Update)
        if let householdID = getHouseholdID(), !householdID.isEmpty {
            DataSyncService.shared.saveContainer(container, householdID: householdID)
        }
    }
    
    func hardDeleteContainer(_ container: ContainerMaster, modelContext: ModelContext) {
        let containerID = container.id // 削除前にID確保
        modelContext.delete(container)
        try? modelContext.save()
        
        // Sync (Delete)
        if let householdID = getHouseholdID(), !householdID.isEmpty {
            DataSyncService.shared.deleteContainer(id: containerID, householdID: householdID)
        }
    }
    
    private func setError(_ message: String, error: Error? = nil) {
        self.lastError = message
        self.showError = true
    }
    
    func clearError() {
        self.lastError = nil
        self.showError = false
    }
    
    // MARK: - デバッグ機能
    
    /// 過去14日間のダミーデータを生成
    func generateDummyData(modelContext: ModelContext) {
        // 1. 器の確保（既存の器を取得、なければ作成）
        let fetchDescriptor = FetchDescriptor<ContainerMaster>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        let containers = (try? modelContext.fetch(fetchDescriptor)) ?? []
        let container: ContainerMaster
        
        if let existingContainer = containers.first {
            container = existingContainer
        } else {
            // 器が存在しない場合は新規作成
            container = ContainerMaster(name: "デバッグ用器", emptyWeight: 200.0)
            modelContext.insert(container)
        }
        
        // 2. 現在の猫の頭数を取得
        let catCount = AppSettings.shared.numberOfPets
        
        // 3. 過去14日間のダミーデータを生成
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<14 {
            // 各日の基準日付を取得（その日の午前0時）
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: targetDate) else {
                continue
            }
            
            // 各日3〜5回分のレコードを生成
            let recordCount = Int.random(in: 3...5)
            
            for _ in 0..<recordCount {
                // ランダムな時間（朝6時〜夜11時の範囲）
                let hourOffset = Int.random(in: 6...23)
                let minuteOffset = Int.random(in: 0...59)
                
                guard let startTime = calendar.date(bySettingHour: hourOffset, minute: minuteOffset, second: 0, of: startOfDay) else {
                    continue
                }
                
                // endTimeは数分後（1〜10分後）
                let durationMinutes = Int.random(in: 1...10)
                let endTime = calendar.date(byAdding: .minute, value: durationMinutes, to: startTime)
                
                // 飲水量をランダムに生成（30g〜80g）
                let drinkAmount = Double.random(in: 30...80)
                
                // 開始重量をランダムに生成（300g〜500g）
                let startWeight = Double.random(in: 300...500)
                
                // 終了重量 = 開始重量 - 飲水量
                let endWeight = startWeight - drinkAmount
                
                // WaterRecordを作成
                let record = WaterRecord(
                    containerID: container.id,
                    startTime: startTime,
                    startWeight: startWeight,
                    endTime: endTime,
                    endWeight: endWeight,
                    catCount: catCount,
                    note: "ダミーデータ",
                    container: container
                )
                
                modelContext.insert(record)
            }
        }
        
        // 4. 保存
        do {
            try modelContext.save()
            print("✅ ダミーデータ生成完了: 過去14日間、合計約42〜70レコード")
        } catch {
            print("❌ ダミーデータ生成エラー: \(error.localizedDescription)")
            setError("ダミーデータの生成に失敗しました", error: error)
        }
    }
}
