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
        // 権限チェック
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                print("⚠️ 通知権限がありません。通知はスケジュールされませんでした。")
                return
            }
            
            // 1. 本来通知すべき日時（設置日 + 指定日数）を計算
            guard let targetDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) else {
                print("通知日時の計算に失敗しました")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "お水交換のお知らせ 💧"
            content.body = "「\(containerName)」のお水が古くなっているかもしれません。新鮮なお水に変えてあげましょう"
            content.sound = .default
            
            // 過去の日時なら即時通知、未来ならカレンダートリガーを使用
            let trigger: UNNotificationTrigger
            if targetDate < Date() {
                print("⚠️ 通知予定時刻(\(targetDate))を過ぎているため、即時通知モードに切り替えます")
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
            } else {
                // CalendarTriggerを使用（より堅牢）
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: targetDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }
            
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
                    print("🔔 通知セット完了: \(containerName) - 予定時刻: \(formatter.string(from: targetDate))")
                }
            }
        }
    }
    
    // MARK: - Debug Helpers (DEBUGビルドのみ)
    #if DEBUG
    func debugCheckPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let statusString: String
            switch settings.authorizationStatus {
            case .authorized: statusString = "Authorized"
            case .denied: statusString = "Denied"
            case .notDetermined: statusString = "Not Determined"
            case .provisional: statusString = "Provisional"
            case .ephemeral: statusString = "Ephemeral"
            @unknown default: statusString = "Unknown"
            }
            print("🔔 [DEBUG] 通知権限ステータス: \(statusString)")
        }
    }
    
    func debugListPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("----- 🔔 [DEBUG] 待機中の通知リスト (\(requests.count)件) -----")
            if requests.isEmpty {
                print("なにもありません")
            }
            for request in requests {
                let triggerInfo: String
                if let trigger = request.trigger as? UNCalendarNotificationTrigger, let nextDate = trigger.nextTriggerDate() {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM/dd HH:mm:ss"
                    triggerInfo = "発火予定: \(formatter.string(from: nextDate))"
                } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger, let nextDate = trigger.nextTriggerDate() {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM/dd HH:mm:ss"
                    triggerInfo = "発火予定: \(formatter.string(from: nextDate))"
                } else {
                    triggerInfo = "\(String(describing: request.trigger))"
                }
                print("ID: \(request.identifier) | Title: \(request.content.title) | \(triggerInfo)")
            }
            print("--------------------------------------------------")
        }
    }
    
    func debugSendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🔔 テスト通知"
        content.body = "これは5秒後のテスト通知です。通知機能は正常に動作しています。"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5.0, repeats: false)
        let request = UNNotificationRequest(identifier: "debug_test_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("テスト通知エラー: \(error)")
            } else {
                print("🚀 テスト通知をスケジュールしました（5秒後）")
            }
        }
    }
    #endif
    
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
