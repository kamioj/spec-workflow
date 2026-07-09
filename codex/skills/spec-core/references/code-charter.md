<!-- GENERATED from core/references/code-charter.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->
# Coding Charter (coding phase only · binding on everyone who writes code)

> **Scope: only when writing code** — `$spec-apply` implementation (dev agent) + scripts / config the main conversation handles itself.
> The **planning phases** `research` / `ask` / `design` / `propose` **do not load this document**: those phases need the freedom to explore "degradation / fault-tolerance / fallback" as **design options**; the fail-fast discipline here governs **keystroke-level implementation** only, not thinking.
>
> **Root**: this document is the concrete, in-code form of the SKILL "Anti-Cheating" principle "don't disguise failure as success".

---

## 1. Failure must be loud — no silent re-routing

When an operation's precondition isn't met / nothing is found / it errors out, **throw an exception or return an explicit error** so the caller stops loudly. **NEVER** quietly switch to another query / another path to scrape together a result — that result is almost certainly semantically wrong, nobody knows a fallback path was taken, and the error spreads silently as "dirty data".

- ❌ `try { primary query } catch { query again a different way }` → returns semantically wrong data that the caller trusts
- ✅ Found nothing / errored → `throw` (with a clear message). **Whether to degrade is the caller's decision, not something this layer makes for it on the sly**

## 2. Changing logic = replacement — never keep the old logic as a fallback

When modifying / refactoring code, **delete the old logic cleanly; never keep it around as a "fallback strategy"**. `try { new logic } catch { old logic }` and `if (new condition) new path else old path (which should be deleted)` are the **number-one source of dirty data + unstable behavior**:

- Both paths alive → you can't be sure which one runs, and data in two formats gets stored intermixed = **dirty data**
- Old path as a safety net → **hides bugs in the new logic**, the new logic never gets exercised fully, and production behavior drifts = **instability**
- ✅ New logic is the new logic; delete the old cleanly; `assert` the new logic's invariants. If you genuinely need a gradual rollout / rollback → use an **explicit switch + a flag**, never a sneaky catch-block fallback

## 3. fail-fast for core logic — don't get defensive

Core logic with a known invariant: violating it is a bug, so **blow up immediately** — `assert x != null` ("guaranteed by X") beats `if (x == null) x = default`, which hides the contract violation and saves it for a debugging hell three months later.

## 4. Degrade only at a trust boundary, and always loudly

At boundaries that **genuinely can fail** — external services / network / untrusted input — degradation is reasonable, but it MUST **log + report**, never silently. Test: if you can name "which **expected** failure it guards against" → keep it; if you can't → delete it and let it crash.

## 5. Never fabricate a fallback value

Returning an empty list / 0 / a default / a mock to "make it look like nothing crashed" is the same crime as patching a test to return true.

---

**Overall test**: would deleting this safety net / old path / default value make a **real bug surface loudly**? Yes → it's hiding a bug for you, delete it. Would it make a **real boundary lose its resilience**? Yes → keep it, but add log + reporting.
