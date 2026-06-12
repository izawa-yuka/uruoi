import Foundation
import SwiftData
import SwiftUI

private let maxRecordWeight: Double = 10000.0

@Observable
final class RecordViewModel {
    // MARK: - Sync Helpers
    private func getHouseholdID() -> String? {
        return UserDefaults.standard.string(forKey: "householdID")
    }

    private func syncRecord(_ record: WaterRecord) async throws {
        guard let householdID = getHouseholdID(), !householdID.isEmpty else { return }
        try await DataSyncService.shared.saveRecord(record, householdID: householdID)
    }

    private func syncDeleteRecord(id: UUID) async throws {
        guard let householdID = getHouseholdID(), !householdID.isEmpty else { return }
        try await DataSyncService.shared.deleteRecord(id: id, householdID: householdID)
    }

    private func syncContainer(_ container: ContainerMaster) async throws {
        guard let householdID = getHouseholdID(), !householdID.isEmpty else { return }
        try await DataSyncService.shared.saveContainer(container, householdID: householdID)
    }

    private func enqueueRecordSync(_ record: WaterRecord) {
        guard let householdID = getHouseholdID(), !householdID.isEmpty else { return }
        DataSyncService.shared.enqueueSaveRecord(record, householdID: householdID)
    }

    private func enqueueRecordDeleteSync(id: UUID) {
        guard let householdID = getHouseholdID(), !householdID.isEmpty else { return }
        DataSyncService.shared.enqueueDeleteRecord(id: id, householdID: householdID)
    }

    private func enqueueContainerSync(_ container: ContainerMaster) {
        guard let householdID = getHouseholdID(), !householdID.isEmpty else { return }
        DataSyncService.shared.enqueueSaveContainer(container, householdID: householdID)
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
        calculateWeeklyAverage(using: context)
        calculateTodayTotalPerCat(using: context)
        checkHealthAlert(using: context)
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
    @discardableResult
    func updateContainer(
        container: ContainerMaster,
        newName: String,
        newEmptyWeight: Double,
        modelContext: ModelContext
    ) async -> Bool {
        if let nameError = InputValidator.validateName(newName) {
            setError(nameError)
            return false
        }
        if let weightError = InputValidator.validateWeight(newEmptyWeight) {
            setError(weightError)
            return false
        }

        container.name = newName
        container.emptyWeight = newEmptyWeight
        guard container.isValid() else {
            setError(container.validationErrors().joined(separator: "\n"))
            modelContext.rollback()
            return false
        }

        do {
            try modelContext.save()

            do {
                try await syncContainer(container)
            } catch {
                enqueueContainerSync(container)
                setError(String(localized: "クラウド同期に失敗しました。後で再送します。"), error: error)
                return true
            }
            return true
        } catch {
            modelContext.rollback()
            setError(String(localized: "器の情報の更新に失敗しました"), error: error)
            return false
        }
    }

    // MARK: - 記録開始（設置）
    @discardableResult
    func startRecording(
        container: ContainerMaster,
        startWeight: Double,
        catCount: Int,
        note: String?,
        date: Date,
        modelContext: ModelContext
    ) async -> Bool {
        resetHealthAlertDismissal()

        let newRecord = WaterRecord(
            containerID: container.id,
            startTime: date,
            startWeight: startWeight,
            catCount: catCount,
            note: note
        )
        newRecord.container = container
        guard newRecord.isValid() else {
            setError(newRecord.validationErrors().joined(separator: "\n"))
            return false
        }

        // 既存の未完了レコードがあれば、保存直前に閉じる
        let closedRecords = finishActiveRecords(for: container, date: date, modelContext: modelContext)

        modelContext.insert(newRecord)

        do {
            resetHealthAlertDismissal()
            try modelContext.save()
            refreshActiveRecords(using: modelContext)
            checkHealthAlert(using: modelContext)

            do {
                for closedRecord in closedRecords {
                    try await syncRecord(closedRecord)
                }
                try await syncRecord(newRecord)
            } catch {
                for closedRecord in closedRecords {
                    enqueueRecordSync(closedRecord)
                }
                enqueueRecordSync(newRecord)
                setError(String(localized: "クラウド同期に失敗しました。後で再送します。"), error: error)
                return true
            }

            // MARK: - 通知設定（保存成功後に予約）
            if !closedRecords.isEmpty {
                NotificationManager.shared.cancelReminder(containerID: container.id)
            }
            let settings = AppSettings.shared
            if settings.isProMember && settings.waterReminderDays > 0 {
                NotificationManager.shared.scheduleWaterReminder(
                    containerID: container.id,
                    containerName: container.name,
                    days: settings.waterReminderDays,
                    startDate: date
                )
            }
            return true
        } catch {
            modelContext.rollback()
            setError(String(localized: "記録の開始に失敗しました"), error: error)
            return false
        }
    }

    // MARK: - 記録終了（回収）
    @discardableResult
    func finishRecording(
        container: ContainerMaster,
        endWeight: Double,
        weatherCondition: String?,
        temperature: Double?,
        catCount: Int,
        note: String?,
        date: Date,
        modelContext: ModelContext
    ) async -> Bool {
        resetHealthAlertDismissal()

        let targetID = container.id

        // 安全策: endTimeでのソートを避け、startTime順で最新の設置データを取得
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.containerID == targetID && $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            let activeRecords = try modelContext.fetch(descriptor)

            if let currentRecord = activeRecords.first {
                if let weightError = InputValidator.validateWeight(endWeight) {
                    setError(weightError)
                    return false
                }
                if let catError = InputValidator.validateCatCount(catCount) {
                    setError(catError)
                    return false
                }
                if let consumptionError = InputValidator.validateWaterConsumption(startWeight: currentRecord.startWeight, endWeight: endWeight) {
                    setError(consumptionError)
                    return false
                }
                if let temperature = temperature,
                   let temperatureError = InputValidator.validateTemperature(temperature) {
                    setError(temperatureError)
                    return false
                }
                if endWeight > maxRecordWeight {
                    setError(String(localized: "回収時重量は10,000g以下にしてください"))
                    return false
                }

                currentRecord.endTime = date
                currentRecord.endWeight = endWeight
                currentRecord.catCount = catCount
                currentRecord.weatherCondition = weatherCondition
                currentRecord.temperature = temperature

                currentRecord.note = collectionNote(endWeight: endWeight, userNote: note)
                guard currentRecord.isValid() else {
                    setError(currentRecord.validationErrors().joined(separator: "\n"))
                    modelContext.rollback()
                    return false
                }

                try modelContext.save()
                NotificationManager.shared.cancelReminder(containerID: container.id)
                refreshActiveRecords(using: modelContext)
                calculateWeeklyAverage(using: modelContext)
                calculateTodayTotalPerCat(using: modelContext)
                checkHealthAlert(using: modelContext)

                do {
                    try await syncRecord(currentRecord)
                } catch {
                    enqueueRecordSync(currentRecord)
                    setError(String(localized: "クラウド同期に失敗しました。後で再送します。"), error: error)
                    return true
                }
                return true
            }
            setError(String(localized: "記録の終了に失敗しました"))
            return false
        } catch {
            modelContext.rollback()
            setError(String(localized: "記録の終了に失敗しました"), error: error)
            return false
        }
    }

    // MARK: - 記録終了して再開
    @discardableResult
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
    ) async -> Bool {
        if let nextWeightError = InputValidator.validateWeight(nextStartWeight) {
            setError(nextWeightError)
            return false
        }
        if nextStartWeight <= 0 || nextStartWeight > maxRecordWeight {
            setError(String(localized: "開始重量は10000g以下で、0より大きい値を入力してください"))
            return false
        }

        resetHealthAlertDismissal()

        let targetID = container.id
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.containerID == targetID && $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            let activeRecords = try modelContext.fetch(descriptor)
            guard let currentRecord = activeRecords.first else {
                setError(String(localized: "記録の終了に失敗しました"))
                return false
            }

            if let weightError = InputValidator.validateWeight(endWeight) {
                setError(weightError)
                return false
            }
            if let catError = InputValidator.validateCatCount(catCount) {
                setError(catError)
                return false
            }
            if let consumptionError = InputValidator.validateWaterConsumption(startWeight: currentRecord.startWeight, endWeight: endWeight) {
                setError(consumptionError)
                return false
            }
            if let temperature = temperature,
               let temperatureError = InputValidator.validateTemperature(temperature) {
                setError(temperatureError)
                return false
            }

            currentRecord.endTime = date
            currentRecord.endWeight = endWeight
            currentRecord.catCount = catCount
            currentRecord.weatherCondition = weatherCondition
            currentRecord.temperature = temperature
            currentRecord.note = collectionNote(endWeight: endWeight, userNote: note)

            let nextRecord = WaterRecord(
                containerID: container.id,
                startTime: date,
                startWeight: nextStartWeight,
                catCount: catCount,
                note: nil
            )
            nextRecord.container = container

            guard currentRecord.isValid(), nextRecord.isValid() else {
                let errors = currentRecord.validationErrors() + nextRecord.validationErrors()
                setError(errors.joined(separator: "\n"))
                modelContext.rollback()
                return false
            }

            modelContext.insert(nextRecord)
            try modelContext.save()

            refreshActiveRecords(using: modelContext)
            calculateWeeklyAverage(using: modelContext)
            calculateTodayTotalPerCat(using: modelContext)
            checkHealthAlert(using: modelContext)

            do {
                try await syncRecord(currentRecord)
                try await syncRecord(nextRecord)
            } catch {
                enqueueRecordSync(currentRecord)
                enqueueRecordSync(nextRecord)
                setError(String(localized: "クラウド同期に失敗しました。後で再送します。"), error: error)
                return true
            }

            NotificationManager.shared.cancelReminder(containerID: container.id)
            let settings = AppSettings.shared
            if settings.isProMember && settings.waterReminderDays > 0 {
                NotificationManager.shared.scheduleWaterReminder(
                    containerID: container.id,
                    containerName: container.name,
                    days: settings.waterReminderDays,
                    startDate: date
                )
            }
            return true
        } catch {
            modelContext.rollback()
            setError(String(localized: "記録の更新に失敗しました"), error: error)
            return false
        }
    }

    // MARK: - 未完了レコードの強制終了
    private func finishActiveRecords(for container: ContainerMaster, date: Date, modelContext: ModelContext) -> [WaterRecord] {
        let targetID = container.id

        // 安全策: 最新のものを優先して取得
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.containerID == targetID && $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        if let activeRecords = try? modelContext.fetch(descriptor) {
            for currentRecord in activeRecords {
                currentRecord.endTime = max(date, currentRecord.startTime)
                currentRecord.endWeight = forcedEndWeight(for: currentRecord)
            }
            return activeRecords
        }
        return []
    }

    // MARK: - レコード編集
    @discardableResult
    func updateStartRecord(
        record: WaterRecord,
        newStartTime: Date,
        newStartWeight: Double,
        newNote: String?,
        modelContext: ModelContext
    ) async -> Bool {
        if let weightError = InputValidator.validateWeight(newStartWeight) {
            setError(weightError)
            return false
        }
        if newStartWeight <= 0 || newStartWeight > maxRecordWeight {
            setError(String(localized: "設置時重量は10000g以下で、0より大きい値を入力してください"))
            return false
        }
        if let endWeight = record.endWeight,
           let consumptionError = InputValidator.validateWaterConsumption(startWeight: newStartWeight, endWeight: endWeight) {
            setError(consumptionError)
            return false
        }

        record.startTime = newStartTime
        record.startWeight = newStartWeight
        record.note = newNote
        guard record.isValid() else {
            setError(record.validationErrors().joined(separator: "\n"))
            modelContext.rollback()
            return false
        }

        do {
            try modelContext.save()
            refreshActiveRecords(using: modelContext)
            calculateWeeklyAverage(using: modelContext)
            calculateTodayTotalPerCat(using: modelContext)
            checkHealthAlert(using: modelContext)

            do {
                try await syncRecord(record)
            } catch {
                enqueueRecordSync(record)
                setError(String(localized: "クラウド同期に失敗しました。後で再送します。"), error: error)
                return true
            }
            return true
        } catch {
            modelContext.rollback()
            setError(String(localized: "記録の更新に失敗しました"), error: error)
            return false
        }
    }

    @discardableResult
    func updateRecord(
        record: WaterRecord,
        newStartTime: Date,
        newEndTime: Date?,
        newStartWeight: Double,
        newEndWeight: Double?,
        newNote: String?,
        modelContext: ModelContext
    ) async -> Bool {
        if let weightError = InputValidator.validateWeight(newStartWeight) {
            setError(weightError)
            return false
        }
        if newStartWeight <= 0 || newStartWeight > maxRecordWeight {
            setError(String(localized: "設置時重量は10000g以下で、0より大きい値を入力してください"))
            return false
        }
        if let endWeight = newEndWeight {
            if let weightError = InputValidator.validateWeight(endWeight) {
                setError(weightError)
                return false
            }
            if endWeight > maxRecordWeight {
                setError(String(localized: "回収時重量は10,000g以下にしてください"))
                return false
            }
            if let consumptionError = InputValidator.validateWaterConsumption(startWeight: newStartWeight, endWeight: endWeight) {
                setError(consumptionError)
                return false
            }
        }

        record.startTime = newStartTime
        record.endTime = newEndTime
        record.startWeight = newStartWeight
        record.endWeight = newEndWeight

        if let endWeight = newEndWeight {
            record.note = collectionNote(endWeight: endWeight, userNote: newNote)
        } else {
            record.note = newNote
        }
        guard record.isValid() else {
            setError(record.validationErrors().joined(separator: "\n"))
            modelContext.rollback()
            return false
        }

        do {
            resetHealthAlertDismissal()
            try modelContext.save()
            calculateWeeklyAverage(using: modelContext)
            calculateTodayTotalPerCat(using: modelContext)
            checkHealthAlert(using: modelContext)

            do {
                try await syncRecord(record)
            } catch {
                enqueueRecordSync(record)
                setError(String(localized: "クラウド同期に失敗しました。後で再送します。"), error: error)
                return true
            }
            return true
        } catch {
            modelContext.rollback()
            setError(String(localized: "記録の更新に失敗しました"), error: error)
            return false
        }
    }

    // MARK: - レコード削除
    @discardableResult
    func deleteRecord(_ record: WaterRecord, modelContext: ModelContext) async -> Bool {
        let recordID = record.id // 削除前にIDを保持
        let reminderContainerID = record.endTime == nil ? record.container?.id : nil

        modelContext.delete(record)

        do {
            resetHealthAlertDismissal()
            try modelContext.save()
            if let reminderContainerID {
                NotificationManager.shared.cancelReminder(containerID: reminderContainerID)
            }
            refreshActiveRecords(using: modelContext)
            calculateWeeklyAverage(using: modelContext)
            calculateTodayTotalPerCat(using: modelContext)
            checkHealthAlert(using: modelContext)

            do {
                try await syncDeleteRecord(id: recordID)
            } catch {
                enqueueRecordDeleteSync(id: recordID)
                setError(String(localized: "クラウド同期に失敗しました。後で再送します。"), error: error)
                return true
            }
            return true
        } catch {
            modelContext.rollback()
            setError(String(localized: "記録の削除に失敗しました"), error: error)
            return false
        }
    }

    private func collectionNote(endWeight: Double, userNote: String?) -> String {
        var finalNote = String(localized: "回収時の重さ: \(Int(endWeight))g")
        let cleanedNote = userNoteWithoutGeneratedRemainingLine(userNote)
        if let cleanedNote, !cleanedNote.isEmpty {
            finalNote += "\n\(cleanedNote)"
        }
        return finalNote
    }

    private func userNoteWithoutGeneratedRemainingLine(_ note: String?) -> String? {
        guard let note, !note.isEmpty else { return note }
        var lines = note.components(separatedBy: .newlines)
        guard let firstLine = lines.first else { return note }
        if firstLine.hasPrefix("残量:")
            || firstLine.hasPrefix("Remaining:")
            || firstLine.hasPrefix("回収時の重さ:")
            || firstLine.hasPrefix("Weight at Collection:") {
            lines.removeFirst()
            return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return note
    }

    private func resetHealthAlertDismissal() {
        isAlertDismissed = false
        dismissedContainerIDs.removeAll()
    }

    private func forcedEndWeight(for record: WaterRecord) -> Double {
        max(0, record.startWeight - 0.1)
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
        guard AppSettings.shared.isHealthAlertEnabled else {
            return false
        }
        if dismissedContainerIDs.contains(container.id) {
            return false
        }

        let targetID = container.id
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { record in
                record.containerID == targetID && record.endTime != nil
            }
        )

        do {
            let records = try modelContext.fetch(descriptor).sorted {
                ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast)
            }
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
        let todayStart = calendar.startOfDay(for: Date())
        guard let intervalStart = calendar.date(byAdding: .day, value: -6, to: todayStart),
              let intervalEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return }
        let interval = DateInterval(start: intervalStart, end: intervalEnd)

        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate {
                $0.endTime != nil
            }
        )

        do {
            let records = try modelContext.fetch(descriptor)
            let dailyTotals = WaterIntakeCalculator.dailyTotals(from: records, in: interval, calendar: calendar)
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
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return }
        let interval = DateInterval(start: todayStart, end: tomorrowStart)

        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate {
                $0.endTime != nil
            }
        )

        do {
            let records = try modelContext.fetch(descriptor)
            let dailyTotals = WaterIntakeCalculator.dailyTotals(from: records, in: interval, calendar: calendar)
            let totalAmount = dailyTotals.values.reduce(0, +)
            let catCount = AppSettings.shared.numberOfPets
            self.todayTotalPerCat = catCount > 0 ? totalAmount / Double(catCount) : 0
        } catch {
            print("今日の合計の計算に失敗: \(error)")
        }
    }

    func checkHealthAlert(using modelContext: ModelContext) {
        let settings = AppSettings.shared
        guard settings.isHealthAlertEnabled else {
            self.isAlert = false
            self.alertMessage = ""
            return
        }

        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.endTime != nil }
        )

        do {
            let records = try modelContext.fetch(descriptor)
                .filter { !dismissedContainerIDs.contains($0.containerID) }
                .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }

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
                    let previousRecords = records.dropFirst().filter {
                        $0.endTime != nil && $0.containerID == latestRecord.containerID
                    }
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

            // 今日の合計が週間平均または設定基準と比較して少ない場合にアラート
            if weeklyAveragePerCat > 0 && todayTotalPerCat > 0 && todayTotalPerCat < weeklyAveragePerCat * 0.5 {
                print("判定結果: 🚨 今日の合計が少ない -> アラートフラグON")
                self.isAlert = true
                self.alertMessage = String(localized: "今日の飲水量の合計が、普段より少なくなっています。")
                return
            }
            if todayTotalPerCat > 0 && todayTotalPerCat < Double(settings.healthAlertThreshold) {
                print("判定結果: 🚨 今日の合計が基準量未満 -> アラートフラグON")
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

        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.endTime != nil }
        )

        do {
            let records = try modelContext.fetch(descriptor).sorted {
                ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast)
            }
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
        guard let recordAmount = WaterIntakeCalculator.normalizedDailyAmount(for: record) else { return false }
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
                    guard let amount = WaterIntakeCalculator.normalizedDailyAmount(for: record), amount > 0 else { return nil }
                    return record
                }
                .prefix(20)

            guard pastRecords.count >= 1 else {
                print("   ℹ️ 比較対象データ不足 (過去\(pastRecords.count)件)")
                return false
            }

            let amounts = pastRecords.compactMap { WaterIntakeCalculator.normalizedDailyAmount(for: $0) }
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

    func alertRangeDifferenceText(for record: WaterRecord, modelContext: ModelContext) -> String? {
        guard let recordAmount = WaterIntakeCalculator.normalizedDailyAmount(for: record) else { return nil }
        let recordID = record.id
        let targetContainerID = record.containerID

        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate {
                $0.containerID == targetContainerID
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            let allRecords = try modelContext.fetch(descriptor)
            let pastAmounts = allRecords
                .filter { $0.endTime != nil && $0.id != recordID }
                .compactMap { WaterIntakeCalculator.normalizedDailyAmount(for: $0) }
                .filter { $0 > 0 }
                .prefix(20)

            guard pastAmounts.count >= 1 else { return nil }

            let average = pastAmounts.reduce(0, +) / Double(pastAmounts.count)
            let lowerBound = average * 0.5
            let upperBound = average * 1.5

            if recordAmount >= upperBound {
                let difference = Int((recordAmount - upperBound).rounded())
                return String(localized: "アラート範囲より \(difference)ml 多いです")
            }

            if recordAmount <= lowerBound {
                let difference = Int((lowerBound - recordAmount).rounded())
                return String(localized: "アラート範囲より \(difference)ml 少ないです")
            }

            return nil
        } catch {
            setError(String(localized: "記録の異常チェックに失敗しました"), error: error)
            return nil
        }
    }

    /// 1回の記録が平均の半分以下（少なすぎ）かどうかを判定する
    private func isRecordLow(_ record: WaterRecord, modelContext: ModelContext) -> Bool {
        guard let recordAmount = WaterIntakeCalculator.normalizedDailyAmount(for: record) else { return false }
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
                .compactMap { WaterIntakeCalculator.normalizedDailyAmount(for: $0) }
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
