//
//  PDFReportGenerator.swift
//  URUOI
//
//  Created by USER on 2026/03/13.
//

import UIKit
import SwiftData

/// 獣医向け飲水量レポートをPDFとして生成するサービス
final class PDFReportGenerator {

    // MARK: - ブランドカラー（UIKit用）
    private static let brandColor = UIColor(red: 21/255, green: 110/255, blue: 186/255, alpha: 1.0) // #156EBA
    private static let lightBrandColor = UIColor(red: 21/255, green: 110/255, blue: 186/255, alpha: 0.08)

    // MARK: - PDF設定
    private static let pageSize = CGSize(width: 595.2, height: 841.8) // A4
    private static let margin: CGFloat = 40
    private static let contentWidth: CGFloat = 595.2 - 80 // pageSize.width - margin * 2

    // MARK: - 日別データ構造体
    struct DailyReportData {
        let date: Date
        let totalAmount: Double
        let perCatAmount: Double
        let weather: String?
        let temperature: Double?
    }

    // MARK: - 公開メソッド

    /// レポートPDFを生成する
    /// - Parameters:
    ///   - records: 完了済みのWaterRecord配列
    ///   - period: 対象期間
    ///   - currentDate: 基準日
    ///   - numberOfPets: ペット数
    /// - Returns: PDFデータ
    static func generateReport(
        records: [WaterRecord],
        period: AnalysisPeriod,
        currentDate: Date,
        numberOfPets: Int
    ) -> Data {
        let calendar = Calendar.current

        // 対象期間を算出
        let dateComponent: Calendar.Component = switch period {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
        guard let interval = calendar.dateInterval(of: dateComponent, for: currentDate) else {
            return Data()
        }

        // 期間内のレコードをフィルタ
        let filteredRecords = records.filter { record in
            guard let endTime = record.endTime else { return false }
            return endTime >= interval.start && endTime < interval.end
        }

        // 日別データを集計
        let dailyData = aggregateDailyData(
            records: filteredRecords,
            interval: interval,
            numberOfPets: numberOfPets,
            calendar: calendar
        )

        // 平均と前期間比較を計算
        let petCount = max(numberOfPets, 1)
        let totalAmount = dailyData.reduce(0) { $0 + $1.totalAmount }
        let dayCount = dailyData.count
        let averagePerCat = dayCount > 0 ? (totalAmount / Double(dayCount)) / Double(petCount) : 0

        // 期間タイトル
        let periodTitle = period.periodTitle(for: currentDate)

        // PDF生成
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { context in
            context.beginPage()
            var y = margin

            // ヘッダー
            y = drawHeader(y: y, periodTitle: periodTitle, numberOfPets: petCount)

            // サマリー
            y = drawSummary(y: y, averagePerCat: averagePerCat, totalDays: dayCount, totalAmount: totalAmount)

            // テーブル
            y = drawTable(context: context, y: y, dailyData: dailyData, period: period)

            // フッター（最終ページに描画）
            drawFooter()
        }

        return data
    }

    /// レポートのファイル名を生成する
    static func fileName(period: AnalysisPeriod, currentDate: Date) -> String {
        let calendar = Calendar.current
        let dateComponent: Calendar.Component = switch period {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
        guard let interval = calendar.dateInterval(of: dateComponent, for: currentDate) else {
            return "URUOI_Report.pdf"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.string(from: interval.start)
        let end = formatter.string(from: calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end)
        return "URUOI_Report_\(start)_\(end).pdf"
    }

    // MARK: - 日別データ集計

    private static func aggregateDailyData(
        records: [WaterRecord],
        interval: DateInterval,
        numberOfPets: Int,
        calendar: Calendar
    ) -> [DailyReportData] {
        let petCount = max(numberOfPets, 1)

        // 日ごとにグループ化
        var dailyMap: [Date: (amount: Double, weather: String?, temperature: Double?)] = [:]

        for record in records {
            guard let endTime = record.endTime, let amount = record.amount else { continue }
            let dayStart = calendar.startOfDay(for: endTime)

            var existing = dailyMap[dayStart] ?? (amount: 0, weather: nil, temperature: nil)
            existing.amount += amount
            // 天気・気温は最初に見つかったものを使う
            if existing.weather == nil { existing.weather = record.weatherCondition }
            if existing.temperature == nil { existing.temperature = record.temperature }
            dailyMap[dayStart] = existing
        }

        // 期間内の全日を生成（データがない日も含む）
        var result: [DailyReportData] = []
        var dateIterator = interval.start
        while dateIterator < interval.end {
            let dayStart = calendar.startOfDay(for: dateIterator)
            let entry = dailyMap[dayStart]
            let totalAmount = entry?.amount ?? 0

            result.append(DailyReportData(
                date: dayStart,
                totalAmount: totalAmount,
                perCatAmount: totalAmount / Double(petCount),
                weather: entry?.weather,
                temperature: entry?.temperature
            ))

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dateIterator) else { break }
            dateIterator = nextDay
        }

        return result
    }

    // MARK: - 描画メソッド

    private static func drawHeader(y: CGFloat, periodTitle: String, numberOfPets: Int) -> CGFloat {
        var currentY = y

        // ヘッダー背景
        let headerRect = CGRect(x: 0, y: 0, width: pageSize.width, height: 100)
        brandColor.setFill()
        UIBezierPath(rect: headerRect).fill()

        // アプリ名
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let titleStr = "URUOI"
        titleStr.draw(at: CGPoint(x: margin, y: 20), withAttributes: titleAttrs)

        // サブタイトル
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let subtitleStr = String(localized: "飲水量レポート")
        subtitleStr.draw(at: CGPoint(x: margin, y: 55), withAttributes: subtitleAttrs)

        // 期間 & ペット数（右寄せ）
        let infoAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let periodStr = periodTitle as NSString
        let periodSize = periodStr.size(withAttributes: infoAttrs)
        periodStr.draw(
            at: CGPoint(x: pageSize.width - margin - periodSize.width, y: 30),
            withAttributes: infoAttrs
        )

        let petStr = String(localized: "ペット数: \(numberOfPets)") as NSString
        let petSize = petStr.size(withAttributes: infoAttrs)
        petStr.draw(
            at: CGPoint(x: pageSize.width - margin - petSize.width, y: 50),
            withAttributes: infoAttrs
        )

        currentY = 100 + 24 // ヘッダー下のスペース
        return currentY
    }

    private static func drawSummary(y: CGFloat, averagePerCat: Double, totalDays: Int, totalAmount: Double) -> CGFloat {
        var currentY = y

        // サマリーボックス背景
        let boxHeight: CGFloat = 70
        let boxRect = CGRect(x: margin, y: currentY, width: contentWidth, height: boxHeight)
        lightBrandColor.setFill()
        UIBezierPath(roundedRect: boxRect, cornerRadius: 8).fill()

        // ラベルスタイル
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: brandColor
        ]
        let unitAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        // 左: 1匹あたり平均
        let avgLabel = String(localized: "1匹あたりの日平均")
        avgLabel.draw(at: CGPoint(x: margin + 16, y: currentY + 12), withAttributes: labelAttrs)
        let avgValue = String(format: "%.1f", averagePerCat)
        avgValue.draw(at: CGPoint(x: margin + 16, y: currentY + 32), withAttributes: valueAttrs)
        let avgValueSize = (avgValue as NSString).size(withAttributes: valueAttrs)
        "ml".draw(at: CGPoint(x: margin + 16 + avgValueSize.width + 4, y: currentY + 38), withAttributes: unitAttrs)

        // 中央: 記録日数
        let centerX = margin + contentWidth / 2 - 40
        let daysLabel = String(localized: "記録日数")
        daysLabel.draw(at: CGPoint(x: centerX, y: currentY + 12), withAttributes: labelAttrs)
        let daysValue = "\(totalDays)"
        daysValue.draw(at: CGPoint(x: centerX, y: currentY + 32), withAttributes: valueAttrs)
        let daysSize = (daysValue as NSString).size(withAttributes: valueAttrs)
        String(localized: "日").draw(at: CGPoint(x: centerX + daysSize.width + 4, y: currentY + 38), withAttributes: unitAttrs)

        // 右: 合計
        let rightX = margin + contentWidth - 140
        let totalLabel = String(localized: "期間合計")
        totalLabel.draw(at: CGPoint(x: rightX, y: currentY + 12), withAttributes: labelAttrs)
        let totalValue = String(format: "%.0f", totalAmount)
        totalValue.draw(at: CGPoint(x: rightX, y: currentY + 32), withAttributes: valueAttrs)
        let totalSize = (totalValue as NSString).size(withAttributes: valueAttrs)
        "ml".draw(at: CGPoint(x: rightX + totalSize.width + 4, y: currentY + 38), withAttributes: unitAttrs)

        currentY += boxHeight + 20
        return currentY
    }

    private static func drawTable(context: UIGraphicsPDFRendererContext, y: CGFloat, dailyData: [DailyReportData], period: AnalysisPeriod) -> CGFloat {
        var currentY = y

        // テーブルタイトル
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        String(localized: "日別記録").draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttrs)
        currentY += 24

        // カラム幅定義
        let colDate: CGFloat = 100
        let colTotal: CGFloat = 90
        let colPerCat: CGFloat = 100
        let colWeather: CGFloat = 80
        let colTemp: CGFloat = contentWidth - colDate - colTotal - colPerCat - colWeather

        let rowHeight: CGFloat = 28
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let emptyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.tertiaryLabel
        ]

        // テーブルヘッダー背景
        let headerRect = CGRect(x: margin, y: currentY, width: contentWidth, height: rowHeight)
        brandColor.setFill()
        UIBezierPath(roundedRect: headerRect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 6, height: 6)).fill()

        // テーブルヘッダーテキスト
        let headers = [
            (String(localized: "日付"), colDate),
            (String(localized: "合計"), colTotal),
            (String(localized: "1匹あたり"), colPerCat),
            (String(localized: "天気"), colWeather),
            (String(localized: "気温"), colTemp)
        ]
        var headerX = margin + 8
        for (text, width) in headers {
            text.draw(at: CGPoint(x: headerX, y: currentY + 7), withAttributes: headerAttrs)
            headerX += width
        }
        currentY += rowHeight

        // 日付フォーマッタ
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.setLocalizedDateFormatFromTemplate("Md_E")

        let weatherMap: [String: String] = [
            "sun.max": "☀️",
            "cloud": "☁️",
            "cloud.rain": "☔️",
            "snowflake": "❄️"
        ]

        // データ行
        for (index, day) in dailyData.enumerated() {
            // ページ跨ぎチェック
            if currentY + rowHeight > pageSize.height - 60 {
                drawFooter()
                context.beginPage()
                currentY = margin
            }

            // 偶数行の背景
            if index % 2 == 0 {
                let rowRect = CGRect(x: margin, y: currentY, width: contentWidth, height: rowHeight)
                UIColor.systemGray6.setFill()
                UIBezierPath(rect: rowRect).fill()
            }

            var cellX = margin + 8

            // 日付
            let dateStr = dateFormatter.string(from: day.date)
            dateStr.draw(at: CGPoint(x: cellX, y: currentY + 7), withAttributes: cellAttrs)
            cellX += colDate

            // 合計
            if day.totalAmount > 0 {
                let amountStr = String(format: "%.0f ml", day.totalAmount)
                amountStr.draw(at: CGPoint(x: cellX, y: currentY + 7), withAttributes: cellAttrs)
            } else {
                "-".draw(at: CGPoint(x: cellX, y: currentY + 7), withAttributes: emptyAttrs)
            }
            cellX += colTotal

            // 1匹あたり
            if day.perCatAmount > 0 {
                let perCatStr = String(format: "%.0f ml", day.perCatAmount)
                perCatStr.draw(at: CGPoint(x: cellX, y: currentY + 7), withAttributes: cellAttrs)
            } else {
                "-".draw(at: CGPoint(x: cellX, y: currentY + 7), withAttributes: emptyAttrs)
            }
            cellX += colPerCat

            // 天気
            if let weather = day.weather, let emoji = weatherMap[weather] {
                emoji.draw(at: CGPoint(x: cellX, y: currentY + 5), withAttributes: cellAttrs)
            } else {
                "-".draw(at: CGPoint(x: cellX, y: currentY + 7), withAttributes: emptyAttrs)
            }
            cellX += colWeather

            // 気温
            if let temp = day.temperature {
                let tempStr = String(format: "%.0f°C", temp)
                tempStr.draw(at: CGPoint(x: cellX, y: currentY + 7), withAttributes: cellAttrs)
            } else {
                "-".draw(at: CGPoint(x: cellX, y: currentY + 7), withAttributes: emptyAttrs)
            }

            currentY += rowHeight
        }

        // テーブル下の罫線
        let lineRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 0.5)
        UIColor.separator.setFill()
        UIBezierPath(rect: lineRect).fill()

        currentY += 16
        return currentY
    }

    private static func drawFooter() {
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.tertiaryLabel
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMd_HHmm")
        let dateStr = formatter.string(from: Date())

        let footerText = "Generated by URUOI | \(dateStr)" as NSString
        let footerSize = footerText.size(withAttributes: footerAttrs)
        footerText.draw(
            at: CGPoint(
                x: (pageSize.width - footerSize.width) / 2,
                y: pageSize.height - 30
            ),
            withAttributes: footerAttrs
        )
    }
}
