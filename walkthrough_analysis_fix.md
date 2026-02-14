# 分析画面の計算ロジック修正 (HistoryViewModel)

## 概要
分析画面（AnalysisView）における「1匹あたりの平均飲水量」の計算ロジックを修正し、`UserDefaults` に保存された猫の頭数（`numberOfPets`）を正しく反映するようにしました。

## 変更内容

### 1. `HistoryViewModel.swift`
- **頭数の取得**: `UserDefaults` から `"numberOfPets"` キーを使用して頭数を取得する `savedPetCount` プロパティを追加しました。
  - ※ご依頼では `"petCount"` とのことでしたが、アプリ全体の `SettingsView` や `AppSettings` で使用されているキーが `"numberOfPets"` であったため、既存の実装に合わせて `"numberOfPets"` を採用しました。
- **計算メソッドの修正**:
  - `calculatePeriodAverage` と `calculatePreviousPeriodAverage` から `catCount` 引数を削除しました。
  - メソッド内部で `savedPetCount` を使用して計算するように変更しました。
  - 計算式: `(合計飲水量 ÷ 日数) ÷ 頭数`

### 2. `AnalysisView.swift`
- **呼び出し元の修正**:
  - `viewModel.calculatePeriodAverage` などの呼び出し時に `numberOfPets` を渡さないように修正しました。
  - 画面更新のトリガーとして `@AppStorage("numberOfPets")` はそのまま維持し、設定変更時に再計算が走る仕組みは確保しています。

## 確認事項
- 設定画面で猫の頭数を変更した後、分析画面の「平均摂取量 (1匹あたり)」の数値が変化することを確認してください。
