"""Notion APIクライアント - タスクをデータベースに登録する"""

import os
from datetime import date
from typing import Optional
from notion_client import Client


# Notionデータベースに必要なプロパティ:
#   名前 (title)    : タスクの内容
#   ソース (select) : "Misskey" or "Slack"
#   日付 (date)     : 収集した日付
#   URL (url)       : 元の投稿へのリンク（任意）
#   ステータス (status/select): デフォルトは "未着手"


class NotionTaskClient:
    def __init__(self, api_token: str, database_id: str):
        self.client = Client(auth=api_token)
        self.database_id = database_id

    def add_task(
        self,
        title: str,
        source: str,
        collected_date: date,
        source_url: Optional[str] = None,
    ) -> dict:
        """Notionデータベースにタスクを1件追加する"""
        properties: dict = {
            "名前": {
                "title": [{"text": {"content": title}}]
            },
            "ソース": {
                "select": {"name": source}
            },
            "日付": {
                "date": {"start": collected_date.isoformat()}
            },
        }

        if source_url:
            properties["URL"] = {"url": source_url}

        return self.client.pages.create(
            parent={"database_id": self.database_id},
            properties=properties,
        )

    def get_existing_urls(self, collected_date: date) -> set[str]:
        """同じ日にすでに登録済みのURLセットを返す（重複登録を防ぐ）"""
        results = []
        start_cursor = None

        while True:
            params: dict = {
                "database_id": self.database_id,
                "filter": {
                    "property": "日付",
                    "date": {"equals": collected_date.isoformat()},
                },
                "page_size": 100,
            }
            if start_cursor:
                params["start_cursor"] = start_cursor

            resp = self.client.databases.query(**params)
            results.extend(resp.get("results", []))

            if not resp.get("has_more"):
                break
            start_cursor = resp["next_cursor"]

        urls = set()
        for page in results:
            url_prop = page.get("properties", {}).get("URL", {})
            url = url_prop.get("url")
            if url:
                urls.add(url)
        return urls


def create_notion_client() -> Optional[NotionTaskClient]:
    token = os.getenv("NOTION_API_TOKEN")
    db_id = os.getenv("NOTION_DATABASE_ID")
    if not token or not db_id:
        return None
    return NotionTaskClient(api_token=token, database_id=db_id)
