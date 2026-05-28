---
name: Java/Spring Backend Conventions (自写)
companion: alibaba-java.md (阿里手册原文，先读这个)
note: 阿里手册规定的是"分层职责"不规定包路径；本文件补足包结构、设计模式应用、任务拆分等手册没说的部分。
---

# Java/Spring 后端工程规范

阿里手册（`alibaba-java.md`）是规则参考；本文件是落地约束。两份配合使用：手册告诉你"该不该"，本文件告诉你"具体怎么放".

---

## 1. 包结构决策

阿里手册**不规定包路径**。Spring 官方推荐 `package-by-feature`（按业务分包）。国内脚手架（若依等）多用 `package-by-layer`（按层分包）。三种各有适用：

### 决策矩阵

| 项目特征 | 推荐 | 标签 |
|---|---|---|
| 小型 CRUD（<10 业务模块）、3 人内团队、短期 | **A. 按层分包** | 国内脚手架风格，简单 |
| **中型业务系统（10-30 模块）、5-10 人、可能演进** | **B. 按业务（DDD-lite）** ⭐ **默认推荐** | package-by-feature |
| 复杂业务（金融/电商/订单/履约）、长期演进、可能拆微服务 | **C. 严格 DDD** | Hexagonal / Onion |
| 框架/SDK/工具库 | 按技术职责分包 | 像 Dubbo / Sentinel |

### 现有项目检测（最高优先级规则）

**进入 SDD 时第一件事**：`Glob src/main/java/<root-package>/` 看第一级目录。

```
检测到的第一级目录                判定
─────────────────────────         ──────────────────
controller/, service/, dao/...    现有项目是 A，跟随
user/, order/, payment/...        现有项目是 B 或 C，看模块内进一步判断
模块内有 domain/+application/+    现有项目是 C 严格 DDD
infrastructure/+interfaces/
模块内有 controller/+service/+    现有项目是 B 简化版
repository/+domain/
```

**禁止规则**：新模块的结构**必须跟现有项目同档次**。已经 A 的项目不允许新加 C 模块；反之亦然。这是为了避免半 A 半 C 的混乱代码库。

如果用户明确说"重构整个项目用 X"——那是另一个独立 SDD 提案，不要在普通新增模块里偷偷做。

---

## 2. B. 按业务模块（DDD-lite）—— 默认推荐结构

```
com.company.app
├── user/                      ← 限界上下文 / 业务模块
│   ├── controller/            (Web 层：HTTP 入口、参数校验)
│   │   ├── UserController.java
│   │   └── dto/               (Web 层 DTO：req/resp)
│   │       ├── CreateUserReq.java
│   │       └── UserResp.java
│   ├── service/               (业务服务：编排业务逻辑)
│   │   ├── UserService.java
│   │   └── impl/
│   │       └── UserServiceImpl.java
│   ├── repository/            (数据访问)
│   │   ├── UserMapper.java
│   │   └── UserMapper.xml
│   ├── domain/                (领域模型：实体、值对象)
│   │   ├── User.java          (DO，数据库映射)
│   │   ├── UserBO.java        (业务对象，可选)
│   │   └── enums/
│   │       └── UserStatus.java
│   └── manager/               (可选：跨多 DAO 组合 / 第三方调用封装)
│       └── UserManager.java
├── order/
│   └── (同样结构)
├── payment/
│   └── (同样结构)
├── common/                    ← 跨业务共享
│   ├── exception/
│   ├── response/
│   ├── util/
│   └── constants/
├── config/                    ← Spring 配置类
│   ├── WebMvcConfig.java
│   ├── MybatisConfig.java
│   └── RedisConfig.java
└── infrastructure/            ← 技术基础设施（可选）
    ├── cache/
    └── mq/
```

### 关键约束

- **单业务模块对外只暴露 `service` 包的接口**，其他包（controller/domain）禁止跨模块直接 import
- **`common/` 不放业务逻辑**，只放纯工具类、通用异常、全局响应模型
- **`config/` 不放业务**，只放 Spring 配置和 Bean 定义
- **Manager 层是阿里手册的精髓**：当一个 Service 需要调多个 DAO 或第三方 API 时，下沉到 Manager，避免 Service 臃肿

### 何时引入 Manager 层

| 场景 | 是否引入 Manager |
|---|---|
| Service 调单 DAO 做 CRUD | ❌ 不需要 |
| Service 调 2-3 个 DAO 组合数据 | ⚠️ 看复杂度，超 50 行考虑下沉 |
| Service 调第三方 API（短信/支付/OSS）| ✅ 必须，封装到 Manager |
| Service 需要 Redis/MQ/缓存编排 | ✅ Manager 或 infrastructure |

---

## 3. A. 按层分包（国内脚手架风格，可选）

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

适用：跟随若依/JeecgBoot 等脚手架现状、小型 CRUD。

不推荐用于新项目（项目长大后单业务的代码会散在多个顶层包，diff 不集中，难以演进）。但**已有项目用这套时跟随，不擅自重构**。

---

## 4. C. 严格 DDD（仅复杂业务）

```
com.company.app.user/         ← 限界上下文
├── domain/                   ← 核心层，无外部依赖
│   ├── model/
│   │   ├── User.java        (聚合根 Aggregate Root)
│   │   ├── UserId.java      (值对象 Value Object)
│   │   └── Email.java       (值对象)
│   ├── service/              (领域服务，纯业务规则)
│   ├── event/                (领域事件)
│   └── repository/
│       └── UserRepository.java (接口！实现在 infrastructure)
├── application/              ← 用例编排
│   ├── command/              (写：CQRS Command 侧)
│   ├── query/                (读：CQRS Query 侧)
│   └── UserAppService.java
├── infrastructure/           ← 技术实现，依赖反转
│   ├── persistence/
│   │   └── UserRepositoryImpl.java
│   ├── gateway/              (调外部系统)
│   └── messaging/
└── interfaces/               ← 输入适配器
    ├── rest/
    │   └── UserController.java
    ├── grpc/
    └── consumer/             (MQ 消费者)
```

仅在以下情况推荐：
- 业务规则复杂（不是 CRUD）
- 长期演进、可能拆微服务
- 团队熟悉 DDD 概念，能维护"领域纯净"的边界

否则**不要用 C**，C 的成本（接口/适配器/聚合根概念）会拖累简单项目。

---

## 5. Spring Boot 高频设计模式

LLM 默认写法常缺设计模式，本节列出**8 个真正高频且简单**的模式 + 使用条件。不要为用模式而用——分支 <3 且不会扩展直接 `if-else`。

### 5.1 策略模式（最常用）

**场景**：业务有 3+ 种"做法"且未来可能扩展（支付方式、消息推送渠道、文件存储类型）

```java
// 接口
public interface PayStrategy {
    String getName();
    PayResult pay(PayRequest req);
}

// 实现（多个 Bean）
@Component("alipay")
public class AlipayStrategy implements PayStrategy { ... }
@Component("wechat")
public class WechatPayStrategy implements PayStrategy { ... }

// 注入 + 路由
@Service
public class PayService {
    private final Map<String, PayStrategy> strategies;
    public PayService(List<PayStrategy> list) {
        this.strategies = list.stream()
            .collect(Collectors.toMap(PayStrategy::getName, s -> s));
    }
    public PayResult pay(String channel, PayRequest req) {
        PayStrategy s = strategies.get(channel);
        if (s == null) throw new BizException("不支持的支付方式: " + channel);
        return s.pay(req);
    }
}
```

**判断**：如果是 `if (channel.equals("alipay")) { ... } else if (channel.equals("wechat")) { ... }` 这种形态 → 改策略。

### 5.2 模板方法（流程固定步骤可变）

**场景**：导入导出、批处理、消息消费等"骨架固定，细节可变"的流程

```java
public abstract class ImportTemplate<T> {
    public final ImportResult execute(File file) {
        validate(file);           // 骨架步骤 1
        List<T> records = parse(file);   // 子类实现
        records.forEach(this::process);  // 子类实现
        return summary(records);
    }
    protected abstract List<T> parse(File file);
    protected abstract void process(T record);
    protected ImportResult summary(List<T> records) { ... }
}
```

### 5.3 责任链（多步处理、可中断）

**场景**：审批流、过滤器链、规则引擎

Spring Security `FilterChain`、Spring MVC `HandlerInterceptor` 都是责任链。业务上常用于：
- 风控规则链
- 审批流（每节点决定是否放行 / 转交）

### 5.4 观察者 / 事件（解耦）

**场景**：下单成功后异步触发"扣库存 + 发短信 + 加积分"——用 Spring `ApplicationEventPublisher` 解耦

```java
@Service
public class OrderService {
    @Autowired ApplicationEventPublisher publisher;
    public void placeOrder(Order o) {
        save(o);
        publisher.publishEvent(new OrderPlacedEvent(o));  // 发事件
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

**判断**：当一个核心操作触发 N 个独立副作用 → 用事件解耦。

### 5.5 装饰器 / AOP（横切关注点）

**场景**：日志、监控、权限、缓存、限流——这些不属于业务逻辑但每个方法都要做的事

```java
@Aspect
@Component
public class AuditLogAspect {
    @Around("@annotation(audit)")
    public Object log(ProceedingJoinPoint pjp, Audit audit) throws Throwable {
        // 前置：记录入参
        Object result = pjp.proceed();
        // 后置：记录出参
        return result;
    }
}
```

### 5.6 建造者（多参数对象）

**场景**：DTO/Entity 字段多（>4 个），用 Lombok `@Builder`

```java
User user = User.builder()
    .name("张三")
    .age(25)
    .email("zs@x.com")
    .role(Role.ADMIN)
    .build();
```

### 5.7 单例（Spring 默认）

Spring Bean 默认单例，除非 `@Scope("prototype")`。**了解但不主动用**——多数时候 Spring 已替你处理。

### 5.8 工厂（动态选择实现）

**场景**：类似策略，但实现可能是动态创建而非已注册的 Bean。频率低，用到再说。

### 反模式：什么时候不要用设计模式

- 业务分支 ≤2 且明确不会扩展 → 直接 `if-else`
- 一次性需求、不复用 → 不要预设抽象
- 团队没人理解某个模式 → 别用，否则维护噩梦
- "用模式让代码看起来高级" → 这是反模式中的反模式

---

## 6. Tasks 拆分模板（前后端并行，monorepo 适用）

全栈项目的 task 必须**显式标注分支可独立性**，让用户能开多个对话并行做。

### Monorepo 全栈 tasks 模板

```markdown
## Tasks

### 后端任务（branch: feat/<name>-backend）
- [ ] B1. 新增 `User` 实体 + `UserMapper` + `UserMapper.xml`
- [ ] B2. `UserService` 业务逻辑（用到设计模式：策略 - 处理多种用户类型）
- [ ] B3. `UserController` REST 接口
- [ ] B4. 接口契约文档（OpenAPI yaml 或 markdown）

### 前端任务（branch: feat/<name>-frontend，可与后端并行）
- [ ] F1. `api/user.ts` 接口封装（先 mock 数据）
- [ ] F2. `views/user/UserList.vue` 列表页
- [ ] F3. `composables/useUser.ts` 数据钩子
- [ ] F4. 路由 + 权限配置

### 契约同步（前置：B4 + F1）
- [ ] C1. 前端切换 mock → 真实接口
- [ ] C2. 字段联调

### 集成任务（必须串行，B 全 + F 全 + C 全完成后）
- [ ] I1. 端到端测试场景
- [ ] I2. 错误处理与边界 case
- [ ] I3. 文档更新（README + 用户手册）
```

### 关键约束

- **B 和 F 完全独立可并行**——用户可开两个 Claude 对话同时跑
- **B4 是契约任务**，必须先于 F 切真实接口；F1 mock 阶段不依赖
- **I 必须最后**——所有 B 和 F 合并到主分支后再做

---

## 7. 反模式清单（明确禁止）

| 反模式 | 为什么不行 |
|---|---|
| 在 A 项目里新加 C 风格的模块 | 结构混乱，新人懵 |
| Controller 里写业务逻辑 | Controller 只做参数校验 + 调 Service |
| Service 里直接 import 另一个业务模块的 DAO | 违反模块边界 |
| 跨模块 import 不通过 Service 接口 | 同上，模块腐烂 |
| 用拼音命名（`xinxi`、`yonghu`） | 阿里手册【强制】禁止 |
| 一个类塞 500+ 行业务 | 拆分或下沉到 Manager |
| 默认 `Executors.newFixedThreadPool` | 阿里手册【强制】禁止，用 `ThreadPoolExecutor` 显式参数 |
| catch 块空处理 | 阿里手册【强制】禁止 |
| `SELECT *` | 阿里手册【强制】禁止 |
| 倒填 proposal 适配已写代码 | SDD 最大反模式 |
