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
    #if DEBUG
    
    /// 過去10日間のダミーデータを生成
    func generateDummyData(modelContext: ModelContext) {
        // 1. 言語判定とワードリストの準備
        let isEnglish = Locale.current.language.languageCode?.identifier == "en"
        
        let bowlNames = isEnglish 
            ? ["Living Room", "Kitchen", "Bedroom", "Cage"] 
            : ["リビング", "キッチン", "寝室", "ケージ"]
            
        let memos = isEnglish 
            ? ["Refilled", "Fresh water", "Cleaned", "Drank well!", ""] 
            : ["水換え", "新鮮な水", "洗った", "よく飲んだ！", ""]
            
        // 2. 器の確保（リストからランダム、または新規作成）
        let fetchDescriptor = FetchDescriptor<ContainerMaster>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        var availableContainers = (try? modelContext.fetch(fetchDescriptor)) ?? []
        
        // 器がなければ作成
        if availableContainers.isEmpty {
            let containerName = bowlNames.first ?? "Bowl"
            let newContainer = ContainerMaster(name: containerName, emptyWeight: 200.0)
            modelContext.insert(newContainer)
            availableContainers.append(newContainer)
        }
        
        // 3. 現在の猫の頭数を取得
        let catCount = AppSettings.shared.numberOfPets
        
        // 4. 過去10日間のダミーデータを生成
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<10 {
            // 各日の基準日付を取得
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: targetDate) else {
                continue
            }
            
            // 1日あたり 2〜4件の記録を作成
            let recordCount = Int.random(in: 2...4)
            
            for _ in 0..<recordCount {
                // 時間をランダムに分散（朝6時〜夜10時の範囲）
                let hourOffset = Int.random(in: 6...22)
                let minuteOffset = Int.random(in: 0...59)
                
                guard let startTime = calendar.date(bySettingHour: hourOffset, minute: minuteOffset, second: 0, of: startOfDay) else {
                    continue
                }
                
                // endTimeは数分後（1〜15分後）
                let durationMinutes = Int.random(in: 1...15)
                guard let endTime = calendar.date(byAdding: .minute, value: durationMinutes, to: startTime) else { continue }
                
                // ここで未来の日付になってしまう場合はスキップ（今日のデータ作成時など）
                if endTime > Date() { continue }
                
                // 器とメモをランダム選択
                // 既存の器があればそれを使う、名前だけ更新するわけではないので注意
                // ここではシンプルに、既存のコンテナリストからランダムに選ぶ
                let container = availableContainers.randomElement()!
                
                // ダミーデータとして、コンテナ名を更新するかどうかは要件にないが、
                // 複数の器がある状況をシミュレートするためにコンテナ自体は固定
                 let memo = memos.randomElement() ?? ""
                
                // 数値の生成（設置: 200~300g, 回収: 50~150g -> 飲水量: 差分）
                let startWeight = Double(Int.random(in: 200...350))
                let endWeight = Double(Int.random(in: 50...180))
                
                // 明らかにおかしいデータ（増えている等）を除外
                if endWeight >= startWeight { continue }
                
                // WaterRecordを作成
                let record = WaterRecord(
                    containerID: container.id,
                    startTime: startTime,
                    startWeight: startWeight,
                    endTime: endTime,
                    endWeight: endWeight,
                    catCount: catCount,
                    note: memo,
                    container: container
                )
                
                modelContext.insert(record)
            }
        }
        
        // 5. 保存
        do {
            try modelContext.save()
            print("✅ ダミーデータ生成完了: 過去10日間")
        } catch {
            print("❌ ダミーデータ生成エラー: \(error.localizedDescription)")
            setError(String(localized: "ダミーデータの生成に失敗しました"), error: error)
        }
    }
    #endif
}
