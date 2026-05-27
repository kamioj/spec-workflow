---
name: PHP 工程化规范（国内特化版）
scope: 现代 PHP（ThinkPHP 国民框架 + Laravel + Symfony）+ 国内老 CMS / 私服后台审计
note: |
  本文件按"国内真实生态权重"重排，与国外推荐脱钩。
  ThinkPHP 是国内 PHP 第一框架（份额远超 Laravel），私活 / 政企外包 / 私服后台默认选型。
  Laravel 占精品互联网 / 创业公司。Symfony 在国内份额可忽略，仅作参考。
  老 CMS 识别（织梦 / DEDECMS / PHPCMS / Discuz / ECShop / 帝国 CMS）与私服后台审计联动 `~/.claude/skills/ctf-game/references/server-audit.md`。
---

# PHP 工程化规范（国内特化）

> **使用前提**：操作者是国内 PHP 开发 / 安全审计场景。如果你在做欧美开源项目，请额外参考国际版 PSR-12 / Laravel 官方文档；本文件**不优先**国外推荐。

---

# 第一部分：现代 PHP 写新代码（国内权重排序）

## 1. PHP 基本盘（PSR + 现代语法）

PSR 是国际标准，国内一线 PHP 库都遵守 PSR-4 / PSR-12，但**国内业务代码**实际遵守度参差。**审计 / 接手老外包代码时不要假设有 PSR**，但**自己写新代码必须遵守**。

| 标准 | 必须程度 | 用途 |
|---|---|---|
| **PSR-1 / PSR-12** | 必须 | 基本编码 + 风格 |
| **PSR-4** | 必须 | autoload，composer 默认按这个 |
| **PSR-11** | 中 | 容器接口（用框架时框架已实现）|
| **PSR-7 / PSR-15** | 中 | HTTP message / middleware（写中间件库时用）|
| **PHP The Right Way** | 索引 | 社区最佳实践 https://phptherightway.com/ |

**PSR-12 关键速查**：

- 文件首行 `<?php`，**UTF-8 无 BOM**（PS5.1 Set-Content -Encoding UTF8 会带 BOM，国内 Windows 开发者常踩）
- `declare(strict_types=1);` 紧跟 `<?php`
- namespace、use 段之间空一行
- 类 `PascalCase`，方法 / 属性 `camelCase`，常量 `UPPER_SNAKE_CASE`
- 缩进 4 空格（不要 tab）
- 类左花括号同行（K&R），方法左花括号下一行
- 文件**只放一个类**，文件名 = 类名

## 2. PHP 8.x 现代特性（写新代码必用）

PHP 8.0 (2020) 起跨度大。国内 2026 年新项目应起步 **PHP 8.2+**（readonly class），生产稳定首选 **PHP 8.3**。

```php
<?php

declare(strict_types=1);   // ★ 全文件必须

namespace app\service;

// ✅ 构造器属性提升（PHP 8.0+）—— 消除 DTO 样板
final class UserDto
{
    public function __construct(
        public readonly string $id,
        public readonly string $email,
        public readonly int $age,
    ) {}
}

// ✅ readonly class（PHP 8.2+）—— 整类不可变
readonly class Address
{
    public function __construct(
        public string $province,
        public string $city,
        public string $street,
    ) {}
}

// ✅ enum（PHP 8.1+）—— 替代魔法字符串 / 类常量
enum OrderStatus: string
{
    case Pending = 'pending';
    case Paid = 'paid';
    case Shipped = 'shipped';
    case Refunded = 'refunded';
    case Cancelled = 'cancelled';

    public function label(): string
    {
        return match ($this) {
            self::Pending   => '待支付',
            self::Paid      => '已支付',
            self::Shipped   => '已发货',
            self::Refunded  => '已退款',
            self::Cancelled => '已取消',
        };
    }
}

// ✅ Attributes（PHP 8.0+）—— 替代注释元信息
#[Route('/users/{id}', methods: ['GET'])]
public function show(int $id): Response { /* ... */ }

// ✅ 命名参数 —— 调用清晰
$user = new User(name: '张三', age: 28, role: Role::Admin);

// ✅ match 表达式 —— 替代 switch（严格比较 + 表达式 + 必须 default 或穷尽）
$tip = match ($status) {
    OrderStatus::Pending => '请尽快支付',
    OrderStatus::Paid    => '商家备货中',
    default              => '订单状态异常',
};

// ✅ Nullsafe operator
$city = $user?->address?->city ?? '未知';

// ✅ First-class callable syntax (PHP 8.1+)
$upper = strtoupper(...);

// ✅ Readonly + 命名构造 —— 推荐 DTO 写法
final readonly class PayNotifyDto
{
    public function __construct(
        public string $outTradeNo,
        public int $totalFee,
        public string $tradeStatus,
    ) {}

    public static function fromWechat(array $payload): self
    {
        return new self(
            outTradeNo:  (string) $payload['out_trade_no'],
            totalFee:    (int)    $payload['total_fee'],
            tradeStatus: (string) $payload['result_code'],
        );
    }
}
```

## 3. 工具链（2026 国内实际使用）

| 工具 | 用途 | 国内使用度 |
|---|---|---|
| **composer** | 包管理（一家独大）| 必须 |
| **PHPStan** | 静态分析（level 8 最严，国内有中文社区翻译）| 高 |
| **Psalm** | 静态分析（污点分析强，**安全审计推荐**）| 中 |
| **PHP-CS-Fixer** | 自动格式化按 PSR-12 | 中 |
| **PHP_CodeSniffer** | 风格检查 | 中 |
| **PHPUnit** | 测试（老 / 企业项目标配）| 高 |
| **Pest** | 测试（新项目优雅）| 低（国内推广不足）|
| **Rector** | 自动化代码升级（PHP 5→7→8、框架升级）| 中（升级老 TP 项目神器）|
| **php-parallel-lint** | 快速语法 lint | 高 |
| **deptrac** | 架构边界检查 | 低 |

**国内特化**：

- composer 全局 `config -g repo.packagist composer https://mirrors.aliyun.com/composer/` 配阿里源，否则海外包慢
- 老项目接手第一件事：`composer install` 看能否拉起 → 不能拉起则项目可能是 PHP 5 时代无 composer 散文件

## 4. 国内 PHP 框架选型（国民框架版）

**重要前提**：国内 PHP 生态 ThinkPHP 份额第一，**远超** Laravel。Laravel 在精品互联网 / 出海公司常见，但**政企外包 / 私活 / CMS / 私服后台 / 中小企业站** 默认 ThinkPHP。

### 选型决策树

```
新项目立项
├─ 客户是政企 / 外包 / 私服 / 站长生态？        → ThinkPHP（生态、招聘、文档全中文）
├─ 客户是创业公司 / 出海 / 接 Stripe / 国际化？  → Laravel
├─ 团队 ≥ 10 人、长期 5 年 + 维护、模块化要求？ → Symfony（罕见，但严肃企业级合理）
├─ API 性能极致 / 微服务 / 协程？              → Hyperf（基于 Swoole，字节系 / 出海团队用）
├─ 极简 API / 轻量？                          → Slim / Lumen（已停维护，慎用）
└─ 接手老代码（>5 年）？                       → 极大概率是 ThinkPHP 3.x / 5.x，先识别版本
```

### 框架国内份额（粗略 2026）

| 框架 | 份额 | 典型场景 |
|---|---|---|
| **ThinkPHP**（TP3/5/6/8）| 第一，约 50%+ | 外包、私服、站点、企业站、CMS |
| **Laravel** | 第二，约 25% | 创业公司、SaaS、API 平台 |
| **Yii / Yii2** | 较少，约 5-10% | 老外包遗留、政府项目 |
| **CodeIgniter** | 老遗留，<5% | 早期外包 |
| **Hyperf**（Swoole）| 增长中 | 字节系、高性能 API |
| **Symfony** | 极少，<2% | 严肃企业级 / 跨国子公司 |

---

## 5. ThinkPHP（国内第一框架）

> ThinkPHP 由顶想科技维护，全中文文档 https://doc.thinkphp.cn/ 。版本演化：TP3.2（古早，PHP 5.3）→ TP5（重写，2016）→ TP5.1 → TP6（2020 PHP 7.1+）→ TP8（2023 PHP 8.0+，当前主流新项目选 TP8）。

### 5.1 TP8 单应用结构

```
project/
├── app/
│   ├── controller/         控制器
│   │   └── Index.php
│   ├── model/              模型
│   │   └── User.php
│   ├── service/            服务层（你自己建）
│   ├── view/               模板
│   ├── middleware/
│   ├── validate/           验证器
│   ├── command/            命令行
│   ├── BaseController.php
│   ├── ExceptionHandle.php
│   ├── Request.php
│   └── common.php          公共函数
├── config/                 配置（多个 php 文件）
│   ├── app.php
│   ├── database.php
│   ├── cache.php
│   └── route.php
├── route/
│   └── app.php             路由定义
├── public/
│   ├── index.php           入口
│   └── static/
├── extend/                 扩展类库（非 composer）
├── runtime/                缓存 / 日志（必须可写）
├── vendor/                 composer
├── .env                    环境变量
├── composer.json
└── think                   命令行入口（php think run）
```

### 5.2 TP8 多应用结构（更常见）

老外包 / 政企项目大量采用**多应用模式**（前台 + 后台分目录），需要安装：

```bash
composer require topthink/think-multi-app
```

```
app/
├── api/                    手机端 API 应用
│   ├── controller/
│   ├── model/
│   └── config/
├── admin/                  后台应用
│   ├── controller/
│   ├── model/
│   ├── view/
│   └── middleware/
└── index/                  前台应用
    ├── controller/
    └── view/
```

**判断单应用 / 多应用**：看 `app/` 下是否直接有 `controller/` 文件夹。有 = 单应用；没有但有子目录 = 多应用。

可在 `config/app.php` 配域名绑定：`admin.xxx.com` → admin 应用。

### 5.3 TP 控制器范式

```php
<?php
declare(strict_types=1);

namespace app\admin\controller;

use app\BaseController;
use app\service\UserService;
use think\Request;
use think\response\Json;

class User extends BaseController
{
    public function __construct(
        protected UserService $userService,  // TP 自带 IoC，构造函数注入
    ) {}

    public function index(Request $request): Json
    {
        $page = (int) $request->param('page', 1);
        $list = $this->userService->paginate($page);
        return json(['code' => 0, 'data' => $list]);
    }

    // 参数自动绑定（TP 特性，路由参数 → 方法参数）
    public function read(int $id): Json
    {
        $user = $this->userService->find($id);
        return json(['code' => 0, 'data' => $user]);
    }
}
```

### 5.4 TP vs Laravel 核心差异（接手项目前必知）

| 维度 | ThinkPHP | Laravel |
|---|---|---|
| **设计哲学** | 约定 + 灵活（"开发友好"，但易写脏代码） | 约定优于配置（强工程约束）|
| **命名空间** | 默认 `app\controller`（小写）| `App\Http\Controllers`（PascalCase）|
| **ORM** | TP 模型（Active Record，自带 `Db` 类）| Eloquent（Active Record）|
| **路由** | 默认 PathInfo 自动路由（**危险，无路由也能访问**）| 必须显式定义路由 |
| **DI 容器** | 弱（构造注入 + facade）| 强（接口自动绑定）|
| **配置** | `.env` + `config/*.php`（多文件分散）| `.env` + `config/*.php` |
| **模板** | 自带模板引擎（`{$var}` 风格）| Blade（`{{ $var }}`）|
| **验证** | Validate 类 | FormRequest |
| **中文文档** | 原生中文 | 翻译版（laravel-china.org / learnku）|
| **生态** | 国内站长 / 外包 | 国内创业 / 国际化 |

**核心坑（TP 接手项目高频）**：

- TP 默认开**自动路由**，`/controller/method` 直接可达 → 老 TP 私服项目 admin 控制器若无鉴权中间件，**直接可访问**。审计时 grep `app/admin/controller/*` 找未鉴权方法。
- TP 模型 `User::create($data)` 默认接受任意字段（无 `$fillable`），**批量赋值漏洞**高发。审计时看 model 是否定义 `protected $field` 白名单。
- TP3.x / TP5.x 历史 RCE 多发（ThinkPHP 5.0.x 远程代码执行 CVE-2018-20062 / 5.1.x / 5.2.x、TP6 反序列化链）。**TP 版本是审计第一信号**。

### 5.5 TP 版本识别

| 文件 / 标识 | 版本 |
|---|---|
| `ThinkPHP/ThinkPHP.php` + `Application/` | **TP3.x**（古早，PHP 5.3+，无 composer，安全严重落后）|
| `thinkphp/library/think/App.php` + `application/` | **TP5.0 / 5.1**（有 composer，但目录还是大写 `Application/` 风格残留）|
| `app/` + `think` 入口 + `composer.json` 中 `topthink/framework: ^6` | **TP6** |
| 同上，`topthink/framework: ^8` | **TP8** |
| `runtime/` 目录存在 | TP5+ 标志 |
| `application/` 目录 | TP3.x / 5.x 老结构 |

---

## 6. Laravel（国内第二选择）

> Laravel 国内文档 https://learnku.com/docs/laravel / 中文社区活跃，2026 主流版本 Laravel 11 LTS。

### 6.1 项目结构（国内常见）

```
app/
├── Http/
│   ├── Controllers/        薄控制器
│   │   ├── Api/            API 控制器（手机 / H5）
│   │   └── Admin/          后台控制器
│   ├── Requests/           FormRequest（验证）
│   ├── Resources/          API Resource（响应转换）
│   └── Middleware/
├── Models/                 Eloquent 模型
├── Services/               业务逻辑（重，国内项目几乎都建这层）
├── Repositories/           DB 访问抽象（小项目可省）
├── DTOs/                   readonly class
├── Events/ Listeners/
├── Jobs/                   队列（结合 Redis / RabbitMQ）
├── Exceptions/
├── Console/Commands/       artisan 命令
└── Providers/
config/
database/migrations/        迁移
routes/
├── web.php
├── api.php
└── admin.php               （国内项目常拆）
resources/views/            Blade
public/
storage/                    必须可写
.env
```

### 6.2 控制器范式（必须薄）

```php
<?php
declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreUserRequest;
use App\Http\Resources\UserResource;
use App\Services\UserService;

final class UserController extends Controller
{
    public function __construct(
        private readonly UserService $userService,
    ) {}

    public function store(StoreUserRequest $request): UserResource
    {
        $user = $this->userService->create(
            UserDto::fromRequest($request)
        );
        return UserResource::make($user);
    }
}
```

### 6.3 国内常用 Laravel 扩展

| 包 | 用途 |
|---|---|
| `dcat-admin` / `laravel-admin` | 后台脚手架（国内站长爱用）|
| `larastan` | PHPStan 集成 |
| `overtrue/wechat`、`yansongda/pay` | 微信 / 支付宝 SDK（国内不可绕开）|
| `predis/predis` | Redis |
| `laravel/horizon` | 队列监控 |
| `spatie/laravel-permission` | RBAC |
| `barryvdh/laravel-debugbar` | 调试栏 |

---

## 7. Symfony（国内份额低，简略）

国内份额 <2%，仅在严肃企业（多为跨国公司 / 严格工程化要求）出现。结构与设计哲学：

```
src/
├── Controller/             控制器
├── Entity/                 Doctrine 实体（Data Mapper，不是 Active Record）
├── Repository/             Doctrine repository
├── Service/                业务服务
├── Form/                   表单类型
├── Security/               认证授权
├── EventListener/
└── Kernel.php
config/services.yaml        服务定义（DI 容器配置）
```

**与 Laravel/TP 对比**：

- Doctrine **Data Mapper**（实体不知道自己怎么持久化），与 Eloquent / TP Model 的 Active Record 是两个世界
- 强 DI，所有依赖必须显式声明
- 没有 facade、没有自动路由 magic
- 学习曲线陡，国内招聘难
- **接手 Symfony 项目通常意味着团队有海外背景或被收购的国内子公司**

---

## 8. Hyperf（基于 Swoole 的高性能选择）

国内增长中，字节系 / 出海团队用。基于 Swoole 协程，**常驻进程**（不是传统 PHP-FPM 请求即销毁模型），需要**注意全局状态污染**。

```
app/
├── Controller/
├── Service/
├── Model/                  Hyperf DB
├── Process/                常驻进程
├── Listener/
└── Middleware/
```

**接手 Hyperf 项目注意**：

- 不要在 controller / service 写 `static` 缓存（请求间会污染）
- ORM 模型属性会跨请求复用，赋值后要 `unset` 或新建实例
- 使用协程上下文：`Hyperf\Utils\Context` 保存请求级数据

---

## 9. 设计模式（PHP 国内项目视角）

| 模式 | 何时用 |
|---|---|
| **Service Layer**（业务层）| ★国内项目几乎必建。controller 太薄，model 太脏，业务塞 service |
| **Repository** | DB 切换需求（如多数据源、读写分离手控）|
| **DTO**（readonly class）| 跨层数据传递。**禁止**直接把 Eloquent / TP Model 当响应返回 |
| **FormRequest / Validate** | 请求验证集中处理 |
| **Resource / Transformer** | 响应字段过滤（防字段泄漏）|
| **Event / Listener** | 解耦副作用（订单创建后发短信、记日志、推送）|
| **Job / Queue** | 异步处理（导出、批量、第三方接口调用、推送）|
| **Facade**（仅 Laravel）| 全局便捷调用，但难 mock，新代码尽量构造注入 |
| **Trait** | 复用切面（如 `SoftDelete`、`HasTimestamps`）|

---

## 10. 微信 / 支付 / 国内特化场景（必读）

> **国内 PHP 大半项目都会触碰这块**：公众号、小程序、扫码支付、H5 支付、银联、APP 内支付回调。本节集中讲安全要点。

### 10.1 微信公众号 / 小程序生态

| 场景 | 推荐 SDK |
|---|---|
| 公众号 + 小程序 + 企业微信 | `w7corp/easywechat`（国内事实标准，原 `overtrue/wechat`） |
| 微信支付 v3 | `wechatpay/wechatpay`（官方）或 `yansongda/pay`（社区，更易用）|
| 支付宝 | `alipaysdk/easysdk` 或 `yansongda/pay` |
| 银联 | 银联官方 SDK（较少更新，建议封装薄层）|

### 10.2 微信支付回调（notify_url）安全要点

**这是国内 PHP 漏洞 Top 1 场景**。常见漏洞模式：

```php
// ❌ 国内私服 / 外包高频反模式：完全没验签
public function notify()
{
    $data = $_POST;
    if ($data['result_code'] === 'SUCCESS') {
        // 充值！加金币！
        Db::table('user')->where('id', $data['attach'])
            ->inc('coin', $data['total_fee']);   // ← 任何人 POST 就能加金币
    }
    echo 'success';
}
```

**正确写法（微信支付 v3，APIv3 密钥 + 平台证书）**：

```php
<?php
declare(strict_types=1);

namespace app\api\controller;

use WeChatPay\Crypto\AesGcm;
use WeChatPay\Crypto\Rsa;

public function wechatNotify(): \think\Response
{
    // 1. 取头部签名信息
    $timestamp = $_SERVER['HTTP_WECHATPAY_TIMESTAMP'] ?? '';
    $nonce     = $_SERVER['HTTP_WECHATPAY_NONCE']     ?? '';
    $signature = $_SERVER['HTTP_WECHATPAY_SIGNATURE'] ?? '';
    $serial    = $_SERVER['HTTP_WECHATPAY_SERIAL']    ?? '';

    // 2. 取原始 body（必须 php://input，不是 $_POST）
    $body = file_get_contents('php://input');

    // 3. 防重放：时间戳偏移 ±5 分钟
    if (abs(time() - (int) $timestamp) > 300) {
        return response('replay', 400);
    }

    // 4. 用微信平台证书公钥验签（serial 决定用哪张证书）
    $verifyMsg = "$timestamp\n$nonce\n$body\n";
    $publicKey = $this->loadPlatformCert($serial);
    if (!Rsa::verify($verifyMsg, $signature, $publicKey)) {
        return response('sign fail', 401);
    }

    // 5. 解密 resource（AES-GCM，用 APIv3 密钥）
    $payload = json_decode($body, true);
    $plain = AesGcm::decrypt(
        $payload['resource']['ciphertext'],
        config('wechat.apiv3_key'),
        $payload['resource']['nonce'],
        $payload['resource']['associated_data'],
    );
    $order = json_decode($plain, true);

    // 6. ★ 幂等：DB 唯一键约束 + 状态检查
    $localOrder = Db::table('orders')->where('out_trade_no', $order['out_trade_no'])->find();
    if (!$localOrder || $localOrder['status'] !== 'pending') {
        return response('success', 200);    // 已处理过，幂等返回成功
    }

    // 7. ★ 金额校验：必须用本地订单金额，不能信回调金额
    if ((int) $localOrder['total_fee'] !== (int) $order['amount']['total']) {
        return response('amount mismatch', 400);
    }

    // 8. 事务里改订单状态 + 发货
    Db::transaction(function () use ($localOrder, $order) {
        Db::table('orders')->where('id', $localOrder['id'])
            ->where('status', 'pending')   // ← 乐观锁
            ->update(['status' => 'paid', 'paid_at' => date('Y-m-d H:i:s')]);
        // 发货 / 加金币 / 发卡密
    });

    return response('success', 200);
}
```

**国内私服 / 外包 PHP 支付回调审计 checklist**：

| 检查点 | 漏洞名 |
|---|---|
| 是否验签？ | 伪造充值（直接 POST `result_code=SUCCESS`）|
| 验签是否用原始 body（`php://input`）？ | 用 `$_POST` 会被 PHP 重排导致验签失败，或被绕 |
| 是否校验金额 = 本地订单金额？ | 1 元充 1000 金币 |
| 是否幂等（同 `out_trade_no` 二次回调）？ | 同笔订单充多次 |
| 是否校验 `out_trade_no` 属于本商户？ | 跨商户订单冒用 |
| 是否乐观锁 / 行锁防并发？ | 并发回调充两份 |
| 是否记录原始回调日志？ | 出问题无法回放 |
| `notify_url` 是否暴露在 `routes/api.php` 且**不在 csrf 排除外**？ | Laravel 默认 web 路由有 csrf，会拒绝回调 → 必须放 api.php |
| 是否处理 XXE？（老版 v2 XML 接口）| XXE 读文件 |

详见微信支付官方安全实践 https://pay.weixin.qq.com/doc/v2/merchant/4014394306 。

### 10.3 支付宝回调

支付宝 notify 用 RSA 公钥验签 + 商户应用私钥加密：

```php
// 验签（同步异步通用）
$alipayPublicKey = config('alipay.alipay_public_key');
$verifyResult = AlipaySdkHelper::rsaCheckV1($_POST, $alipayPublicKey, 'RSA2');
if (!$verifyResult) {
    exit('fail');
}

// 之后同样：金额校验 + 幂等 + 状态检查
```

### 10.4 微信 H5 / JSSDK / 小程序登录

- `code2session` 换 `openid` / `session_key` → 国内私服后台用户体系一律 `openid` 作为唯一身份
- **`session_key` 不能下发到前端**，老外包代码这条 90% 踩
- 解密 `encryptedData`（手机号、unionId）用 AES-128-CBC + `session_key`

---

## 11. 国内 PHP 部署环境（必懂）

国内 PHP 部署 80% 以上用**宝塔面板**，剩余分布在 Docker / 手工 LNMP / 虚拟主机：

| 场景 | 特征 | 审计 / 维护要点 |
|---|---|---|
| **宝塔面板** | `/www/wwwroot/<domain>/`，`/www/server/nginx/`，`/www/server/php/74/` 多版本并存 | 默认 8888 端口，弱口令 / 已知 CVE 高发；备份在 `/www/backup/` |
| **手工 LNMP** | `/etc/nginx/`、`/etc/php/7.4/fpm/`、socket 在 `/run/php/` | 配置较散，需 grep |
| **Docker** | `docker-compose.yml` + 多 service | 较规范 |
| **共享虚拟主机**（万网 / 阿里云轻量旧版 / 西部数码）| PHP 5.6 / 7.0 + Apache + 无 SSH | 老外包 / 个人小站 |
| **Windows + IIS + PHP** | 政府 / 教育系统遗留 | `.htaccess` 无效，注意 `web.config` |

**部署相关安全要点**：

- 宝塔默认 `phpinfo.php` 在 `/phpinfo.php` 暴露
- 宝塔旧版本 `/pma`（phpMyAdmin）软链接默认开启
- 老外包项目根目录常有 `phpinfo.php` / `info.php` / `test.php` / `1.php` 遗留
- 备份文件常在网站根目录：`*.sql`、`*.zip`、`*.tar.gz`、`backup_*`、`bak/`、`old/`、`www.zip`
- `.git/` 目录暴露（部署直接 git pull 不删 `.git`）→ 用 `GitTools` 还原源码

## 12. 国内 PHP 大厂 / 历史遗产

| 公司 / 产品 | PHP 痕迹 |
|---|---|
| **新浪微博**（早期）| 早期重度 PHP，后转 Java + Go，留下大量 PHP 遗产 |
| **百度文库 / 百度知道**（早期）| PHP + 自研框架（odp） |
| **58 同城 / 赶集**（早期）| PHP |
| **去哪儿网**（早期）| PHP，后多语言 |
| **微博部分服务** | Yaf（鸟哥扩展 C-PHP 框架） |
| **腾讯部分内部服务** | PHP（早期 QQ 空间） |

**审计 / 重写老遗产代码常见框架**：

- **Yaf**（鸟哥）—— C 写的 PHP 扩展框架，性能高，社区小，文档少
- **CodeIgniter**（CI）—— 早期国内外包标配，简单粗暴，已停维护
- **自研 MVC**—— 大厂早期项目，结构因团队而异

---

# 第二部分：国内老 PHP 代码识别（审计辅助）

## 13. 拿到陌生 PHP 源码包的快速判型

**第一刻不要急着读代码，先指纹识别**。命令清单：

```bash
# 1. 看根目录文件
ls -la

# 2. 看是否有 composer
test -f composer.json && cat composer.json | head -20

# 3. 找框架特征
find . -maxdepth 3 -name 'think' -o -name 'artisan' -o -name 'index.php' | head

# 4. 找入口
grep -rn '<?php' --include='index.php' --include='admin.php' . | head

# 5. 找老函数残留（PHP 5 信号）
grep -rn 'mysql_query\|mysql_connect\|magic_quotes\|register_globals' . | head -20

# 6. 找后门信号
grep -rn 'eval(\$_\|eval(base64_\|assert(\$_\|preg_replace.*\/e' . | head

# 7. 找 CMS 特征文件
ls plus/ data/ dede/ 2>/dev/null      # DEDECMS
ls api/ phpcms/ caches/ 2>/dev/null   # PHPCMS
ls source/ upload/ template/ 2>/dev/null  # Discuz
```

## 14. 国内主流老 CMS 识别表

| CMS | 特征目录 / 文件 | 默认后台 | 典型漏洞历史 |
|---|---|---|---|
| **DEDECMS / 织梦** | `plus/`、`include/`、`dede/`、`data/common.inc.php`、`uploads/`、`a/`（伪静态生成）| `/dede/` | **国内漏洞冠军**：tpl.php 后台 RCE、`plus/recommend.php` SQLi、`plus/search.php` SQLi、CVE-2018-20129 前台文件上传、CVE-2019-8362、CVE-2023-2928 文件包含、CVE-2025-6335 dedetag.class.php RCE、`member/uploads_edit.php` 变量覆盖、album zip 上传绕扩展名 |
| **PHPCMS** | `phpcms/`、`api/`、`caches/`、`statics/`、`index.php?m=xxx&c=xxx&a=xxx` URL 模式 | `/index.php?m=admin` | v9 `api.php?op=swfupload_json` 上传、`flash_upload.php` 任意文件上传、authkey 泄漏、SQL 注入多发 |
| **Discuz!** | `source/`、`uc_server/`、`uc_client/`、`template/`、`config/config_global.php`、`data/cache/` | `/admin.php` | Discuz X3.x 多版本 SQL / SSRF；UC_KEY 泄漏导致全站接管；`forum.php?mod=ajax&action=downremoteimg` SSRF；前台插件多漏洞 |
| **ECShop** | `admin/`、`api/`、`includes/`、`themes/`、`data/`、`upload/`、`api/client/includes/lib_api.php` | `/admin/` | ECShop 2.x / 3.x `user.php` 注入 + RCE（参数 referer 反序列化 → eval）—— 国内站长服务器沦陷 Top 漏洞 |
| **帝国 CMS（Empire CMS）** | `e/`、`d/`、`e/admin/`、`e/data/`、`e/class/connect.php` | `/e/admin/` | 后台 sql 注入、模板编辑 RCE |
| **Z-BlogPHP** | `zb_system/`、`zb_users/` | `/zb_system/login.php` | 较少 |
| **Typecho** | `var/`、`usr/`、`config.inc.php` | `/admin/` | install.php 反序列化 RCE（CVE-2017-XXXX）|
| **ShopEx / ECStore** | `app/`、`cache/`、`config/` | `/shopadmin/` | 已停维护，老站常见 |
| **MetInfo（米拓）** | `admin/`、`include/`、`message/`、`feedback/` | `/admin/` | SQL 注入、文件包含多发 |
| **CmsEasy（易通）** | `admin/`、`lib/`、`celive/`、`template/` | `/admin/` | 多版本 RCE、SQL 注入 |
| **PHPWind** | `wind/`、`u/`、`bbs/` | 已停维护 | 论坛遗留 |

### 14.1 DEDECMS / 织梦 重点说明

**国内 PHP 漏洞王者**。织梦官方早期免费爆发，2017 年改商用 5800/年后大量站长拒不付费，导致**漏洞修复停滞**。2026 年仍有大量政府 / 教育 / 中小企业站点跑在 5.7 SP2 上。

**指纹**：

- 根目录有 `plus/`（前台动态脚本）+ `include/`（核心库）+ `dede/`（后台，目录名可改）
- `data/common.inc.php` 存 DB 凭据
- `member/` 会员中心
- 模板在 `templets/`
- URL 常含 `?aid=` / `?tid=`
- 页面底部 powered by dedecms 或类似

**审计入口**：

1. `plus/*.php` —— 前台动态脚本，**变量覆盖漏洞高发**（`extract` / `$$var` / `parse_str`）
2. `member/*.php` —— 会员中心，会员可注册后利用
3. `dede/tpl.php` —— 后台模板，能 getshell（鉴权后）
4. `data/` —— 缓存 / 备份，常含敏感 `*.bak` / `mysql_*.txt`
5. `uploads/` —— 上传目录，看是否能解析 PHP

详细漏洞复现见 https://xz.aliyun.com/t/9705 。

### 14.2 老 ThinkPHP（3.x / 5.x）

老 TP 框架本身漏洞同样致命：

| TP 版本 | 历史 RCE | 验证方式 |
|---|---|---|
| TP 3.2.3 | `index.php?m=Home&c=Index&a=index&value[_method]=__construct&method[]=*&filter[]=system&server[]=id` 类构造 | 看是否 `application/` + `ThinkPHP/Library/Think/` |
| TP 5.0.x | CVE-2018-20062 `?s=/Index/\think\app/invokefunction&function=call_user_func_array&vars[0]=phpinfo&vars[1][]=1` | `composer.json` topthink/framework 5.0.* |
| TP 5.1.x | 类似 invokefunction | 5.1.* |
| TP 5.2 / 6.0 早期 | 反序列化链 | 6.0.x |

**接手老 TP 项目第一件事**：确认 `composer.json` 中 `topthink/framework` 版本 + `composer.lock` 实际锁定版本 + `vendor/topthink/framework/src/think/App.php` 文件头注释版本。三处对不上 = 项目被人改过。

### 14.3 国内私服 PHP 后台（典型源码包风格）

国内传奇 / 奇迹 MU / 跑跑卡丁车 / 冒险岛 / 完美世界私服**充值站 / GM 后台**，特征：

- 多用**散文件 PHP**（非框架），或 TP3 / CodeIgniter
- 目录结构粗暴：`pay/`、`gm/`、`admin/`、`api/`、`include/db.php`
- 数据库账号硬编码，常 root + 弱密码 / 空密码
- 充值回调几乎不验签 / 不校验金额
- GM 后台常无鉴权或硬编码后门账号 `admin/admin`、`gm/123456`
- 充值卡密表 `card_password`、`pay_log`、`gm_log` 命名直白
- 常带 `phpinfo.php`、`info.php`、`shell.php`、`1.php`、`x.php`

**审计入口顺序**（私服后台）：

1. `include/config.php` / `db.php` / `inc/conn.php` → DB 凭据、API key、第三方平台密钥
2. `pay/*_notify.php` / `pay/notify_*.php` / `recharge.php` → 充值回调，验签 / 重放 / 金额绕过
3. `admin/` / `gm/` / `manage/` → GM 后台，鉴权绕过 + SQLi + 任意文件上传
4. `api/` → 玩家接口，物品操作 / 鉴权 / 越权
5. 根目录散 `.php` → 调试 / 后门 / 备份文件
6. `upload/` / `uploads/` / `attached/` → 看是否能解析 PHP（Nginx 配置 `location ~ \.php$` 是否包含上传目录）

**与本 skill 联动**：私服业务逻辑漏洞（刷物品、刷币、注入 GM 命令）见 `~/.claude/skills/ctf-game/references/server-audit.md`，本文件只覆盖 PHP 工程化和通用 Web 漏洞模式。

## 15. 老 PHP 代码"信号灯"对照表

拿到一份未知 PHP 源码包，**第一时间 grep 这些信号**判断年代和质量：

| 信号 | 推断 | 风险 |
|---|---|---|
| `mysql_query()` / `mysql_connect()` | PHP 5 时代（mysql_* PHP 7 已移除）| SQLi 极高 |
| `mysqli_query($conn, $sql)` + 字符串拼接 | PHP 5.x，未用 prepared | SQLi 高 |
| `mssql_query` / `mssql_*` | 上古时代 SQL Server 接口 | 全面停用 |
| `register_globals = On` | PHP < 5.4 | 变量覆盖 |
| `magic_quotes_gpc = On` | PHP < 5.4 | 输入过滤错觉 |
| 无 `namespace` 声明 | 老代码 / 散文件 | 全局污染 |
| `require_once '../config.php'` 频繁 | 平铺项目，无 autoload | 路径攻击 |
| 直接 `$_GET[...]` 拼 SQL | 私服重灾区 | SQLi |
| `eval(`, `assert(`, `create_function(` | 后门或动态执行 | RCE |
| `base64_decode(` + `eval(` | 经典后门模式 | RCE |
| `preg_replace('/.../e', ...)` | e 修饰符已废弃，是 RCE 入口 | RCE |
| `extract($_GET)` / `extract($_POST)` | 变量提取 | 任意变量覆盖 |
| `parse_str($_GET['x'])` | 变量注入 | 同上 |
| `$$var = ...` 双美元 | 变量变量 | 覆盖任意变量 |
| `include $_GET['file']` | 文件包含 | LFI / RFI |
| `file_put_contents(..., $_POST[...])` | 任意写入 | 任意文件写 / getshell |
| `system($_GET[...])` / `exec(` / 拼接 | 命令执行 | RCE |
| `unserialize($_COOKIE[...])` / `$_POST[...]` | 反序列化点 | POP 链 RCE |
| `mt_rand()` / `rand()` 做 token / 密码 | 非密码学安全 | 预测攻击 |
| `md5($password)` 不加 salt | 老式哈希 | 彩虹表 |
| `md5($password . SALT)` 固定 salt | 弱 | 仍可彩虹表 |
| 没有 `composer.json` | 完全手工组织 | 无依赖管理 |
| 文件中无 `<?php` 关闭 `?>` 后还有内容 | 老风格 | 输出污染 |
| `header("Content-Type: text/html; charset=gb2312")` | 老编码站，常 GBK | 编码注入 |
| `iconv('GBK', 'UTF-8', ...)` 大量出现 | 中文站 GBK 遗留 | 编码绕过 |
| `error_reporting(0)` 在文件头 | 隐藏错误（多见于后门）| 反检测 |
| `@$_GET[...]` 错误抑制 | 老式写法 | 错误隐藏 |

## 16. 现代化重写策略（客户希望升级）

老 PHP 项目重写到现代的路径：

```
PHP 5.x 老代码（mysql_*、无 namespace、散文件）
  ↓ 第一步：上 composer + autoload（PSR-4）
  ↓ 第二步：把 .php 散文件 namespace 化（按目录组织）
  ↓ 第三步：mysql_ → PDO + prepared，或迁到框架 ORM
  ↓ 第四步：$_GET / $_POST → validator / FormRequest
  ↓ 第五步：搬迁到 ThinkPHP 8 / Laravel 11（保留业务，重写表现层）
  ↓ 第六步：DB 凭据移到 .env，密码改 password_hash，session 改 redis
```

**工具**：

- **Rector** —— 自动化前 4 步（PHP 版本升级 + 部分 SQL 重构）。规则集：`Rector\Set\ValueObject\LevelSetList::UP_TO_PHP_83`
- **php-cs-fixer** —— 风格统一
- **PHPStan** —— 找类型错误、未定义变量

---

# 第三部分：反模式清单（国内频率排序）

## 17. 高频反模式（按国内项目实际频率）

| # | 反模式 | 严重度 | 频率 | 后果 |
|---|---|---|---|---|
| 1 | 拼接 SQL（任何形态）| **致命** | 高 | SQLi |
| 2 | 微信 / 支付宝回调不验签 | **致命** | 高（私服 / 外包必中）| 伪造充值 |
| 3 | 支付回调不校验金额 / 不幂等 | **致命** | 高 | 1 元充 1000 |
| 4 | 用 md5 / sha1 存密码（无 salt 或固定 salt）| **致命** | 高（老 CMS / 私服 100%）| 彩虹表 |
| 5 | TP 自动路由 + admin 控制器无中间件鉴权 | 高 | 中 | 后台直接访问 |
| 6 | 上传目录在 Web 根下且 Nginx 解析 PHP | 高 | 高 | getshell |
| 7 | DB 凭据硬编码在 `.php` 文件 | 高 | 高 | 信息泄漏 |
| 8 | 老 CMS 不及时打补丁（DEDECMS 5.7 / Discuz 3.x）| **致命** | 高 | 已知 CVE 直接打 |
| 9 | 把 Eloquent / TP Model 直接当响应 | 高 | 高 | 字段泄漏（手机号 / 身份证 / 密码哈希）|
| 10 | 不用 FormRequest / Validate，直接 `$request->input()` | 中 | 高 | 验证散乱 |
| 11 | `$_GET` / `$_POST` 直接拼接到 `include` / `file_*` 函数 | **致命** | 中 | LFI / 任意文件 |
| 12 | 不开 `declare(strict_types=1)` | 中 | 高 | 类型强转坑 |
| 13 | God Controller（业务塞控制器）| 高 | 高 | 不可测、难重构 |
| 14 | 没有 CSRF 保护（非 API） | 高 | 中 | CSRF |
| 15 | 老代码全局 mutable `$GLOBALS` | 高 | 中 | 隐式依赖 |
| 16 | 不用 type 声明（参数 / 返回值无类型）| 中 | 高 | IDE 帮不上 |
| 17 | `eval` / `assert` / `preg_replace /e` | **致命** | 中（老代码 / 后门）| RCE |
| 18 | 反序列化用户输入 | **致命** | 中 | POP 链 RCE |
| 19 | 用 `@` 抑制错误 | 中 | 高 | 隐藏 bug + 性能损耗 |
| 20 | Facade 全局调用难 mock（Laravel）| 中 | 高 | 测试困难 |
| 21 | TP / Laravel 模型无 `$fillable` 白名单 | 高 | 高 | 批量赋值漏洞 |
| 22 | `phpinfo.php` / `test.php` / 备份 `.sql` 暴露在 webroot | 高 | 高 | 信息泄漏 |
| 23 | `.git/` 目录暴露 | 高 | 高 | 源码泄漏 |
| 24 | session 用文件存 + 多机不共享 | 中 | 中 | 登录失效 |
| 25 | Hyperf 项目用 `static` 缓存 | 高 | 低 | 请求间数据污染 |

## 18. 安全审计 checklist（私服 / 外包接单）

```
□ 框架版本（TP / Laravel / Yii / CMS）及是否最新补丁
□ DB 凭据存放位置（.env / config / 硬编码）
□ 是否有 .git / .svn / .bak / *.sql / phpinfo / 备份压缩包暴露
□ 支付回调验签 + 金额 + 幂等
□ 文件上传：扩展名白名单 / 内容检测 / 上传目录禁止解析 PHP
□ SQL：是否全 prepared / Query Builder / ORM
□ 命令执行：grep system/exec/shell_exec/passthru/popen/proc_open/`/eval/assert
□ 反序列化：unserialize 用户输入 / __wakeup / __destruct 类
□ 鉴权：后台中间件 / API token / Sanctum / JWT
□ 越权：横向（用户 A 访问 B 资源）/ 纵向（普通用户访问 admin）
□ XSS：模板是否默认转义（Blade {{ }} 是，TP {$var} **不是默认**！）
□ CSRF：web 路由是否启用，notify 是否在 csrf 排除外
□ 密码：password_hash / password_verify，禁止 md5
□ session：是否 redis / DB 存，cookie httpOnly + secure + sameSite
□ 日志：是否记录敏感操作 + 是否泄漏到响应
□ debug 模式是否生产关闭（APP_DEBUG=false / app_debug=false）
□ CORS：Access-Control-Allow-Origin 是否过宽
□ Redis / MySQL 是否绑 0.0.0.0 暴露公网
□ 宝塔面板：是否最新版 / 入口路径是否改 / 弱口令
```

---

## 19. 权威信息源

**官方 / 标准**：

- [PHP-FIG PSR 列表](https://www.php-fig.org/psr/)
- [PSR-12 全文](https://www.php-fig.org/psr/psr-12/)
- [PHP The Right Way](https://phptherightway.com/) — 社区索引
- [PHP 官方文档](https://www.php.net/manual/zh/) — 中文版

**框架**：

- [ThinkPHP 8 官方文档](https://doc.thinkphp.cn/v8_0/) — 中文原生
- [ThinkPHP 6 完全开发手册](https://www.kancloud.cn/manual/thinkphp6_0/)
- [Laravel 官方](https://laravel.com/docs) / [Learnku Laravel 中文文档](https://learnku.com/docs/laravel)
- [Symfony 官方](https://symfony.com/doc)
- [Hyperf 官方](https://hyperf.wiki/)

**工具**：

- [PHPStan](https://phpstan.org/) / [Psalm](https://psalm.dev/)
- [Pest PHP](https://pestphp.com/) / [PHPUnit](https://phpunit.de/)
- [Rector](https://getrector.com/) — 自动化升级

**国内 SDK**：

- [EasyWeChat](https://www.easywechat.com/) — 微信开发事实标准
- [yansongda/pay](https://pay.yansongda.cn/) — 支付聚合
- [微信支付商户文档](https://pay.weixin.qq.com/doc/v3/merchant/) — 支付安全规范
- [支付宝开放平台文档](https://opendocs.alipay.com/)

**安全 / 审计**：

- [先知社区 - dedecms 漏洞总结](https://xz.aliyun.com/t/9705)
- [百宝箱 CMS 漏洞库](https://github.com/BaizeSec/bylibrary)
- 私服 / 游戏后台逻辑漏洞 → `~/.claude/skills/ctf-game/references/server-audit.md`
- Web 通用漏洞模式 → OWASP Top 10 / PortSwigger Academy
