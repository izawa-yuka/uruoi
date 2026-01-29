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
    
    enum PlanType {
        case monthly
        case yearly
        
        var price: String {
            switch self {
            case .monthly: return "¥180"
            case .yearly: return "¥1,800"
            }
        }
        
        // 月額換算価格（年間プラン用）
        var monthlyEquivalent: String? {
            switch self {
            case .monthly: return nil
            case .yearly: return "¥150" // 1800 ÷ 12 = 150
            }
        }
        
        var period: String {
            switch self {
            case .monthly: return "月額"
            case .yearly: return "年額"
            }
        }
        
        var badge: String? {
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
                            .foregroundColor(.primary)
                        
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
                            isSelected: selectedPlan == .yearly
                        ) {
                            selectedPlan = .yearly
                        }

                        // 月額プラン（下部）
                        PlanCard(
                            planType: .monthly,
                            isSelected: selectedPlan == .monthly
                        ) {
                            selectedPlan = .monthly
                        }
                    }
                    .padding(.horizontal)
                    
                    // 購入ボタン
                    VStack(spacing: 12) {
                        Button {
                            // TODO: StoreKitでの購入処理を実装
                            // storeManager.purchasePremium(plan: selectedPlan)
                            #if DEBUG
                            // デバッグ用: フラグを切り替え
                            isProMember = true
                            dismiss()
                            #endif
                        } label: {
                            // 【修正】文言を統一
                            Text("もっと！URUOIプランを購入")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.appMain)
                                .cornerRadius(.buttonCornerRadius)
                        }
                        
                        // マイクロコピー: 安心感を与える
                        Text("いつでもキャンセル可能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button {
                            // TODO: 復元処理を実装
                            // storeManager.restorePurchases()
                        } label: {
                            Text("購入を復元")
                                .font(.subheadline)
                                .foregroundColor(.appMain)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 注意事項
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 支払いはApple IDアカウントに請求されます")
                        Text("• 購入の確認時に課金されます")
                        Text("• 自動更新の終了は、購読期間の終了24時間前までに設定から行えます")
                        Text("• 詳細は利用規約・プライバシーポリシーをご確認ください")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
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
        }
    }
}

// MARK: - PlanCard
struct PlanCard: View {
    let planType: PremiumIntroductionView.PlanType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(planType.period)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // 価格表示（年間プランは月額換算を強調）
                        if let monthlyEquivalent = planType.monthlyEquivalent {
                            // 年間プラン: 月額換算を大きく表示
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(monthlyEquivalent)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.appMain)
                                    Text("/ 月")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("年額 \(planType.price)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // 月額プラン: そのまま表示
                            Text(planType.price)
                                .font(.title2)
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
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.appMain)
                .frame(width: 40) // アイコンの幅を固定して縦列を揃える
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
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