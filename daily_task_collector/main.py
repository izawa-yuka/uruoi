"""毎日のタスク収集フロー - MisskeyとSlackからObsidianへ"""

import os
from datetime import date, datetime, timezone
from dotenv import load_dotenv

from .misskey_client import create_misskey_client
from .slack_client import create_slack_client
from .ai_classifier import classify_posts, create_post_payload
from .obsidian_writer import create_obsidian_writer
from .task_parser import clean_task_text

load_dotenv()


def collect_posts_from_misskey() -> list[dict]:
    """Misskeyから全投稿を取得してリストで返す"""
    client = create_misskey_client()
    if not client:
        print("[Misskey] 環境変数 MISSKEY_HOST / MISSKEY_API_TOKEN が未設定のためスキップ")
        return []

    collect_hours = int(os.getenv("COLLECT_HOURS", "25"))
    print(f"[Misskey] 過去{collect_hours}時間の投稿を取得中...")

    notes = client.get_my_notes(since_hours=collect_hours)
    print(f"[Misskey] {len(notes)}件の投稿を取得")

    posts = []
    for note in notes:
        text = client.extract_text(note)
        if not text:
            continue
        posts.append({
            "text": clean_task_text(text),
            "source": "Misskey",
            "url": f"https://{os.getenv('MISSKEY_HOST')}/notes/{note['id']}",
        })
    return posts


def collect_posts_from_slack() -> list[dict]:
    """Slackから全メッセージを取得してリストで返す"""
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

    posts = []
    for msg in messages:
        text = client.extract_text(msg)
        if not text:
            continue
        posts.append({
            "text": clean_task_text(text),
            "source": "Slack",
            "url": client.get_message_url(workspace, channel_id, msg.get("ts", "")),
        })
    return posts


def run_ai_classification(posts: list[dict]) -> list[dict]:
    """全投稿をClaude APIで解析し、タスクのみ返す"""
    if not posts:
        return []

    print(f"\n[AI] {len(posts)}件の投稿を解析中...")

    payloads = [create_post_payload(i, p["text"]) for i, p in enumerate(posts)]
    results = classify_posts(payloads)

    tasks = []
    for result in results:
        if not result.get("is_task"):
            continue
        original = posts[result["index"]]
        for task in result.get("tasks", []):
            tasks.append({
                "title": task["title"],
                "category": task.get("category", "その他"),
                "source": original["source"],
                "url": original["url"],
            })

    print(f"[AI] タスクとして判定: {len(tasks)}件")
    return tasks


def save_to_obsidian(tasks: list[dict]) -> int:
    """タスクをObsidianのTasks.mdに追記し、追加件数を返す"""
    writer = create_obsidian_writer()
    if not writer:
        print("[Obsidian] 環境変数 OBSIDIAN_VAULT_PATH が未設定のためスキップ")
        return 0

    today = date.today()
    added = writer.append_tasks(tasks, today)

    for task in tasks:
        print(f"  ✓ [{task['category']}] {task['title'][:50]}")

    print(f"[Obsidian] 追加: {added}件")
    return added


def main():
    print(f"=== 毎日タスク収集フロー 開始 {datetime.now(timezone.utc).isoformat()} ===")

    all_posts: list[dict] = []
    all_posts.extend(collect_posts_from_misskey())
    all_posts.extend(collect_posts_from_slack())

    print(f"\n合計投稿数: {len(all_posts)}件")

    if not all_posts:
        print("収集対象の投稿がありませんでした。")
        return

    tasks = run_ai_classification(all_posts)

    if not tasks:
        print("タスクとして判定された投稿がありませんでした。")
        return

    added = save_to_obsidian(tasks)
    print(f"\n=== 完了: Obsidianに{added}件のタスクを登録しました ===")


if __name__ == "__main__":
    main()
