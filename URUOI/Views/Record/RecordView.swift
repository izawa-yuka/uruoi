//
//  RecordView.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = RecordViewModel()
    @Query(filter: #Predicate<ContainerMaster> { !$0.isArchived }, sort: [SortDescriptor(\ContainerMaster.sortOrder), SortDescriptor(\ContainerMaster.createdAt)]) private var containers: [ContainerMaster]
    @Query(sort: \WaterRecord.startTime) private var allRecords: [WaterRecord]
    
    // 詳細画面を制御する変数
    @State private var selectedContainer: ContainerMaster?
    
    @State private var showingAddContainerSheet = false
    @State private var showingProAlert = false
    @State private var showingPremiumIntro = false
    @State private var showingDismissAlertConfirmation = false
    @State private var showingReorderSheet = false
    @AppStorage("isProMember") private var isProMember: Bool = false
    
    private var activeContainersCount: Int {
        containers.filter { !$0.isArchived }.count
    }
    
    private let freeUserLimit = 5
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGray
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ヘッダーエリア
                    HStack(alignment: .center, spacing: 16) {
                        CommonHeaderView(weeklyAveragePerCat: viewModel.weeklyAveragePerCat)
                            .id("header-\(viewModel.lastUpdateTimestamp.timeIntervalSince1970)")
                        
                        Spacer()
                        
                        HStack(spacing: 20) {
                            Button { showingReorderSheet = true } label: {
                                Image(systemName: "arrow.up.arrow.down").font(.title3).foregroundColor(.gray)
                            }
                            
                            Button {
                                if !isProMember && activeContainersCount >= freeUserLimit { showingProAlert = true }
                                else { showingAddContainerSheet = true }
                            } label: {
                                Image(systemName: "plus").font(.title3).fontWeight(.medium).foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    if containers.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "note.text").font(.system(size: 60)).foregroundColor(.secondary)
                            Text("器がまだありません").font(.headline).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                if viewModel.isAlert {
                                    AlertCard(message: viewModel.alertMessage, onDismiss: { showingDismissAlertConfirmation = true })
                                        .padding(.horizontal)
                                        .id("alert-\(viewModel.lastUpdateTimestamp.timeIntervalSince1970)")
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(containers) { container in
                                        ContainerCard(
                                            container: container,
                                            isActive: viewModel.isContainerActive(container: container, modelContext: modelContext),
                                            isInAlert: viewModel.isContainerInAlertState(container: container, modelContext: modelContext),
                                            viewModel: viewModel,
                                            modelContext: modelContext,
                                            onTap: { selectedContainer = container }
                                        )
                                        .id("\(container.id)-\(viewModel.lastUpdateTimestamp.timeIntervalSince1970)")
                                    }
                                }
                                .padding(.horizontal)
                                Spacer().frame(height: 40)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline).navigationBarHidden(true)
            
            .sheet(item: $selectedContainer, onDismiss: {
                viewModel.refreshActiveRecords(using: modelContext)
                viewModel.checkHealthAlert(using: modelContext)
                viewModel.calculateWeeklyAverage(using: modelContext)
            }) { container in
                ContainerDetailView(container: container)
            }
            .sheet(isPresented: $showingAddContainerSheet, onDismiss: {
                viewModel.refreshActiveRecords(using: modelContext)
                viewModel.checkHealthAlert(using: modelContext)
                viewModel.calculateWeeklyAverage(using: modelContext)
            }) {
                AddContainerSheet(viewModel: SettingsViewModel(), modelContext: modelContext)
                    .presentationDetents([.medium]).presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingReorderSheet) {
                ReorderContainersSheet(containers: containers, modelContext: modelContext)
                    // ▼▼▼ 修正: 最初から全画面で開くように変更 ▼▼▼
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingPremiumIntro) { PremiumIntroductionView() }
            .alert("登録数の上限です", isPresented: $showingProAlert) {
                Button("閉じる", role: .cancel) { }; Button("もっと！URUOIプランを見る") { showingPremiumIntro = true }
            } message: {
                Text("無料プランでは最大\(freeUserLimit)つまで登録できます。\n新しい器を追加するには、リストから不要な器を選択し、詳細画面から削除してください。またはもっと！URUOIプランへのアップグレードをご検討ください。")
            }
            .alert("アラートを非表示にしますか？", isPresented: $showingDismissAlertConfirmation) {
                Button("キャンセル", role: .cancel) { }; Button("非表示にする", role: .destructive) { viewModel.dismissAlert() }
            } message: { Text("このアラートを非表示にします。水分摂取量が正常範囲に戻るまで再表示されません。") }
            .alert("エラーが発生しました", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { viewModel.clearError() }
            } message: { if let errorMessage = viewModel.lastError { Text(errorMessage) } }
            .onAppear {
                viewModel.setModelContext(modelContext)
                viewModel.checkHealthAlert(using: modelContext)
                viewModel.calculateWeeklyAverage(using: modelContext)
                viewModel.triggerUIUpdate()
            }
            .onChange(of: allRecords) { _, _ in
                viewModel.refreshActiveRecords(using: modelContext)
                viewModel.checkHealthAlert(using: modelContext)
                viewModel.calculateWeeklyAverage(using: modelContext)
            }
            .onChange(of: viewModel.lastUpdateTimestamp) { _, _ in
                viewModel.checkHealthAlert(using: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.triggerUIUpdate()
                }
            }
        }
    }
}

// MARK: - ContainerCard
struct ContainerCard: View {
    let container: ContainerMaster
    let isActive: Bool
    let isInAlert: Bool
    let viewModel: RecordViewModel
    let modelContext: ModelContext
    let onTap: () -> Void
    
    var body: some View {
        // 色判定: アクティブならViewModelから取得、そうでなければグレー
        let statusColor = isActive ? viewModel.getWaterStatusColor(for: container) : Color.gray
        
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "drop.fill")
                    .foregroundColor(statusColor)
                    .font(.system(size: 32))
                    .frame(width: 48, height: 48)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(container.name).font(.headline).foregroundStyle(Color.primary)
                    HStack(spacing: 8) {
                        if isActive {
                            if let elapsed = viewModel.getElapsedTime(for: container, modelContext: modelContext) {
                                Text(elapsed).font(.caption).foregroundStyle(Color.secondary).monospacedDigit()
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundColor(.appMain)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: .cardCornerRadius)
                    .stroke(isInAlert ? Color.alertOrange : (isActive ? Color.appMain : Color.clear), lineWidth: (isInAlert || isActive) ? 2 : 0)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AlertCard
struct AlertCard: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.alertOrange).font(.title3)
            Text(message).font(.subheadline).foregroundColor(.primary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary).font(.title3)
            }.buttonStyle(.plain)
        }
        .padding().background(Color.alertOrange.opacity(0.1)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.alertOrange.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - ReorderContainersSheet (修正版)
struct ReorderContainersSheet: View {
    let containers: [ContainerMaster]
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editableContainers: [ContainerMaster] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(editableContainers, id: \.id) { container in
                        HStack {
                            Image(systemName: "line.3.horizontal").foregroundColor(.secondary)
                            Text(container.name).font(.body)
                            Spacer()
                        }
                    }
                    .onMove { source, destination in editableContainers.move(fromOffsets: source, toOffset: destination) }
                } header: {
                    Text("長押しで並び替え")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.backgroundGray)
            // ▼▼▼ 修正: safeAreaInsetを使用して、リストのコンテンツがボタンに隠れないように自動調整 ▼▼▼
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Button {
                        saveOrder()
                    } label: {
                        Text("保存する")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.appMain)
                            .cornerRadius(.buttonCornerRadius)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .background(Color.backgroundGray) // リストが透けないように背景色を指定
            }
            // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
            .navigationTitle("器の並び替え").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .onAppear { editableContainers = containers }
        }
    }
    
    private func saveOrder() {
        for (index, container) in editableContainers.enumerated() { container.sortOrder = index }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Common Shadow Extension (Renamed)
extension View {
    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.07), radius: 10, x: 1, y: 4)
    }
}
