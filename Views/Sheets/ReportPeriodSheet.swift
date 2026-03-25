//
//  ReportPeriodSheet.swift
//  URUOI
//
//  Created by USER on 2026/03/13.
//

import SwiftUI
import SwiftData
import PDFKit

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
    @State private var memo: String = ""
    @State private var memoDebounceTask: Task<Void, Never>?

    private let calendar = Calendar.current
    private let memoCharacterLimit = 300

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
            VStack(spacing: 0) {
                // スクロール不要な固定コンテンツ + 可変エリア
                VStack(spacing: 16) {
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

                    // PDFプレビュー or ロック表示
                    if isUnlocked {
                        if let pdfData = generatedPDFData {
                            PDFKitView(data: pdfData)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
                                .padding(.horizontal)

                            HStack(spacing: 4) {
                                Image(systemName: "printer")
                                    .font(.caption2)
                                Text("A4サイズで印刷できます")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGroupedBackground))
                                .overlay {
                                    ProgressView()
                                }
                                .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.appMain)
                            Text("月・年レポートはプレミアム機能です")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGroupedBackground))
                        )
                        .padding(.horizontal)
                    }

                // 病院へのメモ入力欄
                if isUnlocked {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(String(localized: "病院へのメモ"), systemImage: "note.text")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(memo.count)/\(memoCharacterLimit)")
                                .font(.caption)
                                .foregroundColor(memo.count >= memoCharacterLimit ? .red : .secondary)
                        }

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .frame(minHeight: 80, maxHeight: 120)

                            if memo.isEmpty {
                                Text(String(localized: "症状・気になること・質問など、受診時に伝えたいメモを入力してください"))
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 10)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $memo)
                                .font(.subheadline)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 80, maxHeight: 120)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal)
                    .onChange(of: memo) {
                        // 文字数制限
                        if memo.count > memoCharacterLimit {
                            memo = String(memo.prefix(memoCharacterLimit))
                        }
                        // デバウンス付きでプレビュー再生成
                        memoDebounceTask?.cancel()
                        memoDebounceTask = Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            if !Task.isCancelled {
                                await MainActor.run { generatePreview() }
                            }
                        }
                    }
                }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                // 生成ボタン or プレミアム導線
                if isUnlocked {
                    Button {
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(String(localized: "レポートを共有"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(generatedPDFData != nil ? Color.appMain : Color.gray)
                        .cornerRadius(.buttonCornerRadius)
                    }
                    .disabled(generatedPDFData == nil)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                } else {
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
                    .padding(.bottom, 24)
                }
            }
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
            .onAppear {
                generatePreview()
            }
            .onChange(of: selectedPeriod) {
                generatePreview()
            }
            .onChange(of: currentDate) {
                generatePreview()
            }
        }
    }

    private func generatePreview() {
        guard isUnlocked else {
            generatedPDFData = nil
            return
        }
        let pdfData = PDFReportGenerator.generateReport(
            records: records,
            period: selectedPeriod,
            currentDate: currentDate,
            numberOfPets: numberOfPets,
            memo: memo
        )
        let fileName = PDFReportGenerator.fileName(period: selectedPeriod, currentDate: currentDate)
        generatedPDFData = pdfData
        generatedFileName = fileName
    }
}

// MARK: - PDFKitView (PDFプレビュー)

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.secondarySystemGroupedBackground
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
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
