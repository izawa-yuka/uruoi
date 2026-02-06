# 実装計画: 設定画面への課金プラン名表示

## 概要
設定画面に現在加入中の課金プラン名を表示する機能を追加しました。`StoreManager` でプランの詳細状態を管理し、`SettingsView` でそれを表示します。

## 変更内容

### 1. StoreManager.swift
- **`PlanStatus` 列挙型の追加**:
  - `.lifetime` (ずっと！URUOIプラン)
  - `.monthly` (もっと！URUOIプラン 月額)
  - `.yearly` (もっと！URUOIプラン 年額)
  - `.free` (無料プラン)
- **`currentPlan` プロパティの追加**: 現在のプラン状態を保持。
- **`updatePurchasedStatus` メソッドの更新**: `currentEntitlements` のループ内でプロダクトIDを確認し、`currentPlan` を適切に設定するロジックを追加。

### 2. SettingsView.swift
- **UIセクションの追加**:
  - リストの最上部（「プレミアムプラン案内」の上）に「会員ステータス」セクションを追加。
  - `StoreManager.shared.currentPlan` の値に応じて表示を切り替え。
  - **表示パターン**:
    - **有料プラン**: アイコン（王冠または星）＋太字テキスト。アイコン色は黄色（`.yellow`）、テキスト色はプライマリー（`.primary`）。
    - **無料プラン**: シンプルなテキスト「現在のプラン: 無料プラン」。
- **データ更新**:
  - 画面表示時（`.task`）に `StoreManager.shared.updatePurchasedStatus()` を呼び出し、最新のステータスを取得するように修正。

## 確認事項
- アプリ起動後、設定画面を開いた際に現在のプランが正しく表示されること。
- サブスクリプション加入/解約、または買い切り購入後に表示が即座に反映されるか（`.task` による更新と `@Observable` による監視）。
- 表示される文言が以下の仕様と完全に一致していること。
  - もっと！URUOIプラン（月額）
  - もっと！URUOIプラン（年額）
  - ずっと！URUOIプラン（買い切り）
  - 現在のプラン: 無料プラン
