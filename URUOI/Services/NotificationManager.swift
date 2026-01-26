//
//  NotificationManager.swift
//  URUOI
//
//  Created by USER on 2026/01/08.
//

import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        // 【重要】アプリ起動中でも通知を受け取れるようにデリゲートを設定
        UNUserNotificationCenter.current().delegate = self
    }
    
    /// 通知の許可をリクエスト
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知許可リクエストエラー: \(error)")
            } else {
                print("通知許可: \(granted)")
            }
        }
    }
    
    /// 水換えリマインダーをスケジュール
    /// - Parameters:
    ///   - containerID: 器のID
    ///   - containerName: 器の名前
    ///   - days: 何日後に通知するか
    ///   - startDate: 設置した日時（ここを基準に計算します）
    func scheduleWaterReminder(containerID: UUID, containerName: String, days: Int, startDate: Date) {
        // テストのため、daysが0以下でもガードしない（呼び出し元で制御する）
        
        // 1. 本来通知すべき日時（設置日 + 指定日数）を計算
        guard let targetDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) else {
            print("通知日時の計算に失敗しました")
            return
        }
        
        // 2. 「今」から「ターゲット日時」までの秒数を計算
        var timeInterval = targetDate.timeIntervalSinceNow
        
        // もし期限を過ぎていたら、スキップせずに「1秒後（即時）」に通知する
        if timeInterval <= 0 {
            print("⚠️ 通知予定時刻(\(targetDate))を過ぎているため、即時通知モードに切り替えます")
            timeInterval = 1.0 // 1秒後に設定
        }
        
        let content = UNMutableNotificationContent()
        content.title = "お水交換のお知らせ 💧"
        content.body = "「\(containerName)」のお水が古くなっているかもしれません。新鮮なお水に変えてあげましょう🐱"
        content.sound = .default
        
        // 3. タイマーをセット
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: containerID.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知スケジュールエラー: \(error)")
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd HH:mm"
                // ログの内容も分かりやすく分岐
                if timeInterval == 1.0 {
                    print("🔔 通知セット完了(即時): \(containerName) - 期限切れのためすぐ通知します")
                } else {
                    print("🔔 通知セット完了(予約): \(containerName) - 予定時刻: \(formatter.string(from: targetDate))")
                }
            }
        }
    }
    
    /// スケジュールされた通知をキャンセル
    func cancelReminder(containerID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [containerID.uuidString])
        print("通知キャンセル: \(containerID)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    // 【重要】アプリがフォアグラウンド（画面表示中）にある時に通知が来た場合の処理
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // バナー、音、リスト表示を許可する
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
