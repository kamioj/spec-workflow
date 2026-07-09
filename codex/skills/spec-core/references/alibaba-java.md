---
name: Java Coding Conventions — Key Extracts (custom)
source: https://github.com/alibaba/p3c
note: Key rules extracted and distilled in-house, not copied verbatim from the original. Full guide copyright belongs to Alibaba; see official channels for the complete text.
companion: java-conventions.md
---
<!-- GENERATED from core/references/alibaba-java.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# Java Coding Conventions — Key Extracts

This document focuses on **code-level conventions** (naming, constants, OOP, collections, concurrency, exception handling, logging, SQL).

Package structure, layer responsibilities, and design pattern usage are covered in `java-conventions.md`. The two files complement each other without overlapping.

---

## 1. Naming Conventions

**Classes and Interfaces**
- Class names MUST use UpperCamelCase. Test classes MUST carry a `Test` suffix (e.g., `UserServiceTest`).
- Interface names MUST NOT use an `I` prefix (`UserService` over `IUserService`). Implementation classes use an `Impl` suffix.
- Abstract classes should carry an `Abstract` prefix; exception classes MUST carry an `Exception` suffix.

**Methods and Variables**
- Method names and variable names MUST use lowerCamelCase.
- Boolean fields MUST NOT use an `is` prefix (use `enabled`, not `isEnabled`) — some frameworks generate ambiguous getters or break serialization.
- NEVER use Pinyin identifiers (`xinxi`, `yonghu`) or mixed Pinyin/English names.
- NEVER use meaningless names like `a1`, `b2` for temporary variables. Single-letter names are only acceptable as loop counters (`i`, `j`, `k`) in very short scopes.

**Package Names**
- All lowercase, dot-separated. Uppercase letters and underscores are NEVER allowed. Example: `com.company.app.user.controller`.

**Constants**
- SCREAMING_SNAKE_CASE: `MAX_RETRY_COUNT`.

---

## 2. Constant Definitions

- Constants MUST live in a dedicated constant class or enum. Magic numbers and magic strings directly in code are NEVER acceptable.
- Constants shared across multiple modules belong in `common/constants`. Constants used only within one module belong inside that module.
- Prefer enums over constant classes for values that represent a finite set (status codes, type identifiers) — enums carry stronger semantics.
- `Long` literals MUST use an uppercase `L` suffix, never lowercase `l` (too easily confused with the digit `1`).

---

## 3. OOP Conventions

**Access Control**
- Fields MUST be `private` and exposed through methods. NEVER use `public` fields for convenience.
- Utility classes that are not meant to be instantiated MUST have a `private` constructor.

**Overrides and Interfaces**
- Overridden methods MUST be annotated with `@Override` — this catches typos and serves as self-documentation.
- NEVER define constants inside an interface. An interface's responsibility is to describe behavior, not store configuration.

**Object Comparison**
- Compare `String` and wrapper types with `.equals()`, never `==`. Place the constant or literal on the left side (`"OK".equals(status)`) to guard against NullPointerExceptions.
- Enum comparison may use `==`.

**Primitives vs. Wrapper Types**
- POJO fields should use wrapper types (`Integer` rather than `int`) to distinguish between "has a value" and "was not provided."
- Local variables and method parameters should use primitives to avoid unnecessary boxing overhead.
- Always null-check wrapper types before using them in arithmetic to prevent unboxing NPEs.

**Object Construction**
- Objects with more than 4 parameters should use the Builder pattern (Lombok `@Builder`).
- NEVER put complex business logic in a constructor. Constructors MUST only assign parameters.

---

## 4. Collection Handling

**Initial Capacity**
- When initializing a `HashMap`, estimate the size and set the capacity using the formula: `expected element count / 0.75 + 1`, to avoid repeated resizing.
- When the size of an `ArrayList` is known upfront, specify the initial capacity as well.

**Factory Methods**
- Use `Collections.emptyList()` / `emptyMap()` to return immutable empty collections. NEVER return `null` to indicate "no data."
- Lists created by `Arrays.asList()` do not support `add`/`remove`. When a mutable list is needed, use `new ArrayList<>(Arrays.asList(...))`.

**Iteration and Modification**
- NEVER call `remove` directly inside a `for-each` loop while iterating over a collection. Use `Iterator.remove()` or `removeIf()` instead.
- The list returned by `subList()` is a view of the original list — modifications to the view affect the original. Use with care.

**Null Handling**
- Validate that collection parameters are non-null before using them. When returning a collection, return an empty collection rather than `null` so callers do not need to add a null check.

---

## 5. Concurrency

**Thread Pools**
- NEVER use `Executors.newFixedThreadPool` or similar factory methods — their queues are unbounded, which can cause OOM.
- MUST use `ThreadPoolExecutor` with explicit parameters: core thread count, maximum thread count, queue capacity, and rejection policy.
- Thread pools MUST have a meaningful thread name prefix (via `ThreadFactory`) to make thread dumps interpretable.

**Synchronization and Visibility**
- Mutable state in singletons should use `volatile` for visibility; use `AtomicXxx` when atomic compound operations are needed.
- Keep lock granularity as narrow as possible — lock only the critical section. NEVER perform I/O or remote calls while holding a lock.
- Avoid acquiring locks on the same objects in inconsistent orders across different code paths (this is the root cause of deadlocks).

**Thread-Safe Collections**
- For multi-threaded reads and writes, use `ConcurrentHashMap` / `CopyOnWriteArrayList` rather than `Collections.synchronizedXxx` wrappers — the wrappers lock the entire collection and have poor concurrency.
- `ThreadLocal` values MUST be removed in a `finally` block after use to prevent data leaks when threads are reused from a pool.

**Async Tasks and Results**
- Use `CompletableFuture` for async tasks. Handle exceptions with `exceptionally` or `handle` — NEVER let exceptions be silently swallowed.

---

## 6. Exceptions and Logging

**Exception Handling**
- Empty catch blocks are NEVER acceptable after catching an exception. At minimum, log it — or re-throw it wrapped as a business exception.
- Distinguish between checked exceptions (I/O, network) and business exceptions. Business exceptions should use a custom `BizException` (unchecked).
- NEVER use exceptions for flow control (e.g., using `try-catch` to check whether a value exists) — it is both slow and semantically wrong.
- NEVER put a `return` statement in a `finally` block. It silently discards the return value from the `try` block.

**Custom Exceptions**
- Pack the error code and error message together into the exception object. Do not scatter them across the call stack.
- When passing exceptions across layers, wrap the lower-level exception in a higher-level semantic exception and re-throw it, preserving the original `cause`.

**Logging Standards**
- Use the SLF4J interface (`LoggerFactory.getLogger`) — NEVER log directly through Log4j/Logback concrete classes.
- Use placeholders: `log.info("user: {}", userId)` rather than string concatenation (avoids a useless concatenation when the log level is disabled).
- Production log level is INFO. NEVER log at DEBUG inside a tight loop — high-frequency logs can fill disks.
- Exception log statements MUST pass the exception object as the last argument to capture the full stack trace: `log.error("operation failed", e)`.
- NEVER use `System.out.println` for production logging.

---

## 7. MySQL / SQL Conventions

**Table Design**
- Every table MUST have a primary key (recommended: auto-increment `bigint` or a distributed ID). Every table MUST have `create_time` and `update_time` columns.
- Use soft deletes (`is_deleted` or `deleted_at`) — NEVER physically delete business data.
- Column definitions should be `NOT NULL` with a default value. `NULL` columns complicate index statistics and comparisons.
- Monetary amounts MUST use `decimal` — NEVER `float` or `double` (floating-point precision is unacceptable for money).

**Indexes**
- Columns used in business queries MUST be indexed. For composite indexes, follow the leftmost prefix rule and put the most selective columns on the left.
- NEVER create single-column indexes on low-cardinality columns (e.g., `gender` or `status` with only a few distinct values).
- NEVER apply a function to an indexed column in a `WHERE` clause (e.g., `DATE(create_time) = ?`) — it defeats the index. Use range queries instead.

**SQL Style**
- `SELECT *` is NEVER acceptable. Always list the columns you need explicitly to reduce data transfer and protect against schema changes.
- Large-offset pagination (`LIMIT 100000, 10`) performs very poorly. Use cursor-based pagination instead (`WHERE id > last_id LIMIT 10`).
- Batch inserts and updates MUST use a single SQL statement with multiple value sets — NEVER loop with individual statements.
- NEVER make remote calls (HTTP, MQ) inside a database transaction. Transactions MUST be as short as possible.

**ORM Usage**
- In MyBatis, use explicit `resultMap` mappings for result sets. NEVER rely on automatic field name mapping — it is fragile.
- Use `<where>` and `<set>` tags in dynamic SQL to avoid trailing `AND` or trailing comma issues. NEVER concatenate SQL strings by hand.
- NEVER put business logic inside a mapper. Mappers MUST only perform data access.
