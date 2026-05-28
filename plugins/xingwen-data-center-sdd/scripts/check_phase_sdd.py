#!/usr/bin/env python3
"""Check Xingwen data-center phase SDD readiness on macOS/Codex."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


STALE_TERMS = [
    "subTenant",
    "sub_tenant",
    "sub-tenant",
    "子租户",
]

REVIEW_FLOW_TERMS = [
    "HIS",
    "RabbitMQ",
    "ODS",
    "ETL",
    "DWD",
    "ADS",
    "Query",
    "source_ods_id",
    "trace",
]


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text()


def scan_files(root: Path) -> list[Path]:
    return [
        path
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in {".md", ".java", ".xml", ".yml", ".yaml", ".sql"}
    ]


def add_issue(issues: list[str], message: str) -> None:
    issues.append(message)


def check_phase(repo: Path, phase: str, mode: str) -> int:
    phase_dir = repo / "docs" / "sdd" / "data-center" / "phases" / phase
    issues: list[str] = []
    warnings: list[str] = []

    if not phase_dir.exists():
        add_issue(issues, f"阶段目录不存在: {phase_dir}")
        return report(issues, warnings)

    required = ["00-阶段目标.md", "验收记录.md"]
    if mode == "post":
        required.extend(["执行结果.md", "全流程Review路线.md"])

    for filename in required:
        if not (phase_dir / filename).exists():
            add_issue(issues, f"缺少阶段文件: {filename}")

    for path in scan_files(phase_dir):
        rel = path.relative_to(repo)
        text = read_text(path)
        for term in STALE_TERMS:
            if term in text:
                add_issue(issues, f"发现旧组织架构字段 {term}: {rel}")
        if re.search(r"\[TBD(?:-\d+)?\]|待确认|未确认", text):
            warnings.append(f"存在待确认内容: {rel}")

    if mode == "post":
        result = phase_dir / "执行结果.md"
        review = phase_dir / "全流程Review路线.md"
        if result.exists():
            result_text = read_text(result)
            for word in ["验证结果", "TODO", "接口", "迁移"]:
                if word not in result_text:
                    warnings.append(f"执行结果可能缺少 {word}: {result.relative_to(repo)}")
        if review.exists():
            review_text = read_text(review)
            for word in REVIEW_FLOW_TERMS:
                if word not in review_text:
                    add_issue(issues, f"Review 路线缺少链路关键字 {word}: {review.relative_to(repo)}")

    return report(issues, warnings)


def report(issues: list[str], warnings: list[str]) -> int:
    if issues:
        print("SDD 检查失败:")
        for issue in issues:
            print(f"- {issue}")
    else:
        print("SDD 阻塞项检查通过。")

    if warnings:
        print("SDD 警告:")
        for warning in warnings:
            print(f"- {warning}")

    return 1 if issues else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Check Xingwen data-center phase SDD.")
    parser.add_argument("--repo", default=".", help="x-data-center repo path")
    parser.add_argument("--phase", required=True, help="phase directory name, for example phase-03-ads-query-vector")
    parser.add_argument("--mode", choices=["pre", "post"], default="pre", help="pre before coding, post after coding")
    args = parser.parse_args()

    repo = Path(args.repo).expanduser().resolve()
    return check_phase(repo, args.phase, args.mode)


if __name__ == "__main__":
    sys.exit(main())
