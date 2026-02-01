import Foundation
import SwiftData

/// スクリーンショット撮影用のダミーデータを生成するクラス
/// （リリースビルドにも含まれますが、開発用メニューからのみ呼び出されます）
#if DEBUG
final class DebugDataManager {
    @MainActor
    static func injectSampleData(context: ModelContext) {
        // 1. 既存データの削除
        try? context.delete(model: ContainerMaster.self)
        try? context.delete(model: WaterRecord.self)
        
        let container1 = ContainerMaster(name: "リビング", emptyWeight: 300, sortOrder: 0)
        let container2 = ContainerMaster(name: "寝室", emptyWeight: 250, sortOrder: 1)
        
        context.insert(container1)
        context.insert(container2)
        
        // 3. 過去30日分のデータを生成
        let calendar = Calendar.current
        let today = Date()
        
        // 天気候補
        let weatherConditions = ["sun.max.fill", "cloud.fill", "cloud.rain.fill", "cloud.sun.fill"]
        
        for i in 0..<30 {
            // 日付を遡る
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // 1日あたりの記録数（4〜6回）
            let recordCount = Int.random(in: 4...6)
            
            // その日のムラ（0.8〜1.2倍）
            let dailyFactor = Double.random(in: 0.8...1.2)
            
            for j in 0..<recordCount {
                // 時間を分散させる (8時〜22時)
                let hour = 8 + (14 * j / recordCount) + Int.random(in: 0...1)
                guard let recordTime = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...59), second: 0, of: date) else { continue }
                
                // 摂取量 (20〜50ml * ムラ)
                let baseAmount = Double.random(in: 20...50)
                let amount = baseAmount * dailyFactor
                
                // 記録を作成
                let targetContainer = Bool.random() ? container1 : container2
                let startWeight = targetContainer.emptyWeight + 200 // 仮の水量
                let endWeight = startWeight - amount
                
                let record = WaterRecord(
                    containerID: targetContainer.id,
                    startTime: recordTime,
                    startWeight: startWeight,
                    endTime: recordTime.addingTimeInterval(3600), // 1時間後
                    endWeight: endWeight,
                    catCount: 2, // きなこ、だいふく
                    weatherCondition: weatherConditions.randomElement(),
                    temperature: Double.random(in: 15...28),
                    container: targetContainer
                )
                
                context.insert(record)
            }
        }
        
        try? context.save()
        print("Sample data injected successfully.")
    }
}
#endif
