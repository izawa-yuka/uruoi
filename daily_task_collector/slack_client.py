"""Slack APIクライアント - チャンネルのメッセージを取得する"""

import os
from datetime import datetime, timezone, timedelta
from typing import Optional
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError


class SlackClient:
    def __init__(self, bot_token: str):
        self.client = WebClient(token=bot_token)

    def get_channel_messages(self, channel_id: str, since_hours: int = 25) -> list[dict]:
        """指定チャンネルの投稿を取得する"""
        oldest = (
            datetime.now(timezone.utc) - timedelta(hours=since_hours)
        ).timestamp()

        messages = []
        cursor = None

        while True:
            params: dict = {
                "channel": channel_id,
                "oldest": str(oldest),
                "limit": 200,
                "inclusive": True,
            }
            if cursor:
                params["cursor"] = cursor

            try:
                resp = self.client.conversations_history(**params)
            except SlackApiError as e:
                raise RuntimeError(f"Slack API エラー: {e.response['error']}") from e

            batch = resp.get("messages", [])
            # スレッドの親メッセージのみ（サブタイプなし）を対象にする
            messages.extend(
                m for m in batch
                if not m.get("subtype") and m.get("text")
            )

            if not resp.get("has_more"):
                break
            cursor = resp["response_metadata"]["next_cursor"]

        return messages

    @staticmethod
    def extract_text(message: dict) -> str:
        """メッセージからテキストを抽出する"""
        return (message.get("text") or "").strip()

    @staticmethod
    def get_message_url(workspace_domain: str, channel_id: str, ts: str) -> str:
        """メッセージのSlack URLを生成する"""
        ts_formatted = ts.replace(".", "")
        return f"https://{workspace_domain}.slack.com/archives/{channel_id}/p{ts_formatted}"


def create_slack_client() -> Optional[SlackClient]:
    token = os.getenv("SLACK_BOT_TOKEN")
    if not token:
        return None
    return SlackClient(bot_token=token)
