//
//  HistoryView.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \WaterRecord.startTime,
        order: .reverse
    ) private var records: [WaterRecord]
    @State private var viewModel = HistoryViewModel()
    @State private var recordViewModel = RecordViewModel()
    
    // TimelineItemの配列に変換
    private var timelineItems: [TimelineItem] {
        viewModel.convertToTimelineItems(records: records, modelContext: modelContext)
    }
    
    // 日付ごとにグループ化
    private var groupedItems: [String: [TimelineItem]] {
        Dictionary(grouping: timelineItems) { item in
            viewModel.formatDate(item.date)
        }
    }
    
    // 日付のソート済みキー（新しい順）
    private var sortedDates: [String] {
        groupedItems.keys.sorted { date1, date2 in
            guard let d1 = parseDate(date1),
                  let d2 = parseDate(date2) else {
                return false
            }
            return d1 > d2
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ▼▼▼ 修正: 他のタブと同様に HStack + Spacer で左寄せレイアウトにする ▼▼▼
                HStack {
                    CommonHeaderView(weeklyAveragePerCat: recordViewModel.weeklyAveragePerCat)
                        .id("header-\(recordViewModel.lastUpdateTimestamp.timeIntervalSince1970)")
                    
                    Spacer() // これがあることでヘッダーが左に寄り、他のタブと位置が揃います
                }
                .padding(.horizontal) // 分析・記録タブと同じ余白 (16pt)
                .padding(.top, 16)
                .padding(.bottom, 12)
                // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
                
                // コンテンツ部分
                if timelineItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("まだ記録がありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(sortedDates, id: \.self) { date in
                                VStack(alignment: .leading, spacing: 8) {
                                    // 日付タイトル
                                    Text(date)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                    
                                    // その日の記録カード
                                    VStack(spacing: 0) {
                                        let items = groupedItems[date] ?? []
                                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                            TimelineRow(item: item, viewModel: viewModel)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                            
                                            if index < items.count - 1 {
                                                Divider().padding(.leading, 16)
                                            }
                                        }
                                    }
                                    .background(Color.white)
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8) // リスト上部の余白微調整
                        .padding(.bottom, 80)
                    }
                }
            }
            .background(Color.backgroundGray) // 背景色を全体に適用
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .onAppear {
                recordViewModel.setModelContext(modelContext)
            }
            .onChange(of: records) { _, _ in
                recordViewModel.calculateWeeklyAverage(using: modelContext)
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        DateFormatter.japaneseDate.date(from: dateString)
    }
}

// MARK: - TimelineRow
struct TimelineRow: View {
    let item: TimelineItem
    let viewModel: HistoryViewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左側: 時刻
            Text(viewModel.formatTime(item.date))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
                .monospacedDigit()
                .padding(.top, 2)
            
            // 中央: アイコンとテキスト
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.type == .setup ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(item.type == .setup ? Color.appMain : .green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.containerName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    HStack(spacing: 6) {
                        Text(item.type == .setup ? "新規設置" : "回収")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if item.type == .collection {
                            if let weatherEmoji = viewModel.getWeatherEmoji(sfSymbolName: item.weather) {
                                Text(weatherEmoji).font(.caption)
                            }
                            if let temperature = item.temperature {
                                Text("\(Int(temperature))℃")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // 右側: 重量情報
            VStack(alignment: .trailing, spacing: 4) {
                if item.type == .setup {
                    Text("\(Int(item.weight))g")
                        .font(.body)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                } else {
                    if let amount = item.amount {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(Int(amount))")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("ml")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.primary)
                    }
                    Text("残量: \(Int(item.weight))g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

#Preview {
    HistoryView()
}
