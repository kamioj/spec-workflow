#!/usr/bin/env python3
"""检查 /spec:propose 前 research.md 是否仍有待决 TBD。"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(2)


def main() -> int:
    stdin = sys.stdin.read()
    if not stdin.strip():
        return 0

    data = json.loads(stdin)
    user_prompt = data.get("user_prompt") or ""
    cwd = data.get("cwd")

    if "/spec:propose" not in user_prompt:
        return 0
    if not cwd:
        return 0

    changes_dir = Path(cwd) / "spec" / "changes"
    if not changes_dir.is_dir():
        return 0

    changes = [
        path
        for path in changes_dir.iterdir()
        if path.is_dir() and path.name != "archive"
    ]

    if not changes:
        fail("SDD: 没有活跃 change。先调 /spec:research <方向> 启动")

    open_section_re = re.compile(
        r"^##\s*Open\s*\[TBD\][\s\S]*?(?=^##\s+|\Z)",
        re.MULTILINE,
    )
    tbd_re = re.compile(r"\[TBD-\d+\]")

    for change in changes:
        research_path = change / "research.md"
        if not research_path.is_file():
            fail(f"SDD: {change.name} 缺 research.md。先调 /spec:research <方向>")

        content = research_path.read_text(encoding="utf-8")
        match = open_section_re.search(content)
        if match and tbd_re.search(match.group(0)):
            fail(
                f"SDD: research.md ({change.name}) 含未消化的 [TBD] 决策点。"
                "先调 /spec:ask 消化"
            )

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as exc:
        print(f"SDD check-tbd hook 内部错误（已放行）: {exc}", file=sys.stderr)
        raise SystemExit(0)
