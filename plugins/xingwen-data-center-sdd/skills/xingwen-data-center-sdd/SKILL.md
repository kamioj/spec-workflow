---
name: xingwen-data-center-sdd
description: "Use when working in Codex on the Xingwen x-data-center SDD workflow: HIS sync, RabbitMQ, ODS, ETL, EMPI, DWD clinical events, ADS build/query/vector search, phase execution, grill/review, or producing execution result and full-process review route documents."
---

# Xingwen Data Center SDD

This is the Codex/mac workflow for Xingwen data-center phase work. It adapts the useful parts of `kamioj-sdd` to the current Codex project shape instead of using Claude slash commands or PowerShell hooks.

## Core Scope

Primary repo:

```text
/Users/karasu/projects/Xgent4/x-data-center
```

Current SDD root:

```text
docs/sdd/data-center/phases/
```

Use the project phase documents as the source of truth. Do not create generic `spec/changes/*` folders for this project.

## Human / Machine Language

- Human-facing replies, docs, comments, commit messages, plan titles: Chinese.
- Machine identifiers, file names, package names, table names, column names, variables: English.
- Keep edits small and targeted. Do not delete and reinsert large blocks when a local patch is enough.

## When To Use

Use this workflow when the user:

- asks to execute a phase SDD;
- asks to check whether a phase is ready to code;
- asks for `grill me` on data-center architecture;
- changes DWD / ADS / ODS / EMPI / HIS lineage design;
- asks for a phase execution result document;
- asks for a full-process review route;
- works on `x-data-center` code or SDD docs.

Do not activate the heavy workflow for tiny one-line fixes unless the user explicitly asks for SDD handling.

## Phase Workflow

1. Identify the active phase directory under `docs/sdd/data-center/phases/`.
2. Read the phase `00-阶段目标.md`, relevant SDD docs, and `验收记录.md`.
3. Before coding, resolve or call out blocking `[TBD]`, "未确认", stale `subTenant/sub_tenant/子租户`, and SDD/code conflicts.
4. If the user asks to execute the phase and the SDD is ready, implement in the main agent.
5. Use subagents only for read-only review unless the user explicitly asks for parallel implementation.
6. After implementation, verify with the narrowest useful checks.
7. Always produce or update:
   - `执行结果.md`
   - `全流程Review路线.md`
   - `验收记录.md`

## Data-Center Invariants

- Formal ingestion path: HIS Adapter -> `ClinicalDataEvent` -> RabbitMQ -> ODS Consumer -> ODS raw -> ETL -> DWD -> ADS.
- RabbitMQ routing key shape: `{tenantId}.{sourceSystem}.{dataType}`.
- Organization model is `tenant_id + campus_id`; do not reintroduce `subTenantId`, `sub_tenant_id`, or 子租户.
- `dwd.patient` is global natural-person data and must not store `tenant_id`.
- `dwd.patient_tenant` is the tenant/campus relationship table and stores `campus_ids`.
- DWD clinical facts must preserve `empi_id`, `tenant_id`, `campus_id`, `source_system`, `source_id`, and `source_ods_id`.
- Use `source_ods_id` for hard lineage from DWD back to ODS.
- Domestic business time uses `TIMESTAMP(6)` / `LocalDateTime` unless the SDD explicitly changes it.
- `deleted = 1` means not deleted; `deleted = 2` means deleted.

## Grill Rules

For architecture grill:

- Ask one important boundary question at a time.
- Prefer questions that would block implementation or corrupt data lineage.
- Stop asking once remaining questions are low-value or already mandatory.
- Record confirmed decisions back into the relevant SDD before coding.

Important grill themes:

- source API and raw field lineage;
- idempotency key and replay behavior;
- EMPI and `encounter_id` resolution;
- tenant/campus isolation;
- DWD table ownership and denormalization;
- ADS build trigger, versioning, and traceability;
- runtime validation route.

## Execution Result Requirements

`执行结果.md` must state:

- implementation scope;
- changed modules;
- DB migrations;
- new or changed APIs;
- verification commands and results;
- runtime checks not yet performed;
- remaining TODO.

Never say runtime validation passed unless it actually ran against the local services and databases.

## Full-Process Review Route Requirements

For data-center phases, `全流程Review路线.md` must start from HIS data entering the system, not from the middle of the pipeline.

Minimum route:

```text
HIS HTTP 接口
-> HIS Adapter / ClinicalDataEvent
-> RabbitMQ
-> ODS Consumer / ODS raw
-> ETL 阶段顺序
-> 医院 Extractor / CleanCommand / Writer
-> DWD 临床事实
-> ADS build
-> ADS 全息视图 / chunk / 报告向量
-> Query API
-> 来源追溯
```

Each station should include:

- key files;
- SQL or endpoint to inspect;
- expected count/status;
- three to five review questions.

## macOS/Codex Validation Scripts

This plugin uses Python scripts instead of Claude hooks or PowerShell.

From the plugin root:

```bash
python3 scripts/check_phase_sdd.py \
  --repo /Users/karasu/projects/Xgent4/x-data-center \
  --phase phase-03-ads-query-vector \
  --mode post
```

Use `--mode pre` before implementation and `--mode post` after implementation. Script output is advisory for Codex; if it reports blocking issues, fix the SDD or call them out before proceeding.

## Verification Defaults

For `x-data-center`, prefer:

```bash
mvn -q -DskipTests compile
git diff --check
```

When runtime validation is requested, include:

- app startup;
- RabbitMQ connectivity;
- Flyway migration on `dc_ods`, `dc_core`, `dc_ads`;
- manual ODS sync;
- manual ETL dispatch;
- manual ADS build;
- Query API checks.

## Multi-Agent Policy

- Main agent owns file edits and final decisions.
- Subagents may inspect SDD/code and report findings.
- Do not let multiple agents write the same repo concurrently.
- If a subagent finding changes the design, update SDD first, then code.
