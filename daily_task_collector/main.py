"""毎日のタスク収集フロー - MisskeyとSlackからNotionへ"""

import os
import sys
from datetime import date, datetime, timezone
from dotenv import load_dotenv

from .misskey_client import create_misskey_client
from .slack_client import create_slack_client
from .notion_client import create_notion_client
from .task_parser import load_task_keywords, is_task_post, extract_task_lines, clean_task_text

load_dotenv()


def collect_from_misskey(keywords: list[str]) -> list[dict]:
    """Misskeyからタスク投稿を収集する"""
    client = create_misskey_client()
    if not client:
        print("[Misskey] 環境変数 MISSKEY_HOST / MISSKEY_API_TOKEN が未設定のためスキップ")
        return []

    collect_hours = int(os.getenv("COLLECT_HOURS", "25"))
    print(f"[Misskey] 過去{collect_hours}時間の投稿を取得中...")

    notes = client.get_my_notes(since_hours=collect_hours)
    print(f"[Misskey] {len(notes)}件の投稿を取得")

    tasks = []
    for note in notes:
        text = client.extract_text(note)
        if not is_task_post(text, keywords):
            continue

        note_url = (
            f"https://{os.getenv('MISSKEY_HOST')}/notes/{note['id']}"
        )
        task_lines = extract_task_lines(text)

        for line in task_lines:
            cleaned = clean_task_text(line)
            if cleaned:
                tasks.append({
                    "title": cleaned,
                    "source": "Misskey",
                    "url": note_url,
                    "created_at": note.get("createdAt", ""),
                })

    print(f"[Misskey] タスク候補: {len(tasks)}件")
    return tasks


def collect_from_slack(keywords: list[str]) -> list[dict]:
    """Slackからタスク投稿を収集する"""
    client = create_slack_client()
    if not client:
        print("[Slack] 環境変数 SLACK_BOT_TOKEN が未設定のためスキップ")
        return []

    channel_id = os.getenv("SLACK_CHANNEL_ID")
    if not channel_id:
        print("[Slack] 環境変数 SLACK_CHANNEL_ID が未設定のためスキップ")
        return []

    workspace = os.getenv("SLACK_WORKSPACE_DOMAIN", "app")
    collect_hours = int(os.getenv("COLLECT_HOURS", "25"))
    print(f"[Slack] 過去{collect_hours}時間のメッセージを取得中...")

    messages = client.get_channel_messages(channel_id=channel_id, since_hours=collect_hours)
    print(f"[Slack] {len(messages)}件のメッセージを取得")

    tasks = []
    for msg in messages:
        text = client.extract_text(msg)
        if not is_task_post(text, keywords):
            continue

        msg_url = client.get_message_url(workspace, channel_id, msg.get("ts", ""))
        task_lines = extract_task_lines(text)

        for line in task_lines:
            cleaned = clean_task_text(line)
            if cleaned:
                tasks.append({
                    "title": cleaned,
                    "source": "Slack",
                    "url": msg_url,
                    "created_at": msg.get("ts", ""),
                })

    print(f"[Slack] タスク候補: {len(tasks)}件")
    return tasks


def save_to_notion(tasks: list[dict]) -> int:
    """タスクをNotionに保存し、追加件数を返す"""
    client = create_notion_client()
    if not client:
        print("[Notion] 環境変数 NOTION_API_TOKEN / NOTION_DATABASE_ID が未設定のためスキップ")
        return 0

    today = date.today()
    existing_urls = client.get_existing_urls(today)
    print(f"[Notion] 本日すでに登録済み: {len(existing_urls)}件")

    added = 0
    skipped = 0

    for task in tasks:
        url = task.get("url")
        # 同じURLが既に登録されている場合はスキップ（重複防止）
        if url and url in existing_urls:
            skipped += 1
            continue

        client.add_task(
            title=task["title"],
            source=task["source"],
            collected_date=today,
            source_url=url,
        )
        if url:
            existing_urls.add(url)
        added += 1
        print(f"  ✓ [{task['source']}] {task['title'][:50]}")

    print(f"[Notion] 追加: {added}件 / スキップ(重複): {skipped}件")
    return added


def main():
    print(f"=== 毎日タスク収集フロー 開始 {datetime.now(timezone.utc).isoformat()} ===")

    keywords = load_task_keywords()
    print(f"収集キーワード: {keywords}")

    all_tasks: list[dict] = []
    all_tasks.extend(collect_from_misskey(keywords))
    all_tasks.extend(collect_from_slack(keywords))

    print(f"\n合計タスク候補: {len(all_tasks)}件")

    if not all_tasks:
        print("収集対象の投稿がありませんでした。")
        return

    added = save_to_notion(all_tasks)

    print(f"\n=== 完了: Notionに{added}件のタスクを登録しました ===")


if __name__ == "__main__":
    main()
