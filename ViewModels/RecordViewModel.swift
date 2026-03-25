import Foundation
import SwiftData
import SwiftUI

@Observable
final class RecordViewModel {
    // MARK: - Sync Helpers
    private func getHouseholdID() -> String? {
        return UserDefaults.standard.string(forKey: "householdID")
    }
    
    private func syncRecord(_ record: WaterRecord) {
        guard let householdID = getHouseholdID(), !householdID.isEmpty else { return }
        DataSyncService.shared.saveRecord(record, householdID: householdID)
    }
    
    private func syncDeleteRecord(id: UUID) {
        guard let householdID = getHouseholdID(), !householdID.isEmpty else { return }
        DataSyncService.shared.deleteRecord(id: id, householdID: householdID)
    }

    // アラート関連
    var isAlert: Bool = false
    var alertMessage: String = ""
    var isAlertDismissed: Bool = false
    // レコード一覧
    var activeRecords: [WaterRecord] = []
    
    // 1匹あたりの週間平均
    var weeklyAveragePerCat: Double = 0
    // 今日の合計
    var todayTotalPerCat: Double = 0
    
    // エラーハンドリング
    var lastError: String?
    var showError: Bool = false
    var lastUpdateTimestamp: Date = Date()
    
    // アラート解除済みの器ID
    private var dismissedContainerIDs: Set<UUID> = []
    
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        refreshActiveRecords(using: context)
        checkHealthAlert(using: context)
        calculateWeeklyAverage(using: context)
        calculateTodayTotalPerCat(using: context)
    }
    
    // MARK: - エラーハンドリング
    private func setError(_ message: String, error: Error? = nil) {
        self.lastError = message
        self.showError = true
        if let error = error {
            print("[\(type(of: self))] \(message): \(error.localizedDescription)")
        } else {
            print("[\(type(of: self))] \(message)")
        }
    }
    
    func clearError() {
        self.lastError = nil
        self.showError = false
    }
    
    // MARK: - 器の更新
    func updateContainer(
        container: ContainerMaster,
        newName: String,
        newEmptyWeight: Double,
        modelContext: ModelContext
    ) {
        container.name = newName
        container.emptyWeight = newEmptyWeight
        
        do {
            try modelContext.save()
            
            // Sync
            if let householdID = getHouseholdID(), !householdID.isEmpty {
                DataSyncService.shared.saveContainer(container, householdID: householdID)
            }
        } catch {
            setError(String(localized: "器の情報の更新に失敗しました"), error: error)
        }
    }

    // MARK: - 記録開始（設置）
    func startRecording(
        container: ContainerMaster,
        startWeight: Double,
        catCount: Int,
        note: String?,
        date: Date,
        modelContext: ModelContext
    ) {
        dismissedContainerIDs.removeAll()
        
        // 既存の未完了レコードがあれば閉じる
        finishActiveRecord(for: container, date: date, modelContext: modelContext)
        
        let newRecord = WaterRecord(
            containerID: container.id,
            startTime: date,
            startWeight: startWeight,
            catCount: catCount,
            note: note
        )
        newRecord.container = container
        
        modelContext.insert(newRecord)
        
        // MARK: - 通知設定（本番用に戻しました）
        let settings = AppSettings.shared
        
        // 条件：Proメンバー かつ 通知日数が設定されている場合のみ
        if settings.isProMember && settings.waterReminderDays > 0 {
            NotificationManager.shared.scheduleWaterReminder(
                containerID: container.id,
                containerName: container.name,
                days: settings.waterReminderDays,
                startDate: date
            )
        }
        
        do {
            try modelContext.save()
            refreshActiveRecords(using: modelContext)
            checkHealthAlert(using: modelContext)
            
            // Sync
            syncRecord(newRecord)
        } catch {
            setError(String(localized: "記録の開始に失敗しました"), error: error)
        }
    }
    
    // MARK: - 記録終了（回収）
    func finishRecording(
        container: ContainerMaster,
        endWeight: Double,
        weatherCondition: String?,
        temperature: Double?,
        catCount: Int,
        note: String?,
        date: Date,
        modelContext: ModelContext
    ) {
        dismissedContainerIDs.removeAll()
        
        let targetID = container.id
        
        // 安全策: endTimeでのソートを避け、startTime順で最新の設置データを取得
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.containerID == targetID && $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            let activeRecords = try modelContext.fetch(descriptor)
            
            if let currentRecord = activeRecords.first {
                if endWeight > currentRecord.startWeight {
                    let weight = Int(currentRecord.startWeight)
                    setError(String(localized: "残量は設置時の量（\(weight)g）より少なくしてください"))
                    return
                }
                
                currentRecord.endTime = date
                currentRecord.endWeight = endWeight
                currentRecord.catCount = catCount
                currentRecord.weatherCondition = weatherCondition
                currentRecord.temperature = temperature
                
                var finalNote = String(localized: "残量: \(Int(endWeight))g")
                if let userNote = note, !userNote.isEmpty {
                    finalNote += "\n\(userNote)"
                }
                currentRecord.note = finalNote
                
                NotificationManager.shared.cancelReminder(containerID: container.id)
                
                try modelContext.save()
                refreshActiveRecords(using: modelContext)
                calculateWeeklyAverage(using: modelContext)
                calculateTodayTotalPerCat(using: modelContext)
                checkHealthAlert(using: modelContext)
                
                // Sync
                syncRecord(currentRecord)
            }
        } catch {
            setError(String(localized: "記録の終了に失敗しました"), error: error)
        }
    }
    
    // MARK: - 記録終了して再開
    func finishAndRestartRecording(
        container: ContainerMaster,
        endWeight: Double,
        weatherCondition: String?,
        temperature: Double?,
        catCount: Int,
        note: String?,
        nextStartWeight: Double,
        date: Date,
        modelContext: ModelContext
    ) {
        // 先に終了処理
        finishRecording(
            container: container,
            endWeight: endWeight,
            weatherCondition: weatherCondition,
            temperature: temperature,
            catCount: catCount,
            note: note,
            date: date,
            modelContext: modelContext
        )
        
        // エラーが出ていなければ開始処理へ
        if !showError {
            let remainingNote = String(localized: "残量: \(Int(endWeight))g")
            startRecording(
                container: container,
                startWeight: nextStartWeight,
                catCount: catCount,
                note: remainingNote,
                date: date,
                modelContext: modelContext
            )
        }
    }
    
    // MARK: - 未完了レコードの強制終了
    private func finishActiveRecord(for container: ContainerMaster, date: Date, modelContext: ModelContext) {
        let targetID = container.id
        
        // 安全策: 最新のものを優先して取得
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.containerID == targetID && $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        if let activeRecords = try? modelContext.fetch(descriptor), let currentRecord = activeRecords.first {
            currentRecord.endTime = date
            currentRecord.endWeight = currentRecord.startWeight
            
            NotificationManager.shared.cancelReminder(containerID: container.id)
            
            // Sync
            syncRecord(currentRecord)
        }
    }
    
    // MARK: - レコード編集
    func updateStartRecord(
        record: WaterRecord,
        newStartTime: Date,
        newStartWeight: Double,
        newNote: String?,
        modelContext: ModelContext
    ) {
        record.startTime = newStartTime
        record.startWeight = newStartWeight
        record.note = newNote
        
        do {
            try modelContext.save()
            refreshActiveRecords(using: modelContext)
            checkHealthAlert(using: modelContext)
            calculateWeeklyAverage(using: modelContext)
            calculateWeeklyAverage(using: modelContext)
            calculateTodayTotalPerCat(using: modelContext)
            
            // Sync
            syncRecord(record)
        } catch {
            setError(String(localized: "記録の更新に失敗しました"), error: error)
        }
    }
    
    func updateRecord(
        record: WaterRecord,
        newStartTime: Date,
        newEndTime: Date?,
        newStartWeight: Double,
        newEndWeight: Double?,
        newNote: String?,
        modelContext: ModelContext
    ) {
        record.startTime = newStartTime
        record.endTime = newEndTime
        record.startWeight = newStartWeight
        record.endWeight = newEndWeight
        
        if let endWeight = newEndWeight {
            var finalNote = String(localized: "残量: \(Int(endWeight))g")
            if let userNote = newNote, !userNote.isEmpty {
                finalNote += "\n\(userNote)"
            }
            record.note = finalNote
        } else {
            record.note = newNote
        }
        
        do {
            try modelContext.save()
            checkHealthAlert(using: modelContext)
            calculateWeeklyAverage(using: modelContext)
            calculateTodayTotalPerCat(using: modelContext)
            
            // Sync
            syncRecord(record)
        } catch {
            setError(String(localized: "記録の更新に失敗しました"), error: error)
        }
    }
    
    // MARK: - レコード削除
    func deleteRecord(_ record: WaterRecord, modelContext: ModelContext) {
        let recordID = record.id // 削除前にIDを保持
        if record.endTime == nil, let container = record.container {
             NotificationManager.shared.cancelReminder(containerID: container.id)
        }

        modelContext.delete(record)
        
        do {
            try modelContext.save()
            refreshActiveRecords(using: modelContext)
            checkHealthAlert(using: modelContext)
            calculateWeeklyAverage(using: modelContext)
            calculateTodayTotalPerCat(using: modelContext)
            
            // Sync
            syncDeleteRecord(id: recordID)
        } catch {
            setError(String(localized: "記録の削除に失敗しました"), error: error)
        }
    }
    
    // MARK: - 内部ロジック
    func refreshActiveRecords(using modelContext: ModelContext) {
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            self.activeRecords = try modelContext.fetch(descriptor)
            self.lastUpdateTimestamp = Date()
        } catch {
            setError(String(localized: "データの取得に失敗しました"), error: error)
        }
    }
    
    func isContainerActive(container: ContainerMaster, modelContext: ModelContext) -> Bool {
        return activeRecords.contains { $0.containerID == container.id }
    }
    
    // MARK: - 水質アラート（色判定）
    func getWaterStatusColor(for container: ContainerMaster) -> Color {
        // アクティブなレコードを取得
        guard let record = activeRecords.first(where: { $0.containerID == container.id }) else {
            return .gray // 非アクティブ
        }
        
        let settings = AppSettings.shared
        
        // アラートが無効、またはProメンバーでない場合は常にFresh
        if !settings.isProMember || !settings.isWaterAlertEnabled {
            return .appMain
        }
        
        let days = settings.waterReminderDays
        // 設定日数が0以下の場合は、期限ロジック無効（常にFresh）
        if days <= 0 { return .appMain }
        
        // 1. 期限（Deadline）の計算: startTime + alertInterval
        let calendar = Calendar.current
        guard let deadline = calendar.date(byAdding: .day, value: days, to: record.startTime) else {
            return .appMain
        }
        
        // 2. 残り時間の計算: Deadline - CurrentTime
        let remainingSeconds = deadline.timeIntervalSince(Date())
        let remainingHours = remainingSeconds / 3600.0
        
        // 3. 判定ロジック
        if remainingHours <= 3 {
             // 交換 (Urgent): 3時間以下 (および期限切れ)
             // ピンク: F15BB5
            return .statusUrgent
        } else if remainingHours < 12 {
            // 予備軍 (Notice): 12時間未満 〜 3時間前に到達
            // ラベンダー: 9B5DE5
            return .statusNotice
        } else {
            // 通常 (Fresh): 12時間以上ある
            // 青: Color.appMain
            return .appMain
        }
    }
    
    func getElapsedTime(for container: ContainerMaster, modelContext: ModelContext) -> String? {
        guard let record = activeRecords.first(where: { $0.containerID == container.id }) else {
            return nil
        }
        
        let diff = Date().timeIntervalSince(record.startTime)
        let totalSeconds = max(0, Int(diff))
        
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if days > 0 {
            return String(localized: "\(days)日と\(hours)時間\(minutes)分経過")
        } else if hours > 0 {
            return String(localized: "\(hours)時間\(minutes)分経過")
        } else {
            return String(localized: "\(minutes)分経過")
        }
    }
    
    func getRecentHistory(for container: ContainerMaster, modelContext: ModelContext, limit: Int = 10) -> [WaterRecord] {
        let containerID = container.id
        var descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.containerID == containerID },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("履歴の取得に失敗: \(error)")
            return []
        }
    }
    
    func isContainerInAlertState(container: ContainerMaster, modelContext: ModelContext) -> Bool {
        if dismissedContainerIDs.contains(container.id) {
            return false
        }
        
        let targetID = container.id
        // 修正: endTimeでのソートをstartTimeに変更 (クラッシュ回避)
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { record in
                record.containerID == targetID && record.endTime != nil
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            let records = try modelContext.fetch(descriptor)
            if let latestRecord = records.first {
                return isRecordAbnormal(latestRecord, modelContext: modelContext)
            }
        } catch {
            print("器のアラート状態確認エラー: \(error.localizedDescription)")
        }
        
        return false
    }
    
    // MARK: - 集計ロジック
    func calculateWeeklyAverage(using modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return }
        
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate {
                $0.endTime != nil &&
                $0.startTime >= sevenDaysAgo
            }
        )
        
        do {
            let records = try modelContext.fetch(descriptor)
            var dailyTotals: [Date: Double] = [:]
            for record in records {
                if let amount = record.amount, let endTime = record.endTime {
                    let day = calendar.startOfDay(for: endTime)
                    dailyTotals[day, default: 0] += amount
                }
            }
            
            let totalAmount = dailyTotals.values.reduce(0, +)
            let catCount = AppSettings.shared.numberOfPets
            
            self.weeklyAveragePerCat = catCount > 0 ? totalAmount / 7.0 / Double(catCount) : 0
            
        } catch {
            print("週間平均の計算に失敗: \(error)")
        }
    }
    
    func calculateTodayTotalPerCat(using modelContext: ModelContext) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let now = Date()
        
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate {
                $0.endTime != nil &&
                $0.startTime >= todayStart &&
                $0.startTime <= now
            }
        )
        
        do {
            let records = try modelContext.fetch(descriptor)
            let totalAmount = records.reduce(0.0) { $0 + ($1.amount ?? 0) }
            let catCount = AppSettings.shared.numberOfPets
            self.todayTotalPerCat = catCount > 0 ? totalAmount / Double(catCount) : 0
        } catch {
            print("今日の合計の計算に失敗: \(error)")
        }
    }
    
    func checkHealthAlert(using modelContext: ModelContext) {
        if isAlertDismissed { return }

        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.endTime != nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            let records = try modelContext.fetch(descriptor)

            guard let latestRecord = records.first else {
                self.isAlert = false
                return
            }

            print("----- 🏥 健康アラート判定処理開始 -----")
            if let amount = latestRecord.amount {
                print("今回の記録量: \(amount)ml")
            }

            if isRecordAbnormal(latestRecord, modelContext: modelContext) {
                if isRecordLow(latestRecord, modelContext: modelContext) {
                    // 少なすぎる場合：連続して少ない記録がある場合のみアラート
                    let previousRecords = records.dropFirst().filter { $0.endTime != nil }
                    if let previousRecord = previousRecords.first,
                       isRecordLow(previousRecord, modelContext: modelContext) {
                        print("判定結果: 🚨 連続して少ない -> アラートフラグON")
                        self.isAlert = true
                        self.alertMessage = String(localized: "直近の記録で、普段と異なる飲水量が検出されました。")
                        return
                    }
                    print("判定結果: ✅ 1回だけ少ない（アラートなし）")
                } else {
                    // 多すぎる場合：1回で即アラート
                    print("判定結果: 🚨 異常あり（多すぎ）-> アラートフラグON")
                    self.isAlert = true
                    self.alertMessage = String(localized: "直近の記録で、普段と異なる飲水量が検出されました。")
                    return
                }
            }

            // 今日の合計が週間平均と比較して大幅に少ない場合にアラート
            if weeklyAveragePerCat > 0 && todayTotalPerCat > 0 && todayTotalPerCat < weeklyAveragePerCat * 0.5 {
                print("判定結果: 🚨 今日の合計が少ない -> アラートフラグON")
                self.isAlert = true
                self.alertMessage = String(localized: "今日の飲水量の合計が、普段より少なくなっています。")
                return
            }

            print("判定結果: ✅ 正常")
            print("--------------------------------")
            self.isAlert = false

        } catch {
            return
        }
    }
    
    func dismissAlert() {
        self.isAlert = false
        self.isAlertDismissed = true
        
        guard let modelContext = modelContext else { return }
        
        // 修正: ここもソート条件を変更
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.endTime != nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            let records = try modelContext.fetch(descriptor)
            if let latestRecord = records.first,
               isRecordAbnormal(latestRecord, modelContext: modelContext) {
                dismissedContainerIDs.insert(latestRecord.containerID)
                triggerUIUpdate()
            }
        } catch {
            print("アラート解除時のレコード取得エラー: \(error.localizedDescription)")
        }
    }
    
    func isRecordAbnormal(_ record: WaterRecord, modelContext: ModelContext) -> Bool {
        guard let recordAmount = record.amount else { return false }
        let recordID = record.id
        
        let targetContainerID = record.containerID
        
        // ここは元々startTimeなので安全です
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate {
                $0.containerID == targetContainerID
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            let allRecords = try modelContext.fetch(descriptor)
            
            let pastRecords = allRecords
                .filter { $0.endTime != nil }
                .filter { $0.id != recordID }
                .compactMap { record -> WaterRecord? in
                    guard let amount = record.amount, amount > 0 else { return nil }
                    return record
                }
                .prefix(20)
            
            guard pastRecords.count >= 1 else {
                print("   ℹ️ 比較対象データ不足 (過去\(pastRecords.count)件)")
                return false
            }
            
            let amounts = pastRecords.compactMap { $0.amount }
            guard !amounts.isEmpty else { return false }
            
            let average = amounts.reduce(0, +) / Double(amounts.count)
            let lowerBound = average * 0.5
            let upperBound = average * 1.5
            
            print("   📊 平均値(直近20件): \(String(format: "%.1f", average))ml")
            print("   ⚖️ 正常範囲: \(String(format: "%.1f", lowerBound)) 〜 \(String(format: "%.1f", upperBound))ml")
            
            if recordAmount >= upperBound || recordAmount <= lowerBound {
                print("   ⚠️ 異常検出: \(recordAmount)ml (範囲外)")
                return true
            }
            
            return false
        } catch {
            setError(String(localized: "記録の異常チェックに失敗しました"), error: error)
            return false
        }
    }
    
    /// 1回の記録が平均の半分以下（少なすぎ）かどうかを判定する
    private func isRecordLow(_ record: WaterRecord, modelContext: ModelContext) -> Bool {
        guard let recordAmount = record.amount else { return false }
        let recordID = record.id
        let targetContainerID = record.containerID

        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.containerID == targetContainerID },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            let allRecords = try modelContext.fetch(descriptor)
            let pastAmounts = allRecords
                .filter { $0.endTime != nil && $0.id != recordID }
                .compactMap { $0.amount }
                .filter { $0 > 0 }
                .prefix(20)

            guard pastAmounts.count >= 1 else { return false }
            let average = pastAmounts.reduce(0, +) / Double(pastAmounts.count)
            return recordAmount <= average * 0.5
        } catch {
            return false
        }
    }

    func triggerUIUpdate() {
        lastUpdateTimestamp = Date()
    }
}
