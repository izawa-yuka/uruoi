//
//  OnboardingRecordingAnimationView.swift
//  URUOI
//
//  「設置・回収」フローをアニメーションで説明するオンボーディング用デモビュー。
//  spec: animation_spec (6秒ループ、6フェーズ)

import SwiftUI

// MARK: - Main Animation View

struct OnboardingRecordingAnimationView: View {

    // ── カード状態 ──────────────────────────────────────
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOpacity: Double = 1.0
    @State private var borderOpacity: Double = 0

    // ── アイコン・テキスト ─────────────────────────────
    @State private var dropIconFilled = false
    @State private var dropIconColor = Color(hex: "#8A8A8E")
    @State private var mainValue = "未設置"
    @State private var mainValueColor = Color(hex: "#000000")
    @State private var subText = "タップして開始"

    // ── カーソル ───────────────────────────────────────
    @State private var cursorOpacity: Double = 0
    @State private var cursorScale: CGFloat = 1.0

    // ── 水アニメーション ───────────────────────────────
    @State private var waterOpacity: Double = 0
    @State private var waterLevel: CGFloat = 0.82

    // ── 結果ポップアップ ───────────────────────────────
    @State private var popupOpacity: Double = 0
    @State private var popupOffset: CGFloat = 8

    // ── ループ管理 ─────────────────────────────────────
    @State private var animTask: Task<Void, Never>? = nil

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {

            // ポップアップ用の予約エリア（カード上部）
            ZStack {
                Text("+ 50ml")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "#1670BB"))
                    .opacity(popupOpacity)
                    .offset(y: popupOffset)
            }
            .frame(height: 36)

            // カード + カーソル
            // HStack をサイズの基準にして、波アニメーションは .background で乗せる
            // （ZStack だと Shape が親の高さを全て埋めてしまうため）
            HStack(spacing: 14) {

                // 水滴アイコン
                Image(systemName: dropIconFilled ? "drop.fill" : "drop")
                    .font(.system(size: 26))
                    .foregroundColor(dropIconColor)
                    .animation(.easeInOut(duration: 0.25), value: dropIconColor)
                    .frame(width: 40)

                // 名前・数値・経過時間
                VStack(alignment: .leading, spacing: 3) {
                    Text("白の大きい器")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#000000"))

                    Text(mainValue)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(mainValueColor)
                        .animation(.easeInOut(duration: 0.15), value: mainValueColor)
                        .monospacedDigit()

                    Text(subText)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color(hex: "#8A8A8E"))
                        .id(subText)                   // テキスト変化をトランジションで表現
                        .transition(.opacity)
                }

                Spacer()

                // 鉛筆アイコン
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#8A8A8E"))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                // ── 水波アニメーション（HStack の高さに合わせて描画）──
                VesselWaveView(level: waterLevel)
                    .opacity(waterOpacity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .background(Color.white)
            .cornerRadius(16)
            .overlay {
                // ── 枠線 ──────────────────────────────────────────────
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#1670BB"), lineWidth: 2)
                    .opacity(borderOpacity)
                    .animation(.easeInOut(duration: 0.3), value: borderOpacity)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            .overlay(alignment: .bottomTrailing) {
                // タップカーソル（カード右下）
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(hex: "#6E6E73"))
                    .opacity(cursorOpacity)
                    .scaleEffect(cursorScale)
                    .offset(x: -12, y: -12)
            }
        }
        .onAppear { startLoop() }
        .onDisappear { animTask?.cancel() }
    }

    // MARK: - Animation Loop

    private func startLoop() {
        animTask?.cancel()
        animTask = Task { @MainActor in
            while !Task.isCancelled {
                await cycle()
            }
        }
    }

    @MainActor
    private func cycle() async {

        // ── Phase 1: Idle (0.0–0.5s) ──────────────────────────────
        resetState()
        await sleep(500)
        guard !Task.isCancelled else { return }

        // ── Phase 2: 設置アクション (0.5–1.5s) ────────────────────
        // カーソル登場
        withAnimation(.easeIn(duration: 0.2)) { cursorOpacity = 1 }
        await sleep(350)
        guard !Task.isCancelled else { return }

        // タップ
        await tapAnimation()

        // カードをアクティブ化
        withAnimation(.easeInOut(duration: 0.25)) {
            borderOpacity = 1
            dropIconColor  = Color(hex: "#1670BB")
            dropIconFilled = true
            waterOpacity   = 0.22
        }
        withAnimation(.easeInOut(duration: 0.15)) { subText = "0分経過" }

        // 0g → 300g カウントアップ
        await animateValue(from: 0, to: 300, steps: 10, ms: 60)
        guard !Task.isCancelled else { return }

        // カーソル退場
        withAnimation(.easeOut(duration: 0.2)) { cursorOpacity = 0 }
        await sleep(150)
        guard !Task.isCancelled else { return }

        // ── Phase 3: 時間経過 (1.5–3.5s) ──────────────────────────
        withAnimation(.easeInOut(duration: 1.2)) { waterLevel = 0.52 }

        let timeLabels = ["10分経過", "30分経過", "1時間経過", "2時間経過"]
        for label in timeLabels {
            withAnimation(.easeInOut(duration: 0.2)) { subText = label }
            await sleep(500)
            guard !Task.isCancelled else { return }
        }

        // ── Phase 4: 回収アクション (3.5–4.5s) ────────────────────
        withAnimation(.easeOut(duration: 0.3)) { waterOpacity = 0 }

        // カーソル登場
        withAnimation(.easeIn(duration: 0.2)) { cursorOpacity = 1 }
        await sleep(350)
        guard !Task.isCancelled else { return }

        // タップ
        await tapAnimation()

        // 300g → 250g カウントダウン
        await animateValue(from: 300, to: 250, steps: 8, ms: 60)
        guard !Task.isCancelled else { return }

        // カーソル退場
        withAnimation(.easeOut(duration: 0.2)) { cursorOpacity = 0 }
        await sleep(150)
        guard !Task.isCancelled else { return }

        // ── Phase 5: 記録結果 (4.5–5.5s) ──────────────────────────
        withAnimation(.easeInOut(duration: 0.25)) {
            borderOpacity  = 0
            dropIconColor  = Color(hex: "#8A8A8E")
            dropIconFilled = false
        }

        // "+ 50ml" ポップアップ
        popupOffset  = 8
        popupOpacity = 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
            popupOpacity = 1
            popupOffset  = -18
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            mainValueColor = Color(hex: "#1670BB")
        }
        withAnimation(.easeInOut(duration: 0.2)) { subText = "記録完了！" }

        await sleep(950)
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.25)) { popupOpacity = 0 }

        // ── Phase 6: リセット (5.5–6.0s) ──────────────────────────
        await sleep(200)
        withAnimation(.easeOut(duration: 0.25)) { cardOpacity = 0 }
        await sleep(300)
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.25)) { cardOpacity = 1 }
        await sleep(300)
    }

    // MARK: - Helpers

    @MainActor
    private func tapAnimation() async {
        withAnimation(.easeIn(duration: 0.1)) {
            cursorScale = 0.82
            cardScale   = 0.97
        }
        await sleep(110)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            cursorScale = 1.0
            cardScale   = 1.0
        }
        await sleep(180)
    }

    @MainActor
    private func animateValue(from start: Int, to end: Int, steps: Int, ms: Int) async {
        for i in 1...steps {
            guard !Task.isCancelled else { return }
            let v = start + Int(Double(end - start) * Double(i) / Double(steps))
            mainValue = "\(v)g"
            await sleep(ms)
        }
    }

    private func sleep(_ ms: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
    }

    private func resetState() {
        cardScale      = 1.0
        cardOpacity    = 1.0
        borderOpacity  = 0
        dropIconFilled = false
        dropIconColor  = Color(hex: "#8A8A8E")
        mainValue      = "未設置"
        mainValueColor = Color(hex: "#000000")
        subText        = "タップして開始"
        cursorOpacity  = 0
        cursorScale    = 1.0
        waterOpacity   = 0
        waterLevel     = 0.82
        popupOpacity   = 0
        popupOffset    = 8
    }
}

// MARK: - Wave Background

private struct VesselWaveView: View {
    let level: CGFloat
    @State private var phase: Double = 0

    var body: some View {
        WaveShape(phase: phase, level: level)
            .fill(Color(hex: "#1670BB").opacity(0.13))
            .animation(.easeInOut(duration: 1.2), value: level)
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
    }
}

private struct WaveShape: Shape {
    var phase: Double
    var level: CGFloat

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(phase, level) }
        set { phase = newValue.first; level = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amplitude: CGFloat = 5
        let yBase = rect.height * (1 - level)

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: yBase))

        for i in stride(from: 0.0, through: Double(rect.width), by: 2.0) {
            let normalizedX = i / Double(rect.width)
            let y = yBase + sin(normalizedX * .pi * 4 + phase) * amplitude
            path.addLine(to: CGPoint(x: CGFloat(i), y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: "#F0F0F5").ignoresSafeArea()
        OnboardingRecordingAnimationView()
            .padding(.horizontal, 32)
    }
}
