//
//  CommonHeaderView.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import SwiftUI

struct CommonHeaderView: View {
    let weeklyAveragePerCat: Double
    private let calendar = Calendar.current

    private var aggregationPeriodText: String {
        let todayStart = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -6, to: todayStart) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("Md")

        let separator = Locale.current.language.languageCode == .japanese ? "〜" : "–"
        return "\(formatter.string(from: start))\(separator)\(formatter.string(from: todayStart))"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 水滴アイコン
            Image(systemName: "drop.fill")
                .font(.body)
                .foregroundColor(.appMain)
                .padding(9)
                .background(Color.appMain.opacity(0.1))
                .clipShape(Circle())
            
            // テキスト情報（左揃え）
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "平均 (7日間)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(weeklyAveragePerCat))")
                        .font(.system(size: 21, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.appMain)
                    
                    Text("ml")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(String(localized: "/匹"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("\(String(localized: "集計期間")): \(aggregationPeriodText)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .background(Color.white)
        .cornerRadius(16)
        // 影（shadow）と枠線は削除済み
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemGroupedBackground)
        CommonHeaderView(weeklyAveragePerCat: 125.5)
    }
}
