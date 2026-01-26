import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<WaterRecord> { $0.endTime != nil },
        sort: \WaterRecord.endTime,
        order: .reverse
    ) private var records: [WaterRecord]
    
    @State private var viewModel = HistoryViewModel()
    @State private var recordViewModel = RecordViewModel()
    
    // 設定と連動（課金状態）
    @AppStorage("isProMember") private var isProMember: Bool = false
    @AppStorage("defaultCatCount") private var defaultCatCount: Int = 2
    
    @State private var showingPremiumIntro = false
    
    // 計算結果を保持する変数
    @State private var cachedPeriodData: [PeriodIntakeData] = []
    @State private var cachedPeriodAverage: Double = 0.0
    @State private var cachedPreviousAverage: Double = 0.0
    
    // 計算済みのデータを返す
    private var periodData: [PeriodIntakeData] {
        cachedPeriodData
    }
    
    private var chartData: [PeriodIntakeData] {
        periodData.sorted { $0.date < $1.date }
    }
    
    private var highlightData: [PeriodIntakeData] {
        chartData.filter { isCurrentPeriod($0.date) }
    }
    
    private var periodAverage: Double {
        cachedPeriodAverage
    }
    
    private var previousPeriodAverage: Double {
        cachedPreviousAverage
    }
    
    private var comparisonText: String? {
        viewModel.getComparisonText(currentAverage: periodAverage, previousAverage: previousPeriodAverage)
    }
    
    private var periodTitle: String {
        viewModel.selectedPeriod.periodTitle(for: viewModel.currentDate)
    }
    
    private var chartYScaleDomain: Double {
        let maxAmount = periodData.map { $0.totalAmount }.max() ?? 0
        return max(maxAmount * 1.2, 1000)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ▼▼▼ 修正点1: ヘッダーを左寄せに変更（他のタブと統一） ▼▼▼
                HStack {
                    CommonHeaderView(weeklyAveragePerCat: recordViewModel.weeklyAveragePerCat)
                        .id("header-\(recordViewModel.lastUpdateTimestamp.timeIntervalSince1970)")
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(.systemGroupedBackground))
                // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
                
                ScrollView {
                    VStack(spacing: 24) {
                        periodPicker.padding(.horizontal).padding(.top, 16)
                        dateNavigation.padding(.horizontal)
                        
                        chartCard.padding(.horizontal)
                        averageCard.padding(.horizontal).padding(.bottom, 24)
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .onAppear {
                recordViewModel.setModelContext(modelContext)
                updateAllData()
            }
            .onChange(of: records) { _, _ in
                recordViewModel.calculateWeeklyAverage(using: modelContext)
                updateAllData()
            }
            .onChange(of: viewModel.selectedPeriod) { _, _ in updateAllData() }
            .onChange(of: viewModel.currentDate) { _, _ in updateAllData() }
            .onChange(of: defaultCatCount) { _, _ in updateAllData() }
            
            .sheet(isPresented: $showingPremiumIntro) {
                PremiumIntroductionView()
            }
        }
    }
    
    private func updateAllData() {
        DispatchQueue.main.async {
            self.cachedPeriodData = viewModel.calculatePeriodIntake(records: records, modelContext: modelContext)
            self.cachedPeriodAverage = viewModel.calculatePeriodAverage(data: self.cachedPeriodData, catCount: defaultCatCount)
            self.cachedPreviousAverage = viewModel.calculatePreviousPeriodAverage(records: records, modelContext: modelContext, catCount: defaultCatCount)
        }
    }
    
    // --- レイアウト ---
    
    private var periodPicker: some View {
        Picker("期間", selection: $viewModel.selectedPeriod) {
            ForEach(AnalysisPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var dateNavigation: some View {
        HStack {
            Button { withAnimation { viewModel.moveToPreviousPeriod() } } label: {
                Image(systemName: "chevron.left").font(.title3).foregroundColor(.appMain).frame(width: 44, height: 44)
            }
            Spacer()
            Text(periodTitle).font(.headline).foregroundColor(.primary)
            Spacer()
            Button { withAnimation { viewModel.moveToNextPeriod() } } label: {
                Image(systemName: "chevron.right").font(.title3).foregroundColor(viewModel.canMoveToNext() ? .appMain : .gray).frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canMoveToNext())
        }
        .padding(.vertical, 8)
    }
    
    // ▼▼▼ 修正点2: .commonShadow() を削除（グラフカード） ▼▼▼
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("飲水量の推移").font(.headline).foregroundColor(.primary).padding(.horizontal)
            if periodData.isEmpty {
                emptyChart
            } else {
                ZStack {
                    chart.blur(radius: isProMember ? 0 : 10)
                    if !isProMember { ProLockOverlay(showingPremiumIntro: $showingPremiumIntro) }
                }
                .onTapGesture { if !isProMember { showingPremiumIntro = true } }
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(.cardCornerRadius)
        // .commonShadow() は削除しました
    }
    
    private var emptyChart: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar").font(.system(size: 60)).foregroundColor(.secondary)
            Text("この期間のデータがありません").font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).frame(height: 300).padding()
    }
    
    private var chart: some View {
        Chart {
            ForEach(highlightData) { data in
                BarMark(x: .value("期間", data.label), yStart: .value("底", 0), yEnd: .value("最大", chartYScaleDomain), width: .ratio(1.0))
                    .foregroundStyle(Color.appMain.opacity(0.1))
            }
            ForEach(chartData) { data in
                BarMark(x: .value("期間", data.label), y: .value("飲水量", data.totalAmount))
                    .foregroundStyle(Color.appMain).cornerRadius(4)
            }
        }
        .chartXScale(domain: chartData.map { $0.label })
        .chartYScale(domain: 0...chartYScaleDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel { if let intValue = value.as(Int.self) { Text("\(intValue)").font(.caption).foregroundColor(.secondary) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: chartData.map { $0.label }) { value in
                if let label = value.as(String.self) {
                    if shouldShowGrid(for: label) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.gray.opacity(0.2)); AxisTick()
                    }
                    if shouldShowLabel(for: label) {
                        AxisValueLabel(anchor: viewModel.selectedPeriod == .year ? .topTrailing : .top) {
                            Text(label).font(viewModel.selectedPeriod == .year ? .caption2 : .caption).foregroundColor(.secondary)
                                .rotationEffect(viewModel.selectedPeriod == .year ? .degrees(-45) : .degrees(0))
                        }
                    }
                }
            }
        }
        .padding(.bottom, viewModel.selectedPeriod == .year ? 16 : 0).frame(height: 300).padding(.horizontal)
    }
    
    private func shouldShowGrid(for label: String) -> Bool {
        switch viewModel.selectedPeriod {
        case .week: return true
        case .month:
            let dayString = label.replacingOccurrences(of: "日", with: "")
            if let day = Int(dayString) { return day == 1 || day % 5 == 0 }
            return false
        case .year: return true
        }
    }
    
    private func shouldShowLabel(for label: String) -> Bool { shouldShowGrid(for: label) }
    
    // ▼▼▼ 修正点3: .commonShadow() を削除（平均カード） ▼▼▼
    private var averageCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("平均摂取量 (1匹あたり)").font(.headline).foregroundColor(.primary)
                Text(viewModel.selectedPeriod == .week ? "過去7日間" : (viewModel.selectedPeriod == .month ? "今月" : "今年"))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", periodAverage)).font(.system(size: 32, weight: .bold)).foregroundColor(.appMain).monospacedDigit()
                    Text("ml").font(.body).foregroundColor(.secondary)
                }
                if let comparison = comparisonText {
                    Text(comparison).font(.caption).foregroundColor(.secondary).padding(.horizontal, 10).padding(.vertical, 4).background(Color(.systemGray5)).clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(.cardCornerRadius)
        // .commonShadow() は削除しました
    }
    
    private func isCurrentPeriod(_ date: Date) -> Bool {
        let calendar = Calendar.current
        switch viewModel.selectedPeriod {
        case .week, .month: return calendar.isDateInToday(date)
        case .year:
            return calendar.component(.month, from: Date()) == calendar.component(.month, from: date) &&
                   calendar.component(.year, from: Date()) == calendar.component(.year, from: date)
        }
    }
}

// MARK: - ProLockOverlay
struct ProLockOverlay: View {
    @Binding var showingPremiumIntro: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.appMain)
            
            Text("もっと！URUOIプランでグラフを見る")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button {
                showingPremiumIntro = true
            } label: {
                Text("詳しく見る")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 160, height: 48)
                    .background(Color.appMain)
                    .cornerRadius(.buttonCornerRadius)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.95))
    }
}
