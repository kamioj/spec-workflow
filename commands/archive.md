---
description: 归档当前 change 到 spec/archive/YYYY-MM-DD-<name>/。仅用户说"归档"时调。归档前会检查未提交代码
allowed-tools: Read, Glob, Bash(mv:*, mkdir:*, date:*, git:*)
---

# /sdd:archive

## 前置检查

1. **git status 检查**：
   - 有未提交改动 → 警告用户并问"先提交还是先归档"
   - 用户选"先归档"→ 继续；选"先提交"→ 退出，提示用户调 `git commit`
2. **验证状态**：
   - 推荐 `/sdd:verify` 全 pass 后再归档
   - 未通过 → 提示但不强制（用户可能就是想归档失败的提案）

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

change 是放弃的（用户说"这方向不对，废了"）：
- 归档路径：`spec/archive/YYYY-MM-DD-<name>-abandoned/`
- 目录里加 `ABANDONED.md` 写明放弃原因

## 反模式

- ❌ 用户没说"归档"擅自归档
- ❌ git 有未提交改动默认归档（丢代码风险）
- ❌ 归档失败的 proposal 不加标识（archive 目录里要能看出"这是失败案例"）
