"""Misskey APIクライアント - ユーザーの投稿を取得する"""

import os
from datetime import datetime, timezone, timedelta
from typing import Optional
import requests


class MisskeyClient:
    def __init__(self, host: str, api_token: str):
        self.base_url = f"https://{host}/api"
        self.api_token = api_token

    def get_my_user_id(self) -> str:
        """認証済みユーザーのIDを取得する"""
        resp = requests.post(
            f"{self.base_url}/i",
            json={"i": self.api_token},
            timeout=30,
        )
        resp.raise_for_status()
        return resp.json()["id"]

    def get_my_notes(self, since_hours: int = 25) -> list[dict]:
        """指定した時間以内の自分の投稿を取得する"""
        since_dt = datetime.now(timezone.utc) - timedelta(hours=since_hours)
        since_ms = int(since_dt.timestamp() * 1000)
        user_id = self.get_my_user_id()

        notes = []
        until_id: Optional[str] = None

        while True:
            params: dict = {
                "i": self.api_token,
                "userId": user_id,
                "sinceDate": since_ms,
                "limit": 100,
                "withRenotes": False,
            }
            if until_id:
                params["untilId"] = until_id

            resp = requests.post(
                f"{self.base_url}/users/notes",
                json=params,
                timeout=30,
            )
            resp.raise_for_status()
            batch = resp.json()

            if not batch:
                break

            notes.extend(batch)
            until_id = batch[-1]["id"]

        return notes

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
