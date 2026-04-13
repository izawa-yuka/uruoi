//
//  OnboardingStep9View.swift
//  URUOI
//

import SwiftUI

struct OnboardingStep9View: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            Color.backgroundGray
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // チェックマークアイコン
                ZStack {
                    Circle()
                        .fill(Color(hex: "#41C39A").opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(Color(hex: "#41C39A"))
                }

                // タイトル・サブテキスト
                VStack(spacing: 12) {
                    Text("準備完了！")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("設定が完了しました。\nさっそくペットの飲水量を記録しましょう。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                // 開始ボタン
                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("さっそく記録する")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(hex: "#41C39A"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    OnboardingStep9View()
}
