<!-- GENERATED from core/references/code-charter.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->
# Coding Charter (coding phase only · binding on everyone who writes code)

> **Scope: only when writing code** — `/spec:apply` implementation (dev agent) + scripts / config the main conversation handles itself.
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

## 6. Derive, don't mint — requirement nouns get no automatic code entity

A requirement concept is carried by an EXISTING field / method / endpoint whenever one exists — derive from it (e.g. "单据类型" derives from an existing type column; "撤销" reuses the existing revoke method), never mint a parallel carrier for the same concept. Minting is legal only with the empty-handed responsibility search on record: in a change carrying index.md, cite its `## Carriers` minting row; in tiers without an index (fix batches, loop rounds), state the search — where you looked, by responsibility — in the tier's own record (F-N entry / round log) before creating the entity.

## 7. Extraction needs ≥2 call sites

Don't extract a method/function for a single call site — inline it. The exception is a body whose size or complexity genuinely self-justifies isolation (state the reason). "Cleanliness" with one caller is indirection, not abstraction.

## 8. Comments state function, not process — `DEVLOG:`-tag the exceptions

A comment is written for the NEXT reader: what this code is, why it exists, what constraint it carries. Change-narrative comments ("switched to X", "fixed the earlier bug", "per requirement item 3") belong in spec artifacts and commit messages, never in merged code. During implementation a process marker IS legal — but ONLY with the uniform `DEVLOG:` tag (`// DEVLOG: mock until backend lands`); an untagged process comment is a violation from the first keystroke, because untagged markers can't be swept mechanically. **Before the coding phase ends the DEVLOG count goes to zero**: each tag is rewritten as a function comment (intent / constraint) or deleted — the closing sweep is one command (`grep DEVLOG` over the diff → 0), and a residual tag is a charter finding for the verifier.

---

**Overall test**: would deleting this safety net / old path / default value make a **real bug surface loudly**? Yes → it's hiding a bug for you, delete it. Would it make a **real boundary lose its resilience**? Yes → keep it, but add log + reporting.
