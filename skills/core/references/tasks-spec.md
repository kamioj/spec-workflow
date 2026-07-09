<!-- GENERATED from core/references/tasks-spec.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->
# tasks.md spec

`spec/changes/<change-name>/tasks.md` is the **optional** task-tracking artifact of the sdd workflow. Produced only for cross-stack work, multi-executor collaboration, or when a task splits into >5 independent subtasks.

## When it exists

Produced by `/spec:propose` (trigger conditions + generation steps are detailed in [`commands/propose.md`](../../../commands/propose.md) § "When to also generate tasks.md"). **The generation decision is declared at the HARD GATE** (which trigger fired + how the work was split) — never silently attached.

Afterward `/spec:apply` advances by it, `/spec:status` reads it to report progress, and `/spec:archive` packages it on archive.

## Format

```markdown
# Tasks: <change-name>

> deps omitted = sequential, follows the previous item; mark explicitly only for parallel / cross-branch gating
> owner appears only in multi-executor collaboration

- [ ] 1. User authentication module
  - [ ] 1.1 DB schema design
  - [ ] 1.2 Interface contract OpenAPI (also land it in design.md ## Interfaces)
  - [ ] 1.3 Backend API implementation        owner: backend
- [ ] 2. Frontend
  - [ ] 2.1 Page skeleton + mock data          owner: frontend  deps: 1.2
  - [ ] 2.2 Wire up the real interface         owner: frontend  deps: 1.3, 2.1
- [ ] 3. Integration
  - [ ] 3.1 e2e tests                                          deps: 1.3, 2.2
```

## Field rules

### Nested numbering

The decomposition hierarchy. A parent task is done only when all its subtasks are checked.

- Level 1 (1, 2, 3) = module / phase
- Level 2 (1.1, 1.2) = a sub-action of that module
- Level 3 (1.1.1) = only for the extremely complex; usually unnecessary

### deps

Prerequisite tasks:

- **omitted** (not written) = sequential (follows the previous item)
- `deps: X` = skip the intervening tasks and depend directly on X
- `deps: X, Y` = multi-prerequisite gate (both must finish before it can start)

### owner

The executor:

- Cross-stack: `owner: frontend` / `owner: backend`
- Single executor: unmarked
- Shared tasks like the interface contract / DB migration / integration tests usually carry no owner

## Key node types

### High-fan-out node (gate)

A "hub task" that many tasks depend on; it must finish before its dependents. Typical:

- **Interface contract** (landing design.md `## Interfaces`) → both frontend and backend depend on it
- **DB schema migration** → a prerequisite for the backend implementation
- **Shared lib / SDK release** → multiple modules depend on it

In cross-stack work the **contract task must precede the implementation tasks**, otherwise the frontend / backend agents can't parallelize.

### Terminal node

The integration task whose deps list all prerequisites. Typical:

- Integration / e2e tests
- Deploy / release
- Documentation wrap-up

## Marking completion

When a task is done, change `- [ ]` to `- [x]`. **Whoever finishes it marks it:**

- the dev agent marks the subtasks it owns
- the main conversation marks the items it handles itself (config / scripts / cross-module coordination)

The condition for changing a parent `- [ ]` to `- [x]`: all its subtasks are already `[x]`.

## Lifecycle

| Stage | Command | Action |
|---|---|---|
| Generate | `/spec:propose` | produced alongside proposal.md |
| Advance | `/spec:apply` | advance by deps → mark [x] on completion |
| Report | `/spec:status` | tally X/Y completion progress |
| Archive | `/spec:archive` | package into spec/archive/ |

## Anti-patterns

- ❌ Generating tasks.md even for a single-threaded simple task (adds maintenance burden; apply advancing straight from proposal What is lighter)
- ❌ Restating the solution inside tasks (tasks write only owner / deps / acceptance; point the solution back to proposal / design — see SKILL § Phase Responsibility Matrix)
- ❌ Subtask granularity too large (>1 hour) → keep splitting
- ❌ Subtask granularity too small (<10 minutes) → merge
- ❌ A cross-stack project without owner → apply can't decide which agent to dispatch
- ❌ A high-fan-out node without explicit deps → parallel implementation deadlocks
