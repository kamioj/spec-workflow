---
name: Java 编码规约要点（自有提炼）
source: https://github.com/alibaba/p3c
note: 关键规约自有提炼，非原文复制；原手册版权归阿里巴巴，完整内容见官方发布渠道。
companion: java-conventions.md
---

# Java 编码规约要点

本文聚焦**编码层规约**（命名、常量、OOP、集合、并发、异常日志、SQL）。
包结构、分层职责、设计模式应用见 `java-conventions.md`，两者互补不重复。

---

## 1. 命名规约

**类与接口**
- 类名用 UpperCamelCase；测试类加 `Test` 后缀（`UserServiceTest`）。
- 接口名不加 `I` 前缀（`UserService` 优于 `IUserService`）；实现类加 `Impl`。
- 抽象类建议加 `Abstract` 前缀，异常类加 `Exception` 后缀。

**方法与变量**
- 方法名、变量名用 lowerCamelCase。
- 布尔字段不加 `is` 前缀（如 `enabled` 而非 `isEnabled`），否则部分框架序列化/getter 会歧义。
- 禁止用拼音命名（`xinxi`、`yonghu`），也禁止中英混拼。
- 临时变量禁止用 `a1 b2` 之类无意义名称；单字母变量只允许在极短作用域循环计数（`i j k`）中出现。

**包名**
- 全小写，用点分隔；不允许有大写或下划线。例：`com.company.app.user.controller`。

**常量**
- 全大写下划线分隔：`MAX_RETRY_COUNT`。

---

## 2. 常量定义

- 常量必须放独立常量类（或枚举），禁止在代码里出现魔法数字/魔法字符串。
- 跨业务公用的常量放 `common/constants`；只在一个模块内用的常量放该模块内部。
- 枚举比常量类更适合表达"有限集合"语义（状态码、类型标识），优先用枚举。
- Long 型字面量加 `L`，不用小写 `l`（易与数字 1 混淆）。

---

## 3. OOP 规约

**访问控制**
- 字段一律 `private`，通过方法暴露；不要为了方便直接用 `public` 字段。
- 工具类不需要实例化的，构造器设为 `private`。

**覆写与接口**
- 覆写方法必须加 `@Override`，既防拼写错误又自文档化。
- 接口里不要定义常量——接口的职责是描述行为，不是存储配置。

**对象比较**
- 字符串、包装类型比较用 `.equals()`，不用 `==`；常量/字面量放左侧（`"OK".equals(status)`）防空指针。
- 枚举比较可以用 `==`。

**基本类型与包装类型**
- POJO 字段用包装类型（`Integer` 而非 `int`），可以区分"有值"与"未传"。
- 局部变量、方法参数用基本类型减少装箱开销。
- 包装类型做运算前先判空，防止自动拆箱 NPE。

**对象构造**
- 超过 4 个参数的对象用 Builder 模式（Lombok `@Builder`）。
- 不要在构造器里做复杂业务逻辑，构造器只做参数赋值。

---

## 4. 集合处理

**初始化容量**
- `HashMap` 初始化时估算大小并指定容量，公式：`预期元素数 / 0.75 + 1`，避免频繁扩容。
- `ArrayList` 已知大小时同样指定初始容量。

**工具类创建**
- `Collections.emptyList()` / `emptyMap()` 返回不可变空集合；不要返回 `null` 来表示"没有数据"。
- `Arrays.asList()` 生成的列表不支持 `add/remove`，要可变列表用 `new ArrayList<>(Arrays.asList(...))`。

**遍历与修改**
- 遍历集合时不允许用 `for-each` 内部直接 `remove`，用 `Iterator.remove()` 或 `removeIf()`。
- `subList()` 返回的是原列表的视图，修改视图会影响原列表，谨慎使用。

**null 处理**
- 集合参数传入前判空；返回集合时返回空集合而非 `null`，调用方不需要额外判空。

---

## 5. 并发处理

**线程池**
- 禁止用 `Executors.newFixedThreadPool` 等工厂方法（队列无界，可能 OOM）。
- 必须用 `ThreadPoolExecutor` 显式指定：核心线程数、最大线程数、队列容量、拒绝策略。
- 线程池要有有意义的线程名前缀，便于排查线程 dump（用 `ThreadFactory`）。

**同步与可见性**
- 单例的可变状态用 `volatile` 保证可见性；需要原子操作用 `AtomicXxx`。
- 锁的粒度尽量小，只锁临界区，不在锁内做 IO 或远程调用。
- 避免在多处对同一对象加锁的顺序不一致（死锁根因）。

**线程安全集合**
- 多线程读写用 `ConcurrentHashMap` / `CopyOnWriteArrayList`，不用 `Collections.synchronizedXxx`（整体加锁，并发性差）。
- `ThreadLocal` 使用后必须在 finally 中 `remove()`，防止线程池复用时的数据泄漏。

**任务与结果**
- 异步任务用 `CompletableFuture`，用 `exceptionally` 或 `handle` 处理异常，不要让异常静默吞掉。

---

## 6. 异常与日志

**异常处理**
- 捕获异常后不允许空 catch 块；至少要 log 记录，或抛出包装后的业务异常。
- 区分受检异常（I/O、网络）和业务异常；业务异常用自定义 `BizException`（非受检）。
- 不要用异常做流程控制（如用 `try-catch` 判断某个值存不存在）——性能差且语义混乱。
- finally 块里不要有 `return`，会吃掉 try 里的 return 值。

**自定义异常**
- 错误码 + 错误消息二元组放在异常对象里，不要散落在调用层。
- 层间传递时，底层异常包装为上层语义异常再抛，保留原始 cause。

**日志规范**
- 使用 SLF4J 接口（`LoggerFactory.getLogger`），不直接用 Log4j/Logback 的具体类。
- 用占位符 `log.info("user: {}", userId)` 而非字符串拼接（未开启 info 级别时避免无效拼接）。
- 生产环境日志级别 INFO，不要在循环体里打 DEBUG 日志（高频日志会打满磁盘）。
- 异常日志必须把 exception 对象作为最后一个参数传入，输出完整堆栈：`log.error("操作失败", e)`。
- 不允许用 `System.out.println` 输出生产日志。

---

## 7. MySQL / SQL 规约

**表结构**
- 每张表必须有主键（推荐自增 bigint 或分布式 ID），必须有 `create_time` / `update_time`。
- 使用软删除（`is_deleted` 或 `deleted_at`），不要物理删除业务数据。
- 字段设计 `NOT NULL`，给默认值；`NULL` 字段会使索引统计和比较复杂化。
- 金额用 `decimal`，不用 `float/double`（浮点精度问题）。

**索引**
- 业务查询字段必须建索引；组合索引遵循最左前缀原则，把区分度高的字段放左侧。
- 不要在低区分度字段上建单列索引（如 `gender`、`status` 只有几种值）。
- 索引字段不要做函数运算（`DATE(create_time) = ?`），会导致索引失效；改为范围查询。

**SQL 写法**
- 禁止 `SELECT *`，显式列出需要的字段，减少传输量、防止字段变更引发隐患。
- 分页查询大偏移（`LIMIT 100000, 10`）性能极差；用游标分页（`WHERE id > last_id LIMIT 10`）替代。
- 批量插入/更新用单条 SQL 多值，不要在循环里逐条执行。
- 事务内不做远程调用（HTTP / MQ），事务要尽量短。

**ORM 使用**
- MyBatis 中结果集字段用 `resultMap` 显式映射，不依赖字段名自动映射（脆弱）。
- 动态 SQL 里的 `<where>/<set>` 标签防止裸 AND/逗号问题，不要手拼 SQL 字符串。
- 禁止在 mapper 里处理业务逻辑；mapper 只做数据存取。
