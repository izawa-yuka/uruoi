//
//  PremiumIntroductionView.swift
//  URUOI
//
//  Created by USER on 2026/01/07.
//

import SwiftUI

struct PremiumIntroductionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isProMember") private var isProMember: Bool = false
    @State private var selectedPlan: PlanType = .yearly // 初期値を年間プランに変更
    @State private var storeManager = StoreManager.shared
    @State private var isRestoring = false
    @State private var showingRestoreAlert = false
    @State private var restoreAlertTitle = String(localized: "復元完了")
    @State private var restoreAlertMessage = String(localized: "購入履歴の確認が完了しました。有効な購入がある場合は反映されています。")
    
    enum PlanType {
        case monthly
        case yearly
        
        var productID: String {
            switch self {
            case .monthly: return StoreManager.ProductID.monthly
            case .yearly: return StoreManager.ProductID.yearly
            }
        }
        
        var period: LocalizedStringKey {
            switch self {
            case .monthly: return "月額"
            case .yearly: return "年額"
            }
        }
        
        var badge: LocalizedStringKey? {
            switch self {
            case .monthly: return nil
            case .yearly: return "2ヶ月分お得"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // ヘッダーイメージ
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 80))
                            .foregroundColor(.appMain)
                        
                        Text("もっと！URUOI プラン")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.appMain)
                        
                        Text("愛猫の健康変化にいち早く気づこう")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal)
                    
                    // 機能紹介
                    // 【修正】alignment: .leading を追加してアイコンを左揃えに
                    VStack(alignment: .leading, spacing: 24) {
                        FeatureRow(
                            icon: "person.2.circle.fill",
                            title: "家族共有機能",
                            description: "リアルタイムで記録を同期。「あれ？お水かえたっけ？」の心配がなくなります。"
                        )
                        
                        FeatureRow(
                            icon: "chart.bar.fill",
                            title: "分析グラフの閲覧",
                            description: "健康管理の要"
                        )
                        
                        FeatureRow(
                            icon: "bell.fill",
                            title: "水換えリマインド通知",
                            description: "継続のサポート"
                        )
                        
                        FeatureRow(
                            icon: "square.stack.3d.up.fill",
                            title: "器の登録数 無制限",
                            description: "多頭飼いも安心"
                        )
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity) // 幅いっぱいに広げて左揃えを有効化
                    
                    // プラン選択
                    VStack(spacing: 16) {
                        // 年額プラン（先に表示）
                        PlanCard(
                            planType: .yearly,
                            price: storeManager.displayPrice(for: StoreManager.ProductID.yearly),
                            isSelected: selectedPlan == .yearly
                        ) {
                            selectedPlan = .yearly
                        }

                        // 月額プラン（下部）
                        PlanCard(
                            planType: .monthly,
                            price: storeManager.displayPrice(for: StoreManager.ProductID.monthly),
                            isSelected: selectedPlan == .monthly
                        ) {
                            selectedPlan = .monthly
                        }
                    }
                    .padding(.horizontal)

                    if storeManager.isLoadingProducts {
                        ProgressView("商品情報を読み込み中")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if storeManager.productLoadError != nil {
                        Text("商品情報を取得できませんでした。通信状態を確認してください。")
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // 買い切りプラン（Lifetime）
                    Button {
                        Task {
                            if await storeManager.purchaseLifetime() {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ずっと！URUOIプラン")
                                    .font(.headline)
                                    .foregroundColor(.appMain)
                                
	                                HStack(alignment: .firstTextBaseline, spacing: 4) {
	                                    Text(storeManager.displayPrice(for: StoreManager.ProductID.lifetime))
	                                        .font(.title)
	                                        .fontWeight(.bold)
	                                        .foregroundColor(.appMain)
                                    
                                    Text("(一括払い)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
	                                Text("一度の購入で継続利用できます")
	                                    .font(.caption)
	                                    .foregroundColor(.secondary)
	                            }
                            
                            Spacer()
                        }
                        .padding(20) // PlanCardのパディングに合わせる
                        .background(Color(.systemBackground))
                        .cornerRadius(.cardCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: .cardCornerRadius)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .disabled(!storeManager.isProductLoaded(StoreManager.ProductID.lifetime))
                    
                    // 購入ボタン
                    VStack(spacing: 12) {
	                        Button {
	                            Task {
	                                if await storeManager.purchaseSubscription(planId: selectedPlan.productID) {
	                                    dismiss()
	                                }
	                            }

                        } label: {
                            // 【修正】文言を統一
                            Text("もっと！URUOIプランを購入")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(storeManager.isProductLoaded(selectedPlan.productID) ? Color.appMain : Color.disabledButtonBackground)
                                .cornerRadius(.buttonCornerRadius)
	                        }
	                        .disabled(!storeManager.isProductLoaded(selectedPlan.productID))
                        
                        // マイクロコピー: 安心感を与える
                        Text("いつでもキャンセル可能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button {
                            isRestoring = true
                            Task {
                                do {
                                    let result = try await storeManager.restorePurchases()
                                    switch result {
                                    case .restored:
                                        restoreAlertTitle = String(localized: "復元完了")
                                        restoreAlertMessage = String(localized: "購入情報を反映しました。")
                                    case .noPurchase:
                                        restoreAlertTitle = String(localized: "購入履歴なし")
                                        restoreAlertMessage = String(localized: "有効な購入履歴が見つかりませんでした。")
                                    }
                                } catch {
                                    print("Restore failed: \(error)")
                                    restoreAlertTitle = String(localized: "復元に失敗しました")
                                    restoreAlertMessage = String(localized: "通信状態を確認して、もう一度お試しください。")
                                }
                                isRestoring = false
                                showingRestoreAlert = true
                            }
                        } label: {
                            if isRestoring {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("以前購入された方はこちら（復元）")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(isRestoring)
                    }
                    .padding(.horizontal)
                    
                    // 注意事項
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 支払いはApple IDアカウントに請求されます")
                        Text("• 購入の確認時に課金されます")
                        Text("• 自動更新の終了は、購読期間の終了24時間前までに設定から行えます")
                        Text("• 詳細は[利用規約](\(AppConfig.termsURL))・[プライバシーポリシー](\(AppConfig.privacyPolicyURL))をご確認ください")
                            .tint(.appMain) // リンクの色を指定
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    // 利用規約・プライバシーポリシー
                    HStack(spacing: 24) {
                        Link("利用規約", destination: AppConfig.termsURL)
                        Link("プライバシーポリシー", destination: AppConfig.privacyPolicyURL)
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
	            .alert(restoreAlertTitle, isPresented: $showingRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
	                Text(restoreAlertMessage)
	            }
	            .task {
	                await storeManager.loadProducts()
	            }
	        }
	    }
}

// MARK: - PlanCard
struct PlanCard: View {
    let planType: PremiumIntroductionView.PlanType
    let price: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(planType.period)
                            .font(.headline)
                            .foregroundColor(.appMain)
                        
                        // 価格表示（実際の決済総額を最も目立たせる）
                        if planType == .yearly {
                            // 年間プラン: 実際の決済総額（年額）を大きく表示
                            VStack(alignment: .leading, spacing: 4) {
                                Text(price)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.appMain)
                                
                                Text("年額プラン")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // 月額プラン: そのまま表示
                            Text(price)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.appMain)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .appMain : .gray)
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(.cardCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: .cardCornerRadius)
                        .stroke(isSelected ? Color.appMain : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: isSelected ? Color.appMain.opacity(0.2) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                // バッジを右上に配置（年間プランのみ）
                if let badge = planType.badge {
                    Text(badge)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "FF812D"))
                        .clipShape(Capsule())
                        .offset(x: -12, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FeatureRow
struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.appMain)
                .frame(width: 40) // アイコンの幅を固定して縦列を揃える
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.appMain)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
        }
    }
}

#Preview {
    PremiumIntroductionView()
}
