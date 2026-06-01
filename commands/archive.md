---
description: 归档当前 change 到 spec/archive/YYYY-MM-DD-<name>/。仅用户说"归档"时调。归档前会检查未提交代码
allowed-tools: Read, Glob, Bash(mv:*, mkdir:*, date:*, git:*)
---

# /spec:archive

## 前置检查

1. **git status 检查**：
   - 有未提交改动 → 警告用户并问"先提交还是先归档"
   - 用户选"先归档"→ 继续；选"先提交"→ 退出，提示用户调 `git commit`
2. **验证门**（`check-archive-gate.ps1` 在 `/spec:archive` 前硬拦）：
   - 活跃 change 必须有 `VERIFIED ... verdict:pass` 标记，且**裁决时的契约指纹 == 当前指纹**
   - 没验证通过 / 验证后又改了契约 → **hook 拒绝归档**，提示先 `/spec:verify` 跑到 pass
   - **废弃归档例外**：用户明说"这方向废了"→ 用 `/spec:archive --abandon`，归档门放行（失败提案不要求 VERIFIED），走下方「失败 / 废弃归档」

## 流程

1. 从 `spec/changes/<name>/` 读当前 change 名
2. 计算归档路径：`spec/archive/$(date +%Y-%m-%d)-<name>/`
3. `mv` 整个目录过去
4. 输出摘要：
   ```
   归档完成：spec/archive/YYYY-MM-DD-<name>/
   含产物：research.md, design.md, proposal.md, tasks.md
   ```

## 多执行体场景

- 全部 owner 任务完成、各分支合并到主干后才归档
- 任一 owner 未完成 → 拒绝归档，提示"等 X owner 完成"

## 失败 / 废弃归档

change 是放弃的（用户说"这方向不对，废了"）→ 用 **`/spec:archive --abandon`**（归档门放行、跳过 VERIFIED 要求）：
- 归档路径：`spec/archive/YYYY-MM-DD-<name>-abandoned/`
- 目录里加 `ABANDONED.md` 写明放弃原因

## 反模式

- ❌ 用户没说"归档"擅自归档
- ❌ git 有未提交改动默认归档（丢代码风险）
- ❌ 归档失败的 proposal 不加标识（archive 目录里要能看出"这是失败案例"）
