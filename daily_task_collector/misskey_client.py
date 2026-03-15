"""Misskey APIクライアント - ユーザーの投稿を取得する"""

import os
from datetime import datetime, timezone, timedelta
from typing import Optional
import requests


class MisskeyClient:
    def __init__(self, host: str, api_token: str):
        self.base_url = f"https://{host}/api"
        self.api_token = api_token

    def get_my_notes(self, since_hours: int = 25) -> list[dict]:
        """指定した時間以内の自分の投稿を取得する"""
        since_dt = datetime.now(timezone.utc) - timedelta(hours=since_hours)
        since_id = self._datetime_to_aid(since_dt)

        notes = []
        until_id: Optional[str] = None

        while True:
            params: dict = {
                "i": self.api_token,
                "limit": 100,
            }
            if until_id:
                params["untilId"] = until_id
            if since_id:
                params["sinceId"] = since_id

            resp = requests.post(
                f"{self.base_url}/notes/timeline",
                json=params,
                timeout=30,
            )
            resp.raise_for_status()
            batch = resp.json()

            if not batch:
                break

            # 取得期間外の投稿は除外
            filtered = [
                note for note in batch
                if self._note_is_within_range(note, since_dt)
            ]
            notes.extend(filtered)

            # バッチが期間より古くなったら終了
            if len(filtered) < len(batch):
                break

            until_id = batch[-1]["id"]

        return notes

    @staticmethod
    def _note_is_within_range(note: dict, since_dt: datetime) -> bool:
        created_at = datetime.fromisoformat(
            note["createdAt"].replace("Z", "+00:00")
        )
        return created_at >= since_dt

    @staticmethod
    def _datetime_to_aid(dt: datetime) -> str:
        """AID形式のIDを生成してsinceIdとして使う（概算）"""
        # MisskeyのAIDはタイムスタンプベースなので、
        # sinceIdには空文字を渡してクライアント側でフィルタする
        return ""

    def extract_text(self, note: dict) -> str:
        """投稿からテキストを抽出する（renoteやリプライ含む）"""
        text = note.get("text") or ""
        return text.strip()


def create_misskey_client() -> Optional[MisskeyClient]:
    host = os.getenv("MISSKEY_HOST")
    token = os.getenv("MISSKEY_API_TOKEN")
    if not host or not token:
        return None
    return MisskeyClient(host=host, api_token=token)
