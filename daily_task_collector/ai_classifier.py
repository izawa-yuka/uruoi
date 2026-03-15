"""Gemini APIを使って投稿からタスクを判定・分類する"""

import json
import os
from google import genai
from google.genai import types

CATEGORIES = ["買いたいもの", "生活", "調べたいもの", "仕事", "その他"]
BATCH_SIZE = 20
MODEL = "gemini-2.0-flash"

SYSTEM_PROMPT = """あなたは日本語の投稿からタスク（やりたいこと・したいこと・欲しいもの）を抽出するアシスタントです。

以下のルールに従って判定してください：
- 「〜したい」「〜欲しい」「〜買いたい」「〜調べたい」「〜やらなきゃ」「〜試してみよう」など、行動意欲や欲求が含まれる投稿はタスクとして抽出する
- 日記・感想・お知らせ・リプライなど、やりたいことが含まれない投稿は除外する
- 1つの投稿に複数のタスクが含まれる場合はすべて抽出する
- タイトルはハッシュタグを除いて簡潔にまとめる

カテゴリ分類の基準：
- 買いたいもの：商品・サービスの購入、欲しいもの
- 生活：食事・家事・運動・趣味・健康など日常生活に関すること
- 調べたいもの：情報収集・リサーチ・気になること
- 仕事：業務・クライアント対応・スキルアップ・副業など
- その他：上記に当てはまらないやりたいこと"""


def classify_posts(posts: list[dict]) -> list[dict]:
    """投稿リストをGemini APIで一括解析し、タスク判定+分類結果を返す。

    Args:
        posts: [{"index": int, "text": str}, ...] の形式

    Returns:
        [{"index": int, "is_task": bool, "tasks": [{"title": str, "category": str}]}, ...]
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("環境変数 GEMINI_API_KEY が設定されていません")

    client = genai.Client(api_key=api_key)

    results: list[dict] = []
    for i in range(0, len(posts), BATCH_SIZE):
        batch = posts[i:i + BATCH_SIZE]
        batch_results = _classify_batch(client, batch)
        results.extend(batch_results)

    return results


def _classify_batch(client: genai.Client, batch: list[dict]) -> list[dict]:
    """バッチ単位でGemini APIを呼び出す"""
    posts_text = "\n".join(
        f'[{p["index"]}] {p["text"]}' for p in batch
    )
    user_message = f"""以下の投稿リストを解析してください。

{posts_text}

各投稿について、やりたいこと・欲しいもの・したいことが含まれるかを判定し、
含まれる場合はタスクのタイトルとカテゴリ（{'/'.join(CATEGORIES)}）を返してください。

必ず以下のJSON配列形式のみで返答してください（他の文章は不要）：
[
  {{"index": 0, "is_task": false}},
  {{"index": 1, "is_task": true, "tasks": [{{"title": "タスクのタイトル", "category": "カテゴリ名"}}]}}
]"""

    response = client.models.generate_content(
        model=MODEL,
        contents=user_message,
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
        ),
    )
    raw = response.text.strip()
    return _parse_response(raw, batch)


def _parse_response(raw: str, batch: list[dict]) -> list[dict]:
    """APIレスポンスをパースする。失敗した場合は全件 is_task=False で返す"""
    start = raw.find("[")
    end = raw.rfind("]") + 1
    if start == -1 or end == 0:
        return [{"index": p["index"], "is_task": False} for p in batch]

    try:
        parsed = json.loads(raw[start:end])
        for item in parsed:
            if item.get("is_task") and item.get("tasks"):
                for task in item["tasks"]:
                    if task.get("category") not in CATEGORIES:
                        task["category"] = "その他"
        return parsed
    except json.JSONDecodeError:
        return [{"index": p["index"], "is_task": False} for p in batch]


def create_post_payload(index: int, text: str) -> dict:
    """分類に渡す投稿ペイロードを生成するヘルパー"""
    return {"index": index, "text": text}
