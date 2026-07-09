---
name: Java/Spring Backend Conventions (custom)
companion: alibaba-java.md (Alibaba Java guide, read this first)
note: The Alibaba guide covers "layer responsibilities" but not package paths. This file fills in the gaps — package structure, design pattern usage, task decomposition — the areas the guide leaves open.
---
<!-- GENERATED from core/references/java-conventions.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# Java/Spring Backend Engineering Conventions

The Alibaba guide (`alibaba-java.md`) is the rule reference; this file is the implementation constraint. Use both together: the guide tells you *whether* something is right, this file tells you *exactly where to put it*.

---

## 1. Package Structure Decisions

The Alibaba guide **does not prescribe package paths**. Spring officially recommends `package-by-feature`. Many domestic scaffolding frameworks (Ruoyi, etc.) use `package-by-layer`. Each approach has its place:

### Decision Matrix

| Project Characteristics | Recommendation | Label |
|---|---|---|
| Small CRUD (<10 business modules), team ≤3, short-lived | **A. Package by Layer** | Standard scaffolding style, simple |
| **Medium business system (10–30 modules), 5–10 people, likely to evolve** | **B. Package by Feature (DDD-lite)** ⭐ **Default recommendation** | package-by-feature |
| Complex domain (finance/e-commerce/order fulfillment), long-lived, potential microservice split | **C. Strict DDD** | Hexagonal / Onion |
| Framework/SDK/utility library | Package by technical responsibility | Like Dubbo / Sentinel |

### Detecting Existing Projects (Highest-Priority Rule)

**The first thing you do when entering SDD**: run `Glob src/main/java/<root-package>/` and inspect the top-level directories.

```
Detected top-level directories              Classification
─────────────────────────                   ──────────────────
controller/, service/, dao/...              Existing project is A — follow it
user/, order/, payment/...                  Existing project is B or C — inspect module internals
Module contains domain/+application/+       Existing project is strict DDD (C)
infrastructure/+interfaces/
Module contains controller/+service/+       Existing project is simplified DDD (B)
repository/+domain/
```

**Hard rule**: new modules MUST match the structural tier of the existing project. A project already on tier A MUST NOT introduce tier-C modules, and vice versa. This prevents a codebase that is half-A and half-C — a maintenance nightmare.

If the user explicitly asks to "refactor the entire project to style X," treat that as a separate SDD proposal. Do not sneak it in as part of an ordinary feature addition.

---

## 2. B. Package by Feature (DDD-lite) — Default Recommended Structure

```
com.company.app
├── user/                      ← Bounded context / business module
│   ├── controller/            (Web layer: HTTP entry points, request validation)
│   │   ├── UserController.java
│   │   └── dto/               (Web-layer DTOs: request/response)
│   │       ├── CreateUserReq.java
│   │       └── UserResp.java
│   ├── service/               (Business service: orchestrates business logic)
│   │   ├── UserService.java
│   │   └── impl/
│   │       └── UserServiceImpl.java
│   ├── repository/            (Data access)
│   │   ├── UserMapper.java
│   │   └── UserMapper.xml
│   ├── domain/                (Domain model: entities, value objects)
│   │   ├── User.java          (DO, database mapping)
│   │   ├── UserBO.java        (Business object, optional)
│   │   └── enums/
│   │       └── UserStatus.java
│   └── manager/               (Optional: multi-DAO aggregation / third-party call wrappers)
│       └── UserManager.java
├── order/
│   └── (same structure)
├── payment/
│   └── (same structure)
├── common/                    ← Cross-module shared code
│   ├── exception/
│   ├── response/
│   ├── util/
│   └── constants/
├── config/                    ← Spring configuration classes
│   ├── WebMvcConfig.java
│   ├── MybatisConfig.java
│   └── RedisConfig.java
└── infrastructure/            ← Technical infrastructure (optional)
    ├── cache/
    └── mq/
```

### Key Constraints

- **Each business module MUST expose only its `service` package interfaces to the outside world.** Cross-module direct imports of `controller` or `domain` packages are NEVER allowed.
- **`common/` MUST NOT contain business logic** — only pure utilities, shared exceptions, and global response models.
- **`config/` MUST NOT contain business logic** — only Spring configuration and Bean definitions.
- **The Manager layer is the core insight of the Alibaba guide**: when a Service needs to call multiple DAOs or third-party APIs, push that coordination down to a Manager to keep the Service from becoming bloated.

### When to Introduce a Manager Layer

| Scenario | Introduce Manager? |
|---|---|
| Service calls a single DAO for CRUD | ❌ Not needed |
| Service aggregates data from 2–3 DAOs | ⚠️ Depends on complexity — consider pushing down if the logic exceeds ~50 lines |
| Service calls a third-party API (SMS / payment / OSS) | ✅ MUST — wrap it in a Manager |
| Service coordinates Redis / MQ / cache | ✅ Manager or infrastructure layer |

---

## 3. A. Package by Layer (Scaffolding Style, Optional)

```
com.company.app
├── controller/
│   ├── user/
│   │   ├── UserController.java
│   │   └── UserProfileController.java
│   └── order/
├── service/
│   ├── user/
│   │   ├── UserService.java
│   │   └── impl/
│   └── order/
├── dao/
│   └── user/
├── entity/
│   └── user/
└── common/
```

Use this when: following an existing Ruoyi/JeecgBoot scaffolding, or for small CRUD applications.

Not recommended for greenfield projects (as the project grows, code for a single feature scatters across multiple top-level packages, diffs become unfocused, and evolution gets painful). But **when an existing project already uses this style, follow it — do not refactor it unilaterally**.

---

## 4. C. Strict DDD (Complex Business Domains Only)

```
com.company.app.user/         ← Bounded context
├── domain/                   ← Core layer, no external dependencies
│   ├── model/
│   │   ├── User.java        (Aggregate Root)
│   │   ├── UserId.java      (Value Object)
│   │   └── Email.java       (Value Object)
│   ├── service/              (Domain service, pure business rules)
│   ├── event/                (Domain events)
│   └── repository/
│       └── UserRepository.java (Interface only — implementation lives in infrastructure)
├── application/              ← Use case orchestration
│   ├── command/              (Write side: CQRS Commands)
│   ├── query/                (Read side: CQRS Queries)
│   └── UserAppService.java
├── infrastructure/           ← Technical implementation, dependency inversion
│   ├── persistence/
│   │   └── UserRepositoryImpl.java
│   ├── gateway/              (External system adapters)
│   └── messaging/
└── interfaces/               ← Input adapters
    ├── rest/
    │   └── UserController.java
    ├── grpc/
    └── consumer/             (MQ consumers)
```

Only recommended when:
- Business rules are genuinely complex (not just CRUD)
- The system is long-lived and a microservice split is plausible
- The team understands DDD concepts and can maintain clean domain boundaries

Otherwise **do not use C**. The overhead of interfaces, adapters, and aggregate root concepts will slow down simple projects.

---

## 5. High-Frequency Design Patterns in Spring Boot

LLM-generated code routinely skips design patterns. This section lists **8 genuinely high-frequency and practical patterns** along with the conditions that warrant them. Do not use a pattern for its own sake — if the branches are fewer than 3 and unlikely to grow, a plain `if-else` is the right call.

### 5.1 Strategy (Most Common)

**When to use**: the business has 3+ ways of doing something, and more may be added later (payment methods, notification channels, file storage backends).

```java
// Interface
public interface PayStrategy {
    String getName();
    PayResult pay(PayRequest req);
}

// Implementations (multiple Beans)
@Component("alipay")
public class AlipayStrategy implements PayStrategy { ... }
@Component("wechat")
public class WechatPayStrategy implements PayStrategy { ... }

// Injection + routing
@Service
public class PayService {
    private final Map<String, PayStrategy> strategies;
    public PayService(List<PayStrategy> list) {
        this.strategies = list.stream()
            .collect(Collectors.toMap(PayStrategy::getName, s -> s));
    }
    public PayResult pay(String channel, PayRequest req) {
        PayStrategy s = strategies.get(channel);
        if (s == null) throw new BizException("Unsupported payment channel: " + channel);
        return s.pay(req);
    }
}
```

**Signal**: if you see `if (channel.equals("alipay")) { ... } else if (channel.equals("wechat")) { ... }`, refactor to Strategy.

### 5.2 Template Method (Fixed Skeleton, Variable Steps)

**When to use**: import/export flows, batch processing, message consumption — anything with a fixed skeleton where only the details vary.

```java
public abstract class ImportTemplate<T> {
    public final ImportResult execute(File file) {
        validate(file);           // Skeleton step 1
        List<T> records = parse(file);   // Implemented by subclass
        records.forEach(this::process);  // Implemented by subclass
        return summary(records);
    }
    protected abstract List<T> parse(File file);
    protected abstract void process(T record);
    protected ImportResult summary(List<T> records) { ... }
}
```

### 5.3 Chain of Responsibility (Multi-Step Processing, Interruptible)

**When to use**: approval workflows, filter chains, rule engines.

Spring Security `FilterChain` and Spring MVC `HandlerInterceptor` are both chain-of-responsibility implementations. Common business uses include:
- Risk-control rule chains
- Approval workflows (each node decides whether to pass or redirect)

### 5.4 Observer / Event (Decoupling)

**When to use**: after a successful order placement, asynchronously triggering "deduct inventory + send SMS + award points" — use Spring `ApplicationEventPublisher` to decouple these.

```java
@Service
public class OrderService {
    @Autowired ApplicationEventPublisher publisher;
    public void placeOrder(Order o) {
        save(o);
        publisher.publishEvent(new OrderPlacedEvent(o));  // Publish event
    }
}

@Component
public class InventoryListener {
    @EventListener
    @Async
    public void onOrderPlaced(OrderPlacedEvent e) {
        inventoryService.deduct(e.getOrder());
    }
}
```

**Signal**: when a core operation triggers N independent side effects, use events to decouple them.

### 5.5 Decorator / AOP (Cross-Cutting Concerns)

**When to use**: logging, monitoring, authorization, caching, rate limiting — things that don't belong in business logic but need to happen in many places.

```java
@Aspect
@Component
public class AuditLogAspect {
    @Around("@annotation(audit)")
    public Object log(ProceedingJoinPoint pjp, Audit audit) throws Throwable {
        // Before: record input parameters
        Object result = pjp.proceed();
        // After: record output
        return result;
    }
}
```

### 5.6 Builder (Many-Parameter Objects)

**When to use**: DTOs or entities with more than 4 fields — use Lombok `@Builder`.

```java
User user = User.builder()
    .name("Alice")
    .age(25)
    .email("zs@x.com")
    .role(Role.ADMIN)
    .build();
```

### 5.7 Singleton (Spring Default)

Spring Beans are singletons by default unless annotated `@Scope("prototype")`. **Be aware of this but do not actively apply it** — Spring already handles it for you in most cases.

### 5.8 Factory (Dynamic Implementation Selection)

**When to use**: similar to Strategy, but the implementation may be created dynamically rather than pre-registered as a Bean. Low frequency — reach for it when you actually need it.

### Anti-Pattern: When NOT to Use Design Patterns

- Business branches ≤2 and definitely won't grow → use `if-else` directly
- One-off requirement that will never be reused → do not introduce premature abstractions
- Nobody on the team understands a given pattern → don't use it; the maintenance burden is not worth it
- "Using a pattern to make the code look sophisticated" → this is the anti-pattern of anti-patterns

---

## 6. Task Decomposition Template (Frontend/Backend Parallel, Monorepo)

In full-stack projects, tasks MUST **explicitly indicate which branches are independently parallelizable**, so the user can run multiple Claude conversations simultaneously.

### Monorepo Full-Stack Tasks Template

```markdown
## Tasks

### Backend Tasks (branch: feat/<name>-backend)
- [ ] B1. Add `User` entity + `UserMapper` + `UserMapper.xml`
- [ ] B2. `UserService` business logic (design pattern used: Strategy — handles multiple user types)
- [ ] B3. `UserController` REST endpoints
- [ ] B4. API contract documentation (OpenAPI yaml or markdown)

### Frontend Tasks (branch: feat/<name>-frontend, parallelizable with backend)
- [ ] F1. `api/user.ts` API wrapper (mock data first)
- [ ] F2. `views/user/UserList.vue` list page
- [ ] F3. `composables/useUser.ts` data hook
- [ ] F4. Routing + permission configuration

### Contract Sync (prerequisite: B4 + F1)
- [ ] C1. Switch frontend from mock to real API
- [ ] C2. Field-level integration testing

### Integration Tasks (must be sequential — after all B, F, and C tasks are complete)
- [ ] I1. End-to-end test scenarios
- [ ] I2. Error handling and edge cases
- [ ] I3. Documentation updates (README + user guide)
```

### Key Constraints

- **B and F are fully independent and parallelizable** — the user can run two Claude conversations simultaneously
- **B4 is the contract task** and MUST complete before F switches to the real API; F1's mock phase has no dependency on B
- **I MUST be last** — only after all B and F branches are merged to main

---

## 7. Anti-Pattern Checklist (Explicitly Prohibited)

| Anti-Pattern | Why It's Wrong |
|---|---|
| Adding a tier-C module to a tier-A project | Creates structural chaos; confusing for newcomers |
| Writing business logic in a Controller | Controllers MUST only validate parameters and delegate to a Service |
| Service directly importing another module's DAO | Violates module boundaries |
| Cross-module imports that bypass the Service interface | Same issue — modules rot |
| Pinyin identifiers (`xinxi`, `yonghu`) | Alibaba guide **[Mandatory]** prohibition |
| Stuffing 500+ lines of business logic into one class | Decompose or push down to a Manager |
| Using `Executors.newFixedThreadPool` as default | Alibaba guide **[Mandatory]** prohibition — use `ThreadPoolExecutor` with explicit parameters |
| Empty catch blocks | Alibaba guide **[Mandatory]** prohibition |
| `SELECT *` | Alibaba guide **[Mandatory]** prohibition |
| Backfilling a proposal to match already-written code | The biggest anti-pattern in SDD |
