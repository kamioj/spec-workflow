# Research: export-csv

## Practices
- Stream A — write rows as they are read, constant memory | candidate: large exports
- Stream B — build the whole file in memory, then send | candidate: small exports only

## Constraints
- Exports reach 2 million rows | an in-memory build runs out of memory

## Open [TBD]
- [TBD-1] Which export mode ships first | candidates: streaming (evidence: Practices Stream A) / in-memory (evidence: Practices Stream B) / skip-or-minimal | select: one
  - Q: When a manager exports a full year of orders, which mode builds the file?
  - 1: constant memory / more code paths
  - 2: simplest code / fails on large exports

## Decided
- [DEC-1] Column names follow the report screen | source: R-1 | rationale: users compare the two side by side
