//
//  OnboardingView.swift
//  URUOI
//
//  Created by USER on 2026/01/06.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            Color.backgroundGray
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // スキップボタン
                HStack {
                    Spacer()
                    Button {
                        withAnimation {
                            hasSeenOnboarding = true
                        }
                    } label: {
                        Text("スキップ")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.top, 8)
                
                // スライドコンテンツ
                TabView(selection: $currentPage) {
                    // スライド1: イントロダクション
                    IntroductionSlide()
                        .tag(0)
                    
                    // スライド2: 記録の仕方
                    RecordingSlide()
                        .tag(1)
                    
                    // スライド3: 振り返り
                    AnalysisSlide()
                        .tag(2)
                    
                    // スライド4: スタート
                    StartSlide(hasSeenOnboarding: $hasSeenOnboarding)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - スライド1: イントロダクション
struct IntroductionSlide: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // アイコン
            Image(systemName: "drop.fill")
                .font(.system(size: 100))
                .foregroundColor(.appMain)
            
            VStack(spacing: 12) {
                // ⚠️ 修正: 猫 → ペット
                Text("ペットのお水を\n記録しよう")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                // ⚠️ 修正: 愛猫 → 大切なペット
                Text("毎日の飲水量を手軽に記録して、\n大切なペットの健康管理をサポートします。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - スライド2: 記録の仕方
struct RecordingSlide: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // タイトル
            VStack(spacing: 12) {
                Text("器ごとに簡単記録")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("『設置』と『回収』の2ステップ。\n実際の器と同じようにカードをタップするだけ。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 20)
            
            // 簡易版カードUI（ContainerCardのミニチュア）
            VStack(spacing: 12) {
                // アクティブな器のカード
                OnboardingContainerCard(
                    name: "白の大きい器",
                    isActive: true,
                    showTime: true
                )
                
                // 非アクティブな器のカード
                OnboardingContainerCard(
                    name: "緑の大きい器",
                    isActive: false,
                    showTime: false
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - オンボーディング用の簡易器カード
struct OnboardingContainerCard: View {
    let name: String
    let isActive: Bool
    let showTime: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .foregroundColor(isActive ? Color.appMain : Color.backgroundGray)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if showTime {
                    Text("2時間30分経過")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "pencil")
                .font(.caption)
                .foregroundColor(.appMain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? Color.appMain.opacity(0.1) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.appMain : Color.gray.opacity(0.2), lineWidth: isActive ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - スライド3: 振り返り
struct AnalysisSlide: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // タイトル
            VStack(spacing: 12) {
                Text("グラフで変化を把握")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("日々の飲水量や傾向をグラフで確認。\n体調変化の気づきに役立ちます。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 20)
            
            // グラフのイラスト
            OnboardingChartIllustration()
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - オンボーディング用グラフイラスト
struct OnboardingChartIllustration: View {
    let barHeights: [CGFloat] = [0.5, 0.7, 0.6, 0.9, 0.8, 0.7, 1.0]
    let maxHeight: CGFloat = 150
    
    var body: some View {
        VStack(spacing: 16) {
            // グラフアイコン
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.appMain)
            
            // 棒グラフのイラスト
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index == 6 ? Color.appMain : Color.appMain.opacity(0.5))
                            .frame(width: 30, height: maxHeight * barHeights[index])
                        
                        Text(dayLabel(for: index))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(.cardCornerRadius)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    private func dayLabel(for index: Int) -> String {
        let days = ["月", "火", "水", "木", "金", "土", "日"]
        return days[index]
    }
}

// MARK: - スライド4: スタート
struct StartSlide: View {
    @Binding var hasSeenOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // アイコン
            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundColor(.appMain)
            
            VStack(spacing: 12) {
                Text("さあ、はじめましょう")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("器を登録して、今日から記録を始めましょう。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Spacer()
            
            // はじめるボタン
            Button {
                withAnimation {
                    hasSeenOnboarding = true
                }
            } label: {
                Text("はじめる")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.appMain)
                    .cornerRadius(.buttonCornerRadius)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
