//
//  CommonHeaderView.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import SwiftUI

struct CommonHeaderView: View {
    let weeklyAveragePerCat: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // 水滴アイコン
            Image(systemName: "drop.fill")
                .font(.title3)
                .foregroundColor(.appMain)
                .padding(10)
                .background(Color.appMain.opacity(0.1))
                .clipShape(Circle())
            
            // テキスト情報（左揃え）
            VStack(alignment: .leading, spacing: 2) {
                Text("平均 (7日間)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(weeklyAveragePerCat))")
                        .font(.system(size: 24, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.appMain)
                    
                    Text("ml")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text("/匹")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(16)
        // 影（shadow）と枠線は削除済み
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemGroupedBackground)
        CommonHeaderView(weeklyAveragePerCat: 125.5)
    }
}
