"""投稿からタスク候補を抽出するパーサー"""

import os
import re


# タスクとして収集するキーワード（投稿にこれらが含まれる場合に収集）
DEFAULT_KEYWORDS = [
    "やりたいこと",
    "やること",
    "todo",
    "TODO",
    "タスク",
    "したい",
    "やる",
]

# タスクとして収集するハッシュタグ
DEFAULT_HASHTAGS = [
    "#やりたいこと",
    "#todo",
    "#TODO",
    "#タスク",
]


def load_task_keywords() -> list[str]:
    """環境変数からタグ設定を読み込む"""
    env_tags = os.getenv("TASK_HASHTAGS", "")
    if env_tags.strip():
        return [tag.strip() for tag in env_tags.split(",") if tag.strip()]
    return DEFAULT_HASHTAGS + DEFAULT_KEYWORDS


def is_task_post(text: str, keywords: list[str]) -> bool:
    """投稿がタスク関連かどうかを判定する"""
    if not text:
        return False
    text_lower = text.lower()
    for kw in keywords:
        if kw.lower() in text_lower:
            return True
    return False


def extract_task_lines(text: str) -> list[str]:
    """投稿テキストからタスク行を抽出する。

    箇条書き（- / ・ / • / * / ✅ / □ / ☐ など）で始まる行を
    個別タスクとして抽出する。見つからない場合は投稿全体を1タスクとして返す。
    """
    if not text:
        return []

    bullet_pattern = re.compile(
        r"^[\s]*[-・•*✅□☐✓→➡️🔲▶▷◆◇★☆]\s+(.+)$",
        re.MULTILINE,
    )
    matches = bullet_pattern.findall(text)

    if matches:
        return [m.strip() for m in matches if m.strip()]

    # 箇条書きがなければ投稿全体（ハッシュタグを除いて）を返す
    cleaned = re.sub(r"#\S+", "", text).strip()
    # 改行で区切られている場合は各行を返す
    lines = [line.strip() for line in cleaned.split("\n") if line.strip()]
    return lines if lines else [cleaned]


def clean_task_text(text: str) -> str:
    """タスクテキストを整形する（ハッシュタグ除去、余分な空白削除）"""
    cleaned = re.sub(r"#\S+", "", text)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned
