//
//  ContainerDetailView.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import SwiftUI
import SwiftData

struct ContainerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let container: ContainerMaster
    @State private var viewModel = RecordViewModel()
    @State private var showingStartSheet = false
    @State private var showingFinishSheet = false
    @State private var historyRecords: [WaterRecord] = []
    @State private var showingEditSheet = false
    @State private var editedName: String = ""
    @State private var editedEmptyWeight: String = ""
    @AppStorage("numberOfPets") private var catCount: Int = 1
    @State private var historyViewModel = HistoryViewModel()
    @State private var settingsViewModel = SettingsViewModel()
    
    // 履歴編集用の選択状態
    @State private var selectedRecordForEdit: WaterRecord?
    
    private var isActive: Bool {
        viewModel.isContainerActive(container: container, modelContext: modelContext)
    }
    
    private var timelineItems: [TimelineItem] {
        // クラッシュ対策: 削除されたレコードが配列に残っている場合にアクセスするとクラッシュするため、
        // isDeletedフラグをチェックして有効なレコードのみを変換対象にする
        let validRecords = historyRecords.filter { !$0.isDeleted }
        return historyViewModel.convertToTimelineItems(records: validRecords, modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ContainerDetailHeader(container: container)
                Divider()
                ContainerHistoryList(
                    timelineItems: timelineItems,
                    historyRecords: historyRecords,
                    container: container,
                    viewModel: viewModel,
                    historyViewModel: historyViewModel,
                    modelContext: modelContext,
                    onTapRecord: { record in
                        selectedRecordForEdit = record
                    }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button { dismiss() } label: { Image(systemName: "xmark") } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editedName = container.name
                        editedEmptyWeight = container.emptyWeight > 0 ? String(Int(container.emptyWeight)) : ""
                        showingEditSheet = true
                    } label: { Image(systemName: "pencil") }
                }
            }
            .sheet(isPresented: $showingEditSheet, onDismiss: { loadHistory() }) {
                EditContainerSheet(
                    container: container, editedName: $editedName, editedEmptyWeight: $editedEmptyWeight,
                    viewModel: viewModel, settingsViewModel: settingsViewModel, modelContext: modelContext, onDelete: { dismiss() }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                if isActive {
                        Button { showingFinishSheet = true } label: {
                            Text(String(localized: "回収する")).fontWeight(.semibold).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56).background(Color.green).cornerRadius(.buttonCornerRadius)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16).background(Color(.systemBackground))
                    } else {
                        Button { showingStartSheet = true } label: {
                            Text(String(localized: "水を設置する")).fontWeight(.semibold).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56).background(Color.appMain).cornerRadius(.buttonCornerRadius)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16).background(Color(.systemBackground))
                    }
                }
            }
            .sheet(isPresented: $showingStartSheet, onDismiss: {
                loadHistory(); viewModel.refreshActiveRecords(using: modelContext)
                viewModel.checkHealthAlert(using: modelContext); viewModel.calculateWeeklyAverage(using: modelContext)
            }) {
                StartRecordingSheet(container: container, viewModel: viewModel, modelContext: modelContext, catCount: catCount)
                    .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingFinishSheet, onDismiss: {
                loadHistory(); viewModel.refreshActiveRecords(using: modelContext)
                viewModel.checkHealthAlert(using: modelContext); viewModel.calculateWeeklyAverage(using: modelContext)
            }) {
                FinishRecordingSheet(container: container, viewModel: viewModel, modelContext: modelContext, catCount: catCount)
                    .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedRecordForEdit, onDismiss: {
                loadHistory()
                viewModel.refreshActiveRecords(using: modelContext)
                viewModel.checkHealthAlert(using: modelContext)
                viewModel.calculateWeeklyAverage(using: modelContext)
            }) { record in
                RecordEditSheet(record: record)
            }
            .onAppear { viewModel.setModelContext(modelContext); loadHistory(); viewModel.checkHealthAlert(using: modelContext) }
            .onChange(of: isActive) { _, _ in loadHistory(); viewModel.checkHealthAlert(using: modelContext) }
            .onChange(of: historyRecords) { _, _ in viewModel.checkHealthAlert(using: modelContext) }
            .alert("エラーが発生しました", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { viewModel.clearError() }
            } message: {
                if let errorMessage = viewModel.lastError { Text(errorMessage) }
            }
        }
    }
    
    private func loadHistory() {
        historyRecords = viewModel.getRecentHistory(for: container, modelContext: modelContext, limit: 30)
    }
}

// MARK: - Subviews

fileprivate let maxInputWeight: Double = 10000.0

struct StartRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let container: ContainerMaster
    let viewModel: RecordViewModel
    let modelContext: ModelContext
    let catCount: Int
    @State private var startWeight: String = ""
    @State private var note: String = ""
    @State private var recordDate = Date()
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.backgroundGray.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(String(localized: "新規設置")).font(.subheadline).foregroundStyle(.secondary).padding(.leading, 4)
                            VStack(spacing: 16) {
                                TextField(String(localized: "設置する水の重さ (g)"), text: $startWeight)
                                    .keyboardType(.decimalPad).focused($isInputFocused).monospacedDigit().customTextFieldStyle()
                                TextField(String(localized: "メモ (50文字以内)"), text: $note)
                                    .focused($isInputFocused).customTextFieldStyle()
                                    .onChange(of: note) { _, newValue in if newValue.count > 50 { note = String(newValue.prefix(50)) } }
                            }
                            .padding().background(Color.white).cornerRadius(16)
                            Text(String(localized: "日時")).font(.subheadline).foregroundStyle(.secondary).padding(.leading, 4)
                            VStack {
                                DatePicker(String(localized: "記録日時"), selection: $recordDate, displayedComponents: [.date, .hourAndMinute])
                                    .environment(\.locale, Locale.current)
                            }.padding().background(Color.white).cornerRadius(16)
                        }
                        .padding(.horizontal).padding(.top, 20)
                    }
                    .padding(.bottom, 80)
                }
                Button { saveStart() } label: {
                    Text(String(localized: "設置を開始する")).fontWeight(.semibold).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56)
                        .background((startWeight.isEmpty || Double(startWeight) == nil) ? Color.disabledButtonBackground : Color.appMain)
                        .cornerRadius(.buttonCornerRadius)
                }
                .disabled(startWeight.isEmpty || Double(startWeight) == nil).padding(.horizontal, 20).padding(.bottom, 20)
            }
            .navigationTitle(String(localized: "水を設置する")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
            .alert(String(localized: "入力エラー"), isPresented: $showingValidationAlert) { Button("OK", role: .cancel) { } } message: { Text(validationMessage) }
        }
        .keyboardToolbar(focus: $isInputFocused)
    }
    
    private func saveStart() {
        guard let weight = Double(startWeight) else { return }
        if weight > maxInputWeight { validationMessage = "10,000g以下の値を入力してください"; showingValidationAlert = true; return }
        if let weightError = InputValidator.validateWeight(weight) { validationMessage = weightError; showingValidationAlert = true; return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.startRecording(container: container, startWeight: weight, catCount: catCount, note: trimmedNote.isEmpty ? nil : trimmedNote, date: recordDate, modelContext: modelContext)
        dismiss()
    }
}

struct FinishRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let container: ContainerMaster
    let viewModel: RecordViewModel
    let modelContext: ModelContext
    let catCount: Int
    @State private var endWeight: String = ""
    @State private var selectedWeather: WeatherOption? = nil
    @State private var temperature: String = ""
    @State private var note: String = ""
    @State private var nextStartWeight: String = ""
    @State private var recordDate = Date()
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.backgroundGray.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(String(localized: "回収")).font(.subheadline).foregroundStyle(.secondary).padding(.leading, 4)
                                VStack(spacing: 16) {
                                    TextField(String(localized: "回収時の重さ (g)"), text: $endWeight)
                                        .keyboardType(.decimalPad).focused($isInputFocused).monospacedDigit().customTextFieldStyle()
                                    TextField(String(localized: "メモ (50文字以内)"), text: $note)
                                        .focused($isInputFocused).customTextFieldStyle()
                                        .onChange(of: note) { _, newValue in if newValue.count > 50 { note = String(newValue.prefix(50)) } }
                                }
                                .padding().background(Color.white).cornerRadius(16)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                Text(String(localized: "次回の記録")).font(.subheadline).foregroundStyle(.secondary).padding(.leading, 4)
                                VStack(spacing: 16) {
                                    TextField(String(localized: "新しい水の重さ (任意)"), text: $nextStartWeight)
                                        .keyboardType(.decimalPad).focused($isInputFocused).monospacedDigit().customTextFieldStyle()
                                }
                                .padding().background(Color.white).cornerRadius(16)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                Text(String(localized: "環境")).font(.subheadline).foregroundStyle(.secondary).padding(.leading, 4)
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text(String(localized: "天気")).font(.subheadline).foregroundColor(.secondary)
                                        Spacer()
                                        if selectedWeather != nil { Button(String(localized: "クリア")) { selectedWeather = nil }.font(.caption).foregroundColor(Color.appMain) }
                                    }
                                    HStack(spacing: 12) {
                                        ForEach(WeatherOption.allCases, id: \.self) { option in
                                            WeatherButton(option: option, isSelected: selectedWeather == option) { selectedWeather = selectedWeather == option ? nil : option }
                                        }
                                        Spacer()
                                    }
                                    Divider()
                                    HStack {
                                        Text(String(localized: "室温")).font(.subheadline).foregroundColor(.secondary)
                                        Spacer()
                                        TextField(String(localized: "室温 (任意)"), text: $temperature)
                                            .keyboardType(.decimalPad).focused($isInputFocused).multilineTextAlignment(.trailing).frame(width: 120).monospacedDigit()
                                        Text("℃").foregroundColor(.secondary)
                                    }
                                }
                                .padding().background(Color.white).cornerRadius(16)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                Text(String(localized: "日時")).font(.subheadline).foregroundStyle(.secondary).padding(.leading, 4)
                                VStack {
                                    DatePicker(String(localized: "記録日時"), selection: $recordDate, displayedComponents: [.date, .hourAndMinute])
                                        .environment(\.locale, Locale.current)
                                }.padding().background(Color.white).cornerRadius(16)
                            }
                        }
                        .padding(.horizontal).padding(.top, 20).padding(.bottom, 180)
                    }
                }
                Button { saveFinish() } label: {
                    Text(String(localized: "記録を更新する")).fontWeight(.semibold).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56)
                        .background(canSave ? Color.appMain : Color.disabledButtonBackground).cornerRadius(.buttonCornerRadius)
                }
                .disabled(!canSave).padding(.horizontal, 20).padding(.bottom, 20)
            }
            .navigationTitle(String(localized: "回収する")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
            .alert(String(localized: "入力エラー"), isPresented: $showingValidationAlert) { Button("OK", role: .cancel) { } } message: { Text(validationMessage) }
        }
        .keyboardToolbar(focus: $isInputFocused)
    }
    
    private var canSave: Bool { !endWeight.isEmpty && Double(endWeight) != nil }
    
    private func saveFinish() {
        guard let weight = Double(endWeight) else { return }
        if weight > maxInputWeight { validationMessage = "回収時重量は10,000g以下にしてください"; showingValidationAlert = true; return }
        if let weightError = InputValidator.validateWeight(weight) { validationMessage = "回収時の重量: \(weightError)"; showingValidationAlert = true; return }
        let temp = temperature.isEmpty ? nil : Double(temperature)
        let weatherSymbol = selectedWeather?.sfSymbolName
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNextWeight = nextStartWeight.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNextWeight.isEmpty, let nextWeight = Double(trimmedNextWeight) {
            if nextWeight > maxInputWeight { validationMessage = "次回の重量は10,000g以下にしてください"; showingValidationAlert = true; return }
            if let nextWeightError = InputValidator.validateWeight(nextWeight) { validationMessage = "次回の重量: \(nextWeightError)"; showingValidationAlert = true; return }
            viewModel.finishAndRestartRecording(container: container, endWeight: weight, weatherCondition: weatherSymbol, temperature: temp, catCount: catCount, note: trimmedNote.isEmpty ? nil : trimmedNote, nextStartWeight: nextWeight, date: recordDate, modelContext: modelContext)
        } else {
            viewModel.finishRecording(container: container, endWeight: weight, weatherCondition: weatherSymbol, temperature: temp, catCount: catCount, note: trimmedNote.isEmpty ? nil : trimmedNote, date: recordDate, modelContext: modelContext)
        }
        dismiss()
    }
}

enum WeatherOption: String, CaseIterable {
    case sunny = "sun.max", cloudy = "cloud", rainy = "cloud.rain", snowy = "snowflake"
    var sfSymbolName: String { rawValue }
    var emoji: String {
        switch self { case .sunny: return "☀️"; case .cloudy: return "☁️"; case .rainy: return "☔️"; case .snowy: return "❄️" }
    }
}

struct WeatherButton: View {
    let option: WeatherOption; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(option.emoji).font(.title2).frame(width: 50, height: 50)
                .background(isSelected ? Color.appMain.opacity(0.2) : Color(.systemGray6))
                .cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.appMain : Color.clear, lineWidth: 2))
        }.buttonStyle(.plain)
    }
}

struct EditContainerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let container: ContainerMaster
    @Binding var editedName: String
    @Binding var editedEmptyWeight: String
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var showingDeleteConfirmation = false
    @FocusState private var isInputFocused: Bool
    let viewModel: RecordViewModel
    let settingsViewModel: SettingsViewModel
    let modelContext: ModelContext
    let onDelete: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.backgroundGray.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        Form {
                            Section {
                                TextField(String(localized: "器の名前"), text: $editedName).focused($isInputFocused)
                                TextField(String(localized: "空重量 (g) - 任意"), text: $editedEmptyWeight).keyboardType(.decimalPad).focused($isInputFocused).monospacedDigit()
                            } header: { Text(String(localized: "器の情報を編集")) }
                        }
                        .frame(height: 240)
                        Button(role: .destructive) { showingDeleteConfirmation = true } label: { Text(String(localized: "この器を削除する")).font(.body).foregroundColor(.red).frame(maxWidth: .infinity) }
                        .padding(.top, 20).padding(.bottom, 40)
                    }
                }
                Button { saveChanges() } label: {
                    Text(String(localized: "保存する")).fontWeight(.semibold).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56)
                        .background(editedName.isEmpty ? Color.disabledButtonBackground : Color.appMain).cornerRadius(.buttonCornerRadius)
                }
                .disabled(editedName.isEmpty).padding(.horizontal, 20).padding(.bottom, 20)
            }
            .navigationTitle(String(localized: "器を編集")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
            .alert(String(localized: "入力エラー"), isPresented: $showingValidationAlert) { Button("OK", role: .cancel) { } } message: { Text(validationMessage) }
            .alert(String(localized: "器を削除しますか？"), isPresented: $showingDeleteConfirmation) {
                Button(String(localized: "キャンセル"), role: .cancel) { }; Button(String(localized: "削除する"), role: .destructive) { deleteContainer() }
            } message: { Text(String(localized: "この操作は取り消せません。")) }
        }
        .keyboardToolbar(focus: $isInputFocused)
    }
    
    private func saveChanges() {
        if let nameError = InputValidator.validateName(editedName) { validationMessage = nameError; showingValidationAlert = true; return }
        let weight = editedEmptyWeight.isEmpty ? 0.0 : (Double(editedEmptyWeight) ?? 0.0)
        if weight > maxInputWeight { validationMessage = "空重量は10,000g以下にしてください"; showingValidationAlert = true; return }
        if let weightError = InputValidator.validateWeight(weight) { validationMessage = weightError; showingValidationAlert = true; return }
        viewModel.updateContainer(container: container, newName: editedName.trimmingCharacters(in: .whitespacesAndNewlines), newEmptyWeight: weight, modelContext: modelContext)
        dismiss()
    }
    
    private func deleteContainer() {
        settingsViewModel.deleteContainer(container, modelContext: modelContext)
        dismiss(); onDelete()
    }
}

struct RecordEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var record: WaterRecord
    @State private var tempStartTime: Date
    @State private var tempStartWeight: String
    @State private var tempEndTime: Date
    @State private var tempEndWeight: String
    @State private var showingDeleteAlert = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    init(record: WaterRecord) {
        self.record = record
        _tempStartTime = State(initialValue: record.startTime)
        _tempStartWeight = State(initialValue: String(Int(record.startWeight)))
        if let end = record.endTime { _tempEndTime = State(initialValue: end) } else { _tempEndTime = State(initialValue: Date()) }
        if let w = record.endWeight { _tempEndWeight = State(initialValue: String(Int(w))) } else { _tempEndWeight = State(initialValue: "") }
    }
    
    var isCollection: Bool { return record.endTime != nil }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.backgroundGray.ignoresSafeArea()
                Form {
                    Section(header: Text(String(localized: "設置データ"))) {
                        DatePicker(String(localized: "設置日時"), selection: $tempStartTime)
                        HStack { Text(String(localized: "設置時重量")); Spacer(); TextField("g", text: $tempStartWeight).keyboardType(.numberPad).multilineTextAlignment(.trailing); Text("g") }
                    }
                    if isCollection {
                        Section(header: Text(String(localized: "回収データ"))) {
                            DatePicker(String(localized: "回収日時"), selection: $tempEndTime)
                            HStack { Text(String(localized: "回収時重量")); Spacer(); TextField("g", text: $tempEndWeight).keyboardType(.numberPad).multilineTextAlignment(.trailing); Text("g") }
                        }
                    }
                    Section { Button(String(localized: "この記録を削除"), role: .destructive) { showingDeleteAlert = true } }
                }
                .padding(.bottom, 80)
                Button { saveChanges() } label: {
                    Text(String(localized: "保存する")).fontWeight(.semibold).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56).background(Color.appMain).cornerRadius(.buttonCornerRadius)
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
            .navigationTitle(String(localized: "記録を編集")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
            .alert(String(localized: "入力エラー"), isPresented: $showingValidationAlert) { Button("OK", role: .cancel) { } } message: { Text(validationMessage) }
            .alert(String(localized: "記録を削除しますか？"), isPresented: $showingDeleteAlert) {
                Button(String(localized: "キャンセル"), role: .cancel) {}; Button(String(localized: "削除"), role: .destructive) { deleteRecord() }
            } message: { Text(String(localized: "この操作は取り消せません。")) }
        }
    }
    
    private func saveChanges() {
        guard let startW = Double(tempStartWeight) else { return }
        if startW > maxInputWeight { validationMessage = "設置時重量は10,000g以下にしてください"; showingValidationAlert = true; return }
        if isCollection, let endW = Double(tempEndWeight) {
             if endW > maxInputWeight { validationMessage = "回収時重量は10,000g以下にしてください"; showingValidationAlert = true; return }
        }
        record.startTime = tempStartTime; record.startWeight = startW
        if isCollection {
            record.endTime = tempEndTime
            if let w = Double(tempEndWeight) { record.endWeight = w }
        }
        try? modelContext.save(); dismiss()
    }
    
    private func deleteRecord() {
        // 1. 必要なIDとContextを退避（オブジェクトそのものは触らない）
        let recordID = record.persistentModelID
        let context = modelContext
        
        // 2. 先に画面を閉じる（ユーザーには即座に反応）
        dismiss()
        
        // 3. 画面が完全に消え、親の再描画も終わった頃を見計らって削除
        Task { @MainActor in
            // 1.0秒待機（アニメーションと競合しない十分な時間）
            try? await Task.sleep(for: .seconds(1.0))
            
            // IDを使ってひっそりと削除
            if let targetRecord = context.model(for: recordID) as? WaterRecord {
                context.delete(targetRecord)
            }
        }
    }
}

struct ContainerDetailHeader: View {
    let container: ContainerMaster
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(container.name).font(.title2).fontWeight(.bold)
            Text("空重量: \(Int(container.emptyWeight))g").font(.subheadline).foregroundColor(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemBackground))
    }
}

struct ContainerHistoryList: View {
    let timelineItems: [TimelineItem]
    let historyRecords: [WaterRecord]
    let container: ContainerMaster
    let viewModel: RecordViewModel
    let historyViewModel: HistoryViewModel
    let modelContext: ModelContext
    let onTapRecord: (WaterRecord) -> Void
    
    private var groupedItems: [Date: [TimelineItem]] {
        Dictionary(grouping: timelineItems) { item in
            Calendar.current.startOfDay(for: item.date)
        }
    }
    
    private var sortedDates: [Date] {
        groupedItems.keys.sorted(by: >)
    }
    
    var body: some View {
        ZStack {
            Color.backgroundGray.ignoresSafeArea()
            if timelineItems.isEmpty {
                VStack(spacing: 12) { Image(systemName: "clock").font(.largeTitle).foregroundColor(.secondary); Text(String(localized: "履歴はありません")).font(.subheadline).foregroundColor(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(sortedDates, id: \.self) { date in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(historyViewModel.formatDate(date)).font(.subheadline).fontWeight(.bold).foregroundColor(.secondary).padding(.leading, 4)
                                VStack(spacing: 12) {
                                    ForEach(groupedItems[date] ?? []) { item in
                                        Button {
                                            let id = item.recordID
                                            // クラッシュ対策: modelContext.model(for:) の代わりに、すでにロード済みの historyRecords から検索する
                                            if let record = historyRecords.first(where: { $0.id == id }) {
                                                onTapRecord(record)
                                            }
                                        } label: {
                                            ContainerTimelineRow(item: item, container: container, viewModel: viewModel, historyViewModel: historyViewModel, modelContext: modelContext, isFirst: item.id == timelineItems.first?.id)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 20)
                }
            }
        }
    }
}

extension Double {
    var safeDisplayInt: Int {
        if self.isNaN || self.isInfinite { return 0 }
        if self > 999_999 { return 999_999 }
        if self < -999_999 { return -999_999 }
        return Int(self)
    }
}

struct ContainerTimelineRow: View {
    let item: TimelineItem
    let container: ContainerMaster
    let viewModel: RecordViewModel
    let historyViewModel: HistoryViewModel
    let modelContext: ModelContext
    let isFirst: Bool
    
    private var record: WaterRecord? { let id = item.recordID; return modelContext.model(for: id) as? WaterRecord }
    private var isAbnormal: Bool { guard let r = record else { return false }; return viewModel.isRecordAbnormal(r, modelContext: modelContext) }
    
    private var isRecording: Bool {
        guard let r = record else { return false }
        return r.endTime == nil
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(historyViewModel.formatTime(item.date)).font(.subheadline).foregroundColor(.secondary).frame(width: 50, alignment: .leading).monospacedDigit()
            HStack(spacing: 8) {
                Image(systemName: item.type == .setup ? "arrow.down.circle.fill" : (isAbnormal ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"))
                    .foregroundColor(item.type == .setup ? .appMain : (isAbnormal ? .alertOrange : .green)).font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.type == .setup ? (isFirst ? String(localized: "設置中") : String(localized: "設置")) : String(localized: "回収"))
                        .font(.body).fontWeight(isFirst ? .bold : .regular)
                    if item.type == .collection, let t = item.temperature { Text("\(Int(t))℃").font(.caption).foregroundColor(.secondary) }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if item.type == .setup { Text("\(item.weight.safeDisplayInt)g").monospacedDigit() }
                else if let amount = item.amount { Text("\(amount.safeDisplayInt)ml").fontWeight(.bold).monospacedDigit() }
            }
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary.opacity(0.5)).padding(.leading, 4).padding(.top, 4)
        }
        // ▼▼▼ 修正: commonShadow -> cardShadow ▼▼▼
        .padding().background(Color.white).cornerRadius(.cardCornerRadius).cardShadow()
        .overlay(
            RoundedRectangle(cornerRadius: .cardCornerRadius)
                .stroke(isRecording ? Color.appMain : Color.clear, lineWidth: 2)
        )
    }
}
