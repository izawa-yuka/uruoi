"""投稿テキストの整形ユーティリティ"""

import re


def clean_task_text(text: str) -> str:
    """タスクテキストを整形する（ハッシュタグ除去、余分な空白削除）"""
    cleaned = re.sub(r"#\S+", "", text)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned
