#!/usr/bin/env python3
"""检查 /spec:apply 前 proposal.md 是否存在。"""

from __future__ import annotations

import json
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

    if "/spec:apply" not in user_prompt:
        return 0
    if not cwd:
        return 0

    changes_dir = Path(cwd) / "spec" / "changes"
    if not changes_dir.is_dir():
        fail("SDD: 没有 spec/changes/ 目录。先走 /spec:research → /spec:propose")

    changes = [
        path
        for path in changes_dir.iterdir()
        if path.is_dir() and path.name != "archive"
    ]

    if not changes:
        fail("SDD: 没有活跃 change。先走 /spec:research → /spec:propose")

    for change in changes:
        proposal_path = change / "proposal.md"
        if not proposal_path.is_file():
            fail(f"SDD: {change.name} 缺 proposal.md。先调 /spec:propose")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as exc:
        print(f"SDD check-gate hook 内部错误（已放行）: {exc}", file=sys.stderr)
        raise SystemExit(0)
