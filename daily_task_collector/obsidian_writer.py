"""Obsidian vault の Tasks.md にタスクを追記する

出力フォーマット:
  ## 買いたいもの
  - [ ] AirPodsが欲しい (2026-03-15) <!-- url: https://... -->

  ## 生活
  - [ ] ジムに行く (2026-03-15) <!-- url: https://... -->
"""

import os
import re
from datetime import date
from pathlib import Path
from typing import Optional


CATEGORY_ORDER = ["買いたいもの", "生活", "調べたいもの", "仕事", "その他"]


class ObsidianWriter:
    def __init__(self, vault_path: str, tasks_file: str = "Tasks.md"):
        self.tasks_path = Path(vault_path) / tasks_file

    def append_tasks(self, tasks: list[dict], target_date: date) -> int:
        """タスクリストをTasks.mdに追記し、追加件数を返す。

        Args:
            tasks: [{"title": str, "category": str, "url": str|None}, ...]
            target_date: 投稿日付（タスク行末尾に表示）
        """
        if not tasks:
            return 0

        content = self._read_file()
        existing_urls = self._extract_existing_urls(content)

        new_tasks = [
            t for t in tasks
            if not t.get("url") or t["url"] not in existing_urls
        ]
        if not new_tasks:
            return 0

        # カテゴリごとに仕分け
        by_category: dict[str, list[dict]] = {}
        for task in new_tasks:
            cat = task.get("category", "その他")
            by_category.setdefault(cat, []).append(task)

        for category in CATEGORY_ORDER:
            if category not in by_category:
                continue
            content = self._insert_into_category(
                content, category, by_category[category], target_date
            )

        self._write_file(content)
        return len(new_tasks)

    def _insert_into_category(
        self,
        content: str,
        category: str,
        tasks: list[dict],
        target_date: date,
    ) -> str:
        """カテゴリセクションにタスクを追加する。セクションがなければ作成する。"""
        cat_header = f"## {category}"
        lines = content.split("\n") if content else []

        cat_idx = next(
            (i for i, l in enumerate(lines) if l.strip() == cat_header), None
        )

        new_lines = [_format_task(t, target_date) for t in tasks]

        if cat_idx is not None:
            # セクションが存在 → タスク行の末尾に追加
            insert_at = cat_idx + 1
            while insert_at < len(lines) and (
                lines[insert_at].startswith("- ") or lines[insert_at].strip() == ""
            ):
                if lines[insert_at].strip() == "" and insert_at > cat_idx + 1:
                    break
                insert_at += 1
            lines = lines[:insert_at] + new_lines + lines[insert_at:]
        else:
            # セクションがない → ファイル末尾に新規追加
            if lines and lines[-1].strip() != "":
                lines.append("")
            lines.append(cat_header)
            lines.extend(new_lines)
            lines.append("")

        return "\n".join(lines)

    def _read_file(self) -> str:
        if self.tasks_path.exists():
            return self.tasks_path.read_text(encoding="utf-8")
        return ""

    def _write_file(self, content: str) -> None:
        self.tasks_path.parent.mkdir(parents=True, exist_ok=True)
        self.tasks_path.write_text(content, encoding="utf-8")

    @staticmethod
    def _extract_existing_urls(content: str) -> set[str]:
        """ファイル内の <!-- url: ... --> コメントからURLを抽出する"""
        return set(re.findall(r"<!-- url: (\S+) -->", content))


def _format_task(task: dict, target_date: date) -> str:
    """タスクを Markdown チェックボックス形式に整形する。

    例: - [ ] AirPodsが欲しい (2026-03-15) <!-- url: https://... -->
    """
    title = task.get("title", "").strip()
    url = task.get("url")
    date_str = target_date.isoformat()
    line = f"- [ ] {title} ({date_str})"
    if url:
        line += f" <!-- url: {url} -->"
    return line


def create_obsidian_writer() -> Optional[ObsidianWriter]:
    vault_path = os.getenv("OBSIDIAN_VAULT_PATH")
    if not vault_path:
        return None
    tasks_file = os.getenv("OBSIDIAN_TASKS_FILE", "Tasks.md")
    return ObsidianWriter(vault_path=vault_path, tasks_file=tasks_file)
