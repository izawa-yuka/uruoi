//
//  ReportPeriodSheet.swift
//  URUOI
//
//  Created by USER on 2026/03/13.
//

import SwiftUI
import SwiftData

/// 獣医向けレポートの期間選択＆PDF生成シート
struct ReportPeriodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<WaterRecord> { $0.endTime != nil },
        sort: \WaterRecord.endTime,
        order: .reverse
    ) private var records: [WaterRecord]

    @AppStorage("isProMember") private var isProMember: Bool = false
    @AppStorage("numberOfPets") private var numberOfPets: Int = 1

    @State private var selectedPeriod: AnalysisPeriod = .week
    @State private var currentDate: Date = Date()
    @State private var showingPremiumIntro = false
    @State private var showingShareSheet = false
    @State private var generatedPDFData: Data?
    @State private var generatedFileName: String = ""

    private let calendar = Calendar.current

    private var isUnlocked: Bool {
        isProMember || selectedPeriod == .week
    }

    private var periodTitle: String {
        selectedPeriod.periodTitle(for: currentDate)
    }

    private var canMoveToNext: Bool {
        switch selectedPeriod {
        case .week:
            return calendar.compare(currentDate, to: Date(), toGranularity: .weekOfYear) == .orderedAscending
        case .month:
            return calendar.compare(currentDate, to: Date(), toGranularity: .month) == .orderedAscending
        case .year:
            return calendar.compare(currentDate, to: Date(), toGranularity: .year) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 期間選択ピッカー
                Picker("期間", selection: $selectedPeriod) {
                    ForEach(AnalysisPeriod.allCases, id: \.self) { period in
                        Text(period.localizedTitle).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // 日付ナビゲーション
                HStack {
                    Button {
                        withAnimation {
                            let component: Calendar.Component = switch selectedPeriod {
                            case .week: .weekOfYear
                            case .month: .month
                            case .year: .year
                            }
                            currentDate = calendar.date(byAdding: component, value: -1, to: currentDate) ?? currentDate
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.appMain)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text(periodTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Button {
                        withAnimation {
                            let component: Calendar.Component = switch selectedPeriod {
                            case .week: .weekOfYear
                            case .month: .month
                            case .year: .year
                            }
                            currentDate = calendar.date(byAdding: component, value: 1, to: currentDate) ?? currentDate
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundColor(canMoveToNext ? .appMain : .gray)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canMoveToNext)
                }
                .padding(.horizontal)

                Spacer()

                // レポート説明
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.appMain)

                    Text(String(localized: "選択した期間の飲水量データをPDFレポートとして出力します。獣医への共有にご活用ください。"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // 生成ボタン or プレミアム導線
                if isUnlocked {
                    Button {
                        generateAndShare()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(String(localized: "レポートを作成"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appMain)
                        .cornerRadius(.buttonCornerRadius)
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.appMain)
                            Text(String(localized: "月・年レポートはプレミアム機能です"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Button {
                            showingPremiumIntro = true
                        } label: {
                            Text(String(localized: "詳しく見る"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.appMain)
                                .cornerRadius(.buttonCornerRadius)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 24)
            .navigationTitle(String(localized: "飲水量レポート"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPremiumIntro) {
                PremiumIntroductionView()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfData = generatedPDFData {
                    ShareSheet(activityItems: [
                        PDFDataItem(data: pdfData, fileName: generatedFileName)
                    ])
                }
            }
        }
    }

    private func generateAndShare() {
        let pdfData = PDFReportGenerator.generateReport(
            records: records,
            period: selectedPeriod,
            currentDate: currentDate,
            numberOfPets: numberOfPets
        )
        let fileName = PDFReportGenerator.fileName(period: selectedPeriod, currentDate: currentDate)

        generatedPDFData = pdfData
        generatedFileName = fileName
        showingShareSheet = true
    }
}

// MARK: - ShareSheet (UIActivityViewController Wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PDFDataItem (ファイル名付きPDFデータ)

final class PDFDataItem: NSObject, UIActivityItemSource {
    let data: Data
    let fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        data
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        data
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        "com.adobe.pdf"
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        String(localized: "URUOI 飲水量レポート")
    }

    func activityViewController(_ activityViewController: UIActivityViewController, filenameForActivityType activityType: UIActivity.ActivityType?) -> String? {
        fileName
    }
}
