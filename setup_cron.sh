#!/bin/bash
# macOSで毎朝8時にタスク収集を自動実行するcronジョブを設定するスクリプト
#
# 使い方:
#   bash setup_cron.sh
#   bash setup_cron.sh /path/to/python  # Pythonのパスを指定する場合

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON="${1:-$(which python3)}"

if [ -z "$PYTHON" ]; then
  echo "エラー: python3 が見つかりません。引数でPythonのパスを指定してください。"
  echo "例: bash setup_cron.sh /usr/local/bin/python3"
  exit 1
fi

echo "Pythonパス: $PYTHON"
echo "スクリプトパス: $SCRIPT_DIR"

CRON_JOB="0 8 * * * cd \"$SCRIPT_DIR\" && \"$PYTHON\" run_daily_task_collector.py >> \"$SCRIPT_DIR/cron.log\" 2>&1"

# 既存のcronジョブに重複追加しない
EXISTING=$(crontab -l 2>/dev/null || echo "")
if echo "$EXISTING" | grep -qF "run_daily_task_collector.py"; then
  echo "cronジョブはすでに登録されています。"
  crontab -l | grep "run_daily_task_collector.py"
else
  (echo "$EXISTING"; echo "$CRON_JOB") | crontab -
  echo "cronジョブを登録しました（毎日 朝8時に実行）:"
  echo "  $CRON_JOB"
fi

echo ""
echo "手動で今すぐ実行したい場合:"
echo "  cd \"$SCRIPT_DIR\" && \"$PYTHON\" run_daily_task_collector.py"
echo ""
echo "ログの確認:"
echo "  tail -f \"$SCRIPT_DIR/cron.log\""
