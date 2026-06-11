import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // タイトル
                    Text("アップデートのお知らせ")
                        .font(.title) // 文字サイズを調整して収まりやすく
                        .fontWeight(.bold)
                        .padding(.top, 50)
                        .multilineTextAlignment(.center)
                    
                    // はじめの挨拶
                    Text("いつもURUOIをご利用いただきありがとうございます\n今回のアップデート内容は以下の通りです。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    
                    // アップデート内容リスト
                    VStack(alignment: .leading, spacing: 28) {
                        featureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "直近7日間の平均飲水量を改善",
                            description: "毎日水を交換しない場合でも、複数日分の記録を日ごとの飲水量として扱い、より実態に近い平均を確認できるようになりました。"
                        )

                        featureRow(
                            icon: "scalemass.fill",
                            title: "回収時の器の重さを確認しやすく",
                            description: "回収時に入力した器の重さを、履歴や記録の詳細で確認しやすくしました。"
                        )

                        featureRow(
                            icon: "wrench.adjustable.fill",
                            title: "その他、軽微なバグ修正",
                            description: "アプリをより安定してご利用いただけるよう、細かな不具合を修正しました。"
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            
            // 下部ボタンエリア
            VStack {
                Button(action: {
                    onContinue()
                    dismiss()
                }) {
                    Text("続ける")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appMain)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(Color(UIColor.systemBackground))
        }
    }
    
    // 新機能の行コンポーネント
    // LocalizedStringKeyを受け取るように変更して、多言語対応しやすくしました
    private func featureRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.appMain)
                .frame(width: 40)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WhatsNewView(onContinue: {})
}
