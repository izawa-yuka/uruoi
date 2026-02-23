//
//  HistoryViewModel.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - TimelineItem（履歴用データモデル）
struct TimelineItem: Identifiable {
    let id: UUID
    let date: Date
    let type: TimelineItemType
    let weight: Double
    let containerName: String
    let amount: Double? // 回収時のみ
    let weather: String? // SF Symbol名
    let temperature: Double?
    let recordID: PersistentIdentifier // 元のWaterRecordのID
    let createdByDeviceID: String? // 記録を作成したデバイスID
    
    /// 家族（自分以外）が作成した記録かどうか
    /// - `createdByDeviceID` が nil の場合は既存データなので「自分」として扱う
    var isFamilyRecord: Bool {
        guard let deviceID = createdByDeviceID, !deviceID.isEmpty else {
            return false // nil または空文字 = 既存データ or 自分の記録
        }
        return deviceID != DeviceManager.currentDeviceID
    }
    
    enum TimelineItemType {
        case setup
        case collection
    }
}

// MARK: - AnalysisPeriod（期間選択用）
// MARK: - AnalysisPeriod（期間選択用）
enum AnalysisPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"
    
    var localizedTitle: String {
        switch self {
        case .week: return String(localized: "週")
        case .month: return String(localized: "月")
        case .year: return String(localized: "年")
        }
    }
    
    func periodTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        switch self {
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return "" }
            let start = weekInterval.start
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            formatter.setLocalizedDateFormatFromTemplate("Md")
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: date)
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("y")
            return formatter.string(from: date)
        }
    }
}

// MARK: - PeriodIntakeData（グラフ用データモデル）
struct PeriodIntakeData: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let totalAmount: Double
    let label: String
}

// MARK: - HistoryViewModel
@Observable
final class HistoryViewModel {
    var currentDate: Date = Date()
    var selectedPeriod: AnalysisPeriod = .week
    
    private let calendar = Calendar.current
    
    // MARK: - 期間移動
    func moveToNextPeriod() {
        currentDate = calendar.date(byAdding: dateComponentForPeriod, value: 1, to: currentDate) ?? currentDate
    }
    
    func moveToPreviousPeriod() {
        currentDate = calendar.date(byAdding: dateComponentForPeriod, value: -1, to: currentDate) ?? currentDate
    }
    
    func canMoveToNext() -> Bool {
        let now = Date()
        switch selectedPeriod {
        case .week:
            return calendar.compare(currentDate, to: now, toGranularity: .weekOfYear) == .orderedAscending
        case .month:
            return calendar.compare(currentDate, to: now, toGranularity: .month) == .orderedAscending
        case .year:
            return calendar.compare(currentDate, to: now, toGranularity: .year) == .orderedAscending
        }
    }
    
    private var dateComponentForPeriod: Calendar.Component {
        switch selectedPeriod {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
    
    // MARK: - データ計算 (分析用)
    func calculatePeriodIntake(records: [WaterRecord], modelContext: ModelContext) -> [PeriodIntakeData] {
        guard let interval = calendar.dateInterval(of: dateComponentForPeriod, for: currentDate) else { return [] }
        let start = interval.start
        let end = interval.end
        
        let filteredRecords = records.filter { record in
            guard let recordEnd = record.endTime else { return false }
            return recordEnd >= start && recordEnd < end
        }
        
        var result: [PeriodIntakeData] = []
        var dateIterator = start
        
        while dateIterator < end {
            let nextDate: Date
            let label: String
            
            // 安全な日付計算
            switch selectedPeriod {
            case .week:
                nextDate = calendar.date(byAdding: .day, value: 1, to: dateIterator) ?? dateIterator.addingTimeInterval(86400)
                
                // 曜日のみを表示（日本語ロケールを指定）
                let weekday = calendar.component(.weekday, from: dateIterator)
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                
                // 曜日のみをラベルに設定
                label = formatter.shortWeekdaySymbols[safe: weekday - 1] ?? ""
            case .month:
                nextDate = calendar.date(byAdding: .day, value: 1, to: dateIterator) ?? dateIterator.addingTimeInterval(86400)
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                formatter.setLocalizedDateFormatFromTemplate("d")
                label = formatter.string(from: dateIterator)
            case .year:
                nextDate = calendar.date(byAdding: .month, value: 1, to: dateIterator) ?? dateIterator.addingTimeInterval(86400 * 30)
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                formatter.setLocalizedDateFormatFromTemplate("MMM")
                label = formatter.string(from: dateIterator)
            }
            
            // 無限ループ防止（万が一 nextDate が進まない場合）
            if nextDate <= dateIterator { break }
            
            let recordsInChunk = filteredRecords.filter {
                guard let rEnd = $0.endTime else { return false }
                return rEnd >= dateIterator && rEnd < nextDate
            }
            
            let amount = recordsInChunk.reduce(0) { $0 + ($1.amount ?? 0) }
            result.append(PeriodIntakeData(date: dateIterator, totalAmount: amount, label: label))
            
            dateIterator = nextDate
        }
        return result
    }
    
    private var savedPetCount: Int {
        let count = UserDefaults.standard.integer(forKey: "numberOfPets")
        return count > 0 ? count : 1
    }

    func calculatePeriodAverage(data: [PeriodIntakeData]) -> Double {
        let count = savedPetCount
        guard !data.isEmpty else { return 0 }
        let totalAmount = data.reduce(0) { $0 + $1.totalAmount }
        let averagePerUnit = totalAmount / Double(data.count)
        return averagePerUnit / Double(count)
    }
    
    func calculatePreviousPeriodAverage(records: [WaterRecord], modelContext: ModelContext) -> Double {
        let originalDate = currentDate
        let prevDate = calendar.date(byAdding: dateComponentForPeriod, value: -1, to: currentDate) ?? currentDate
        self.currentDate = prevDate
        let prevData = calculatePeriodIntake(records: records, modelContext: modelContext)
        let average = calculatePeriodAverage(data: prevData)
        self.currentDate = originalDate
        return average
    }
    
    func getComparisonText(currentAverage: Double, previousAverage: Double) -> String? {
        guard previousAverage > 0 else { return nil }
        let diff = currentAverage - previousAverage
        if diff > 0 { return String(localized: "前回より \(Int(diff))ml 増加") }
        else if diff < 0 { return String(localized: "前回より \(Int(abs(diff)))ml 減少") }
        else { return String(localized: "前回と同じ") }
    }
    
    // MARK: - タイムライン変換 (履歴画面用)
    func convertToTimelineItems(records: [WaterRecord], modelContext: ModelContext) -> [TimelineItem] {
        var items: [TimelineItem] = []
        for record in records {
            // コンテナ名を取得（削除されている場合などを考慮）
            let containerName = record.container?.name ?? String(localized: "不明な容器")
            
            // 設置レコード
            let setupItem = TimelineItem(
                id: UUID(),
                date: record.startTime,
                type: .setup,
                weight: record.startWeight,
                containerName: containerName,
                amount: nil,
                weather: nil,
                temperature: nil,
                recordID: record.id,
                createdByDeviceID: record.createdByDeviceID
            )
            items.append(setupItem)
            
            // 回収レコード（存在する場合）
            if let endTime = record.endTime {
                let collectionItem = TimelineItem(
                    id: UUID(),
                    date: endTime,
                    type: .collection,
                    weight: record.endWeight ?? 0,
                    containerName: containerName,
                    amount: record.amount,
                    weather: record.weatherCondition,
                    temperature: record.temperature,
                    recordID: record.id,
                    createdByDeviceID: record.createdByDeviceID
                )
                items.append(collectionItem)
            }
        }
        return items.sorted { $0.date > $1.date }
    }
    
    // MARK: - ヘルパー
    func getWeatherEmoji(sfSymbolName: String?) -> String? {
        guard let symbol = sfSymbolName else { return nil }
        switch symbol {
        case "sun.max": return "☀️"
        case "cloud": return "☁️"
        case "cloud.rain": return "☔️"
        case "snowflake": return "❄️"
        default: return nil
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")
        return formatter.string(from: date)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
