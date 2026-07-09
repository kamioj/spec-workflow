---
name: PHP Engineering Standards (China-Localized Edition)
scope: Modern PHP (ThinkPHP — the dominant domestic framework + Laravel + Symfony) + legacy CMS / private-server backend auditing
note: |
  This file is ordered by "real-world weight in the Chinese PHP ecosystem" and intentionally diverges from international recommendations.
  ThinkPHP is the #1 PHP framework in China (market share far exceeds Laravel) — it is the default choice for freelance work, government/enterprise outsourcing, and private-server backends.
  Laravel is common in premium internet companies and startups. Symfony's domestic share is negligible and included only for reference.
  Legacy CMS identification (DEDECMS / PHPCMS / Discuz / ECShop / Empire CMS) ties into private-server backend auditing at `~/.claude/skills/ctf-game/references/server-audit.md`.
---
<!-- GENERATED from core/references/php-conventions.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# PHP Engineering Standards (China-Localized)

> **Prerequisite**: This document targets PHP development and security auditing in the Chinese domestic context. If you are working on a Western open-source project, also consult the international PSR-12 standard and the official Laravel documentation — this file does NOT prioritize international conventions.

---

# Part 1: Writing New PHP Code in Modern Style (ordered by domestic weight)

## 1. PHP Fundamentals (PSR + Modern Syntax)

PSR is an international standard. Mainstream Chinese PHP libraries all comply with PSR-4 / PSR-12, but **domestic business code** compliance varies widely in practice. When **auditing or inheriting legacy outsourced code, NEVER assume PSR compliance** — but **you MUST follow it for any new code you write**.

| Standard | Requirement | Purpose |
|---|---|---|
| **PSR-1 / PSR-12** | MUST | Basic coding + style |
| **PSR-4** | MUST | Autoloading — Composer's default |
| **PSR-11** | Medium | Container interface (frameworks already implement this) |
| **PSR-7 / PSR-15** | Medium | HTTP message / middleware (relevant when writing middleware libraries) |
| **PHP The Right Way** | Reference | Community best practices https://phptherightway.com/ |

**PSR-12 quick reference**:

- First line of file: `<?php`, **UTF-8 without BOM** (PowerShell 5.1's `Set-Content -Encoding UTF8` adds a BOM — a common pitfall for Windows developers in China)
- `declare(strict_types=1);` immediately after `<?php`
- Blank line between `namespace` and `use` blocks
- Classes: `PascalCase`; methods / properties: `camelCase`; constants: `UPPER_SNAKE_CASE`
- Indent with 4 spaces (never tabs)
- Class opening brace on the same line (K&R); method opening brace on the next line
- **One class per file**; filename = class name

## 2. PHP 8.x Modern Features (MUST use for new code)

PHP 8.0 (2020) was a major leap forward. New projects in China in 2026 should target **PHP 8.2+** (readonly classes) as a minimum; **PHP 8.3** is the preferred stable production version.

```php
<?php

declare(strict_types=1);   // ★ MUST be in every file

namespace app\service;

// ✅ Constructor property promotion (PHP 8.0+) — eliminates DTO boilerplate
final class UserDto
{
    public function __construct(
        public readonly string $id,
        public readonly string $email,
        public readonly int $age,
    ) {}
}

// ✅ readonly class (PHP 8.2+) — makes the entire class immutable
readonly class Address
{
    public function __construct(
        public string $province,
        public string $city,
        public string $street,
    ) {}
}

// ✅ enum (PHP 8.1+) — replaces magic strings / class constants
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
            self::Pending   => 'Pending payment',
            self::Paid      => 'Paid',
            self::Shipped   => 'Shipped',
            self::Refunded  => 'Refunded',
            self::Cancelled => 'Cancelled',
        };
    }
}

// ✅ Attributes (PHP 8.0+) — replaces annotation-based metadata
#[Route('/users/{id}', methods: ['GET'])]
public function show(int $id): Response { /* ... */ }

// ✅ Named arguments — makes call sites self-documenting
$user = new User(name: 'Alice', age: 28, role: Role::Admin);

// ✅ match expression — replaces switch (strict comparison + expression form + must be exhaustive or have a default)
$tip = match ($status) {
    OrderStatus::Pending => 'Please pay soon',
    OrderStatus::Paid    => 'Seller is preparing your order',
    default              => 'Abnormal order status',
};

// ✅ Nullsafe operator
$city = $user?->address?->city ?? 'unknown';

// ✅ First-class callable syntax (PHP 8.1+)
$upper = strtoupper(...);

// ✅ Readonly + named constructor — recommended DTO pattern
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

## 3. Toolchain (China 2026 Actual Usage)

| Tool | Purpose | Domestic adoption |
|---|---|---|
| **composer** | Package management (the only real choice) | MUST |
| **PHPStan** | Static analysis (level 8 = strictest; active Chinese community) | High |
| **Psalm** | Static analysis (excellent taint tracking — **recommended for security audits**) | Medium |
| **PHP-CS-Fixer** | Auto-format to PSR-12 | Medium |
| **PHP_CodeSniffer** | Style checking | Medium |
| **PHPUnit** | Testing (standard for legacy and enterprise projects) | High |
| **Pest** | Testing (elegant for new projects) | Low (underadopted domestically) |
| **Rector** | Automated code upgrades (PHP 5→7→8, framework migrations) | Medium (invaluable for upgrading old TP projects) |
| **php-parallel-lint** | Fast syntax linting | High |
| **deptrac** | Architectural boundary enforcement | Low |

**China-specific notes**:

- Configure Alibaba's Composer mirror globally to avoid slow package downloads: `composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/`
- When inheriting a legacy project, the first thing to do is run `composer install` and see if it resolves — if it fails, the project likely predates Composer and is all loose PHP files from the PHP 5 era

## 4. PHP Framework Selection in China (The National Framework Reality)

**Important context**: ThinkPHP holds the #1 market share in the Chinese PHP ecosystem, **far ahead of Laravel**. Laravel is common in polished internet companies and companies with international exposure, but **government/enterprise outsourcing, freelance work, CMS sites, private-server backends, and small-business sites** default to ThinkPHP.

### Framework Decision Tree

```
Starting a new project
├─ Client is a government body / outsourcing / private server / webmaster?  → ThinkPHP (ecosystem, hiring, docs all in Chinese)
├─ Client is a startup / going overseas / integrating Stripe / international? → Laravel
├─ Team ≥ 10 people, 5+ year maintenance horizon, strong modularity required? → Symfony (rare, but justified for serious enterprise)
├─ Extreme API performance / microservices / coroutines?                      → Hyperf (Swoole-based; used by ByteDance-affiliated teams)
├─ Minimal API / lightweight?                                                 → Slim / Lumen (Lumen is no longer maintained — use with caution)
└─ Inheriting legacy code (>5 years old)?                                     → Almost certainly ThinkPHP 3.x / 5.x — identify the version first
```

### Framework Market Share (approximate 2026)

| Framework | Share | Typical use cases |
|---|---|---|
| **ThinkPHP** (TP3/5/6/8) | #1, ~50%+ | Outsourcing, private servers, websites, enterprise sites, CMS |
| **Laravel** | #2, ~25% | Startups, SaaS, API platforms |
| **Yii / Yii2** | Minor, ~5–10% | Legacy outsourcing, government projects |
| **CodeIgniter** | Legacy, <5% | Early outsourcing projects |
| **Hyperf** (Swoole) | Growing | ByteDance-affiliated teams, high-performance APIs |
| **Symfony** | Negligible, <2% | Serious enterprise / multinational subsidiaries |

---

## 5. ThinkPHP (China's #1 Framework)

> ThinkPHP is maintained by Top Think Technology, with fully Chinese documentation at https://doc.thinkphp.cn/. Version history: TP3.2 (legacy, PHP 5.3) → TP5 (rewrite, 2016) → TP5.1 → TP6 (2020, PHP 7.1+) → TP8 (2023, PHP 8.0+). **TP8 is the current recommended choice for new projects**.

### 5.1 TP8 Single-Application Structure

```
project/
├── app/
│   ├── controller/         Controllers
│   │   └── Index.php
│   ├── model/              Models
│   │   └── User.php
│   ├── service/            Service layer (you create this)
│   ├── view/               Templates
│   ├── middleware/
│   ├── validate/           Validators
│   ├── command/            CLI commands
│   ├── BaseController.php
│   ├── ExceptionHandle.php
│   ├── Request.php
│   └── common.php          Shared helper functions
├── config/                 Configuration (multiple PHP files)
│   ├── app.php
│   ├── database.php
│   ├── cache.php
│   └── route.php
├── route/
│   └── app.php             Route definitions
├── public/
│   ├── index.php           Entry point
│   └── static/
├── extend/                 Extension libraries (outside Composer)
├── runtime/                Cache / logs (MUST be writable)
├── vendor/                 Composer
├── .env                    Environment variables
├── composer.json
└── think                   CLI entry point (php think run)
```

### 5.2 TP8 Multi-Application Structure (more common)

Legacy outsourcing and government/enterprise projects heavily use **multi-application mode** (separate directories for frontend and backend). Requires:

```bash
composer require topthink/think-multi-app
```

```
app/
├── api/                    Mobile API application
│   ├── controller/
│   ├── model/
│   └── config/
├── admin/                  Backend admin application
│   ├── controller/
│   ├── model/
│   ├── view/
│   └── middleware/
└── index/                  Frontend application
    ├── controller/
    └── view/
```

**Identifying single vs. multi-application**: check whether `app/` contains a `controller/` directory directly. If yes → single-application; if it contains sub-directories instead → multi-application.

Domain-to-application binding can be configured in `config/app.php` (e.g., `admin.xxx.com` → admin application).

### 5.3 TP Controller Pattern

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
        protected UserService $userService,  // TP has a built-in IoC container; use constructor injection
    ) {}

    public function index(Request $request): Json
    {
        $page = (int) $request->param('page', 1);
        $list = $this->userService->paginate($page);
        return json(['code' => 0, 'data' => $list]);
    }

    // Auto parameter binding (TP feature: route params → method params)
    public function read(int $id): Json
    {
        $user = $this->userService->find($id);
        return json(['code' => 0, 'data' => $user]);
    }
}
```

### 5.4 TP vs Laravel Core Differences (must know before inheriting a project)

| Dimension | ThinkPHP | Laravel |
|---|---|---|
| **Design philosophy** | Convention + flexibility ("developer-friendly," but easy to write messy code) | Convention over configuration (strong engineering discipline) |
| **Namespace** | Default `app\controller` (lowercase) | `App\Http\Controllers` (PascalCase) |
| **ORM** | TP Model (Active Record, with a standalone `Db` class) | Eloquent (Active Record) |
| **Routing** | PathInfo auto-routing by default (**dangerous — controllers are accessible without explicit routes**) | Explicit route definitions required |
| **DI container** | Weak (constructor injection + facades) | Strong (automatic interface binding) |
| **Configuration** | `.env` + `config/*.php` (scattered across multiple files) | `.env` + `config/*.php` |
| **Templates** | Built-in template engine (`{$var}` style) | Blade (`{{ $var }}`) |
| **Validation** | Validate classes | FormRequest |
| **Chinese docs** | Native Chinese | Community translations (laravel-china.org / learnku) |
| **Ecosystem** | Domestic webmasters / outsourcing | Domestic startups / international projects |

**Common pitfalls when inheriting TP projects**:

- TP enables **auto-routing** by default — `/controller/method` is directly accessible. In legacy private-server projects, admin controllers with no authentication middleware are **directly reachable by anyone**. During auditing, grep `app/admin/controller/*` to find unguarded methods.
- TP's `User::create($data)` accepts any field by default (no `$fillable`), making **mass-assignment vulnerabilities** extremely common. During auditing, check whether models define a `protected $field` whitelist.
- TP3.x / TP5.x has a history of multiple RCEs (ThinkPHP 5.0.x CVE-2018-20062, 5.1.x, 5.2.x, TP6 deserialization chains). **The TP version number is the first signal to look for during an audit**.

### 5.5 TP Version Identification

| File / Indicator | Version |
|---|---|
| `ThinkPHP/ThinkPHP.php` + `Application/` | **TP3.x** (legacy, PHP 5.3+, no Composer, severely outdated security) |
| `thinkphp/library/think/App.php` + `application/` | **TP5.0 / 5.1** (has Composer, but still uses the old uppercase `Application/`-style structure) |
| `app/` + `think` entry point + `topthink/framework: ^6` in `composer.json` | **TP6** |
| Same as above, `topthink/framework: ^8` | **TP8** |
| `runtime/` directory present | TP5+ indicator |
| `application/` directory | TP3.x / 5.x legacy structure |

---

## 6. Laravel (China's Second Choice)

> Chinese Laravel documentation: https://learnku.com/docs/laravel — active community. The dominant version in 2026 is Laravel 11 LTS.

### 6.1 Project Structure (typical in China)

```
app/
├── Http/
│   ├── Controllers/        Thin controllers
│   │   ├── Api/            API controllers (mobile / H5)
│   │   └── Admin/          Backend admin controllers
│   ├── Requests/           FormRequests (validation)
│   ├── Resources/          API Resources (response transformation)
│   └── Middleware/
├── Models/                 Eloquent models
├── Services/               Business logic (heavy — nearly all domestic projects add this layer)
├── Repositories/           DB access abstraction (optional for small projects)
├── DTOs/                   readonly classes
├── Events/ Listeners/
├── Jobs/                   Queues (with Redis / RabbitMQ)
├── Exceptions/
├── Console/Commands/       Artisan commands
└── Providers/
config/
database/migrations/        Migrations
routes/
├── web.php
├── api.php
└── admin.php               (commonly split in domestic projects)
resources/views/            Blade
public/
storage/                    MUST be writable
.env
```

### 6.2 Controller Pattern (MUST be thin)

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

### 6.3 Commonly Used Laravel Packages in China

| Package | Purpose |
|---|---|
| `dcat-admin` / `laravel-admin` | Admin panel scaffolding (popular among domestic developers) |
| `larastan` | PHPStan integration |
| `overtrue/wechat`, `yansongda/pay` | WeChat / Alipay SDKs (unavoidable in China) |
| `predis/predis` | Redis |
| `laravel/horizon` | Queue monitoring |
| `spatie/laravel-permission` | RBAC |
| `barryvdh/laravel-debugbar` | Debug toolbar |

---

## 7. Symfony (Low domestic share — brief overview)

Domestic market share is <2%, appearing mainly in serious enterprises (typically multinationals or companies with strict engineering requirements). Structure and design philosophy:

```
src/
├── Controller/             Controllers
├── Entity/                 Doctrine entities (Data Mapper — not Active Record)
├── Repository/             Doctrine repositories
├── Service/                Business services
├── Form/                   Form types
├── Security/               Authentication and authorization
├── EventListener/
└── Kernel.php
config/services.yaml        Service definitions (DI container configuration)
```

**Compared to Laravel / TP**:

- Doctrine uses the **Data Mapper** pattern (entities have no knowledge of how they are persisted) — a completely different world from Eloquent / TP Model's Active Record
- Strong DI — all dependencies must be explicitly declared
- No facades, no auto-routing magic
- Steep learning curve; hard to hire for in China
- **Inheriting a Symfony project usually means the team has an overseas background, or the company is a domestic subsidiary acquired by a multinational**

---

## 8. Hyperf (High-Performance Choice Built on Swoole)

Gaining traction in China among ByteDance-affiliated and overseas-facing teams. Built on Swoole coroutines and uses a **persistent process model** (not traditional PHP-FPM's request-and-destroy lifecycle). You MUST **watch for global state contamination**.

```
app/
├── Controller/
├── Service/
├── Model/                  Hyperf DB
├── Process/                Persistent processes
├── Listener/
└── Middleware/
```

**When inheriting a Hyperf project**:

- NEVER use `static` variables as caches inside controllers / services — they persist across requests and will contaminate state
- ORM model properties are reused across requests; after assignment, `unset` them or create new instances
- Use coroutine context (`Hyperf\Utils\Context`) to store per-request data

---

## 9. Design Patterns (Domestic PHP Project Perspective)

| Pattern | When to use |
|---|---|
| **Service Layer** | ★ Nearly universal in domestic projects. Keeps controllers thin and models clean; business logic belongs in services |
| **Repository** | When you need DB-switching flexibility (e.g., multiple data sources, manual read/write splitting) |
| **DTO** (readonly class) | Cross-layer data transfer. **NEVER** return Eloquent / TP Model instances directly as responses |
| **FormRequest / Validate** | Centralized request validation |
| **Resource / Transformer** | Response field filtering (prevents field leaks) |
| **Event / Listener** | Decoupling side effects (send SMS after order creation, logging, push notifications) |
| **Job / Queue** | Async processing (exports, bulk operations, third-party API calls, push notifications) |
| **Facade** (Laravel only) | Global convenience access — but hard to mock; prefer constructor injection in new code |
| **Trait** | Cross-cutting reuse (e.g., `SoftDelete`, `HasTimestamps`) |

---

## 10. WeChat / Payment / China-Specific Scenarios (Required Reading)

> **The majority of domestic PHP projects will touch this area**: Official Accounts, Mini Programs, QR code payments, H5 payments, UnionPay, in-app payment callbacks. This section focuses on security-critical points.

### 10.1 WeChat Official Account / Mini Program Ecosystem

| Scenario | Recommended SDK |
|---|---|
| Official Account + Mini Program + WeCom | `w7corp/easywechat` (the de facto standard in China; formerly `overtrue/wechat`) |
| WeChat Pay v3 | `wechatpay/wechatpay` (official) or `yansongda/pay` (community; easier to use) |
| Alipay | `alipaysdk/easysdk` or `yansongda/pay` |
| UnionPay | Official UnionPay SDK (infrequently updated — wrap it in a thin abstraction layer) |

### 10.2 WeChat Pay Callback (notify_url) Security

**This is the #1 vulnerability scenario in domestic PHP.** Common anti-patterns:

```php
// ❌ High-frequency anti-pattern in domestic private servers / outsourced code: no signature verification at all
public function notify()
{
    $data = $_POST;
    if ($data['result_code'] === 'SUCCESS') {
        // Recharge! Add coins!
        Db::table('user')->where('id', $data['attach'])
            ->inc('coin', $data['total_fee']);   // ← anyone can POST and get coins
    }
    echo 'success';
}
```

**Correct implementation (WeChat Pay v3, APIv3 key + platform certificate)**:

```php
<?php
declare(strict_types=1);

namespace app\api\controller;

use WeChatPay\Crypto\AesGcm;
use WeChatPay\Crypto\Rsa;

public function wechatNotify(): \think\Response
{
    // 1. Extract signature headers
    $timestamp = $_SERVER['HTTP_WECHATPAY_TIMESTAMP'] ?? '';
    $nonce     = $_SERVER['HTTP_WECHATPAY_NONCE']     ?? '';
    $signature = $_SERVER['HTTP_WECHATPAY_SIGNATURE'] ?? '';
    $serial    = $_SERVER['HTTP_WECHATPAY_SERIAL']    ?? '';

    // 2. Read raw body (MUST use php://input, not $_POST)
    $body = file_get_contents('php://input');

    // 3. Replay protection: timestamp must be within ±5 minutes
    if (abs(time() - (int) $timestamp) > 300) {
        return response('replay', 400);
    }

    // 4. Verify signature using the WeChat platform certificate public key (serial determines which cert to use)
    $verifyMsg = "$timestamp\n$nonce\n$body\n";
    $publicKey = $this->loadPlatformCert($serial);
    if (!Rsa::verify($verifyMsg, $signature, $publicKey)) {
        return response('sign fail', 401);
    }

    // 5. Decrypt the resource (AES-GCM using the APIv3 key)
    $payload = json_decode($body, true);
    $plain = AesGcm::decrypt(
        $payload['resource']['ciphertext'],
        config('wechat.apiv3_key'),
        $payload['resource']['nonce'],
        $payload['resource']['associated_data'],
    );
    $order = json_decode($plain, true);

    // 6. ★ Idempotency: DB unique-key constraint + status check
    $localOrder = Db::table('orders')->where('out_trade_no', $order['out_trade_no'])->find();
    if (!$localOrder || $localOrder['status'] !== 'pending') {
        return response('success', 200);    // Already processed — return success idempotently
    }

    // 7. ★ Amount verification: MUST use the local order amount — NEVER trust the callback amount
    if ((int) $localOrder['total_fee'] !== (int) $order['amount']['total']) {
        return response('amount mismatch', 400);
    }

    // 8. Update order status + fulfill in a transaction
    Db::transaction(function () use ($localOrder, $order) {
        Db::table('orders')->where('id', $localOrder['id'])
            ->where('status', 'pending')   // ← optimistic lock
            ->update(['status' => 'paid', 'paid_at' => date('Y-m-d H:i:s')]);
        // Fulfill: ship item / add coins / deliver card key
    });

    return response('success', 200);
}
```

**Payment callback audit checklist for domestic private servers / outsourced PHP**:

| Check | Vulnerability |
|---|---|
| Is the signature verified? | Forged recharge (direct POST with `result_code=SUCCESS`) |
| Is verification done against the raw body (`php://input`)? | Using `$_POST` allows PHP to reorder params, breaking or bypassing signature verification |
| Is the amount compared against the local order amount? | ¥1 purchase credits ¥1000 worth of coins |
| Is the callback idempotent (same `out_trade_no` delivered twice)? | Same order credited multiple times |
| Is `out_trade_no` verified to belong to this merchant? | Cross-merchant order impersonation |
| Is there an optimistic or row lock to prevent concurrent callbacks? | Concurrent delivery of two credits for one order |
| Are raw callback payloads logged? | No ability to replay or investigate incidents |
| Is `notify_url` in `routes/api.php` and explicitly **excluded from CSRF**? | Laravel's default web routes have CSRF — callbacks will be rejected unless placed in `api.php` |
| Is XXE handled? (legacy v2 XML interface) | XXE file read |

See WeChat Pay official security practices: https://pay.weixin.qq.com/doc/v2/merchant/4014394306

### 10.3 Alipay Callback

Alipay notify uses RSA public key signature verification + merchant application private key encryption:

```php
// Signature verification (works for both sync and async callbacks)
$alipayPublicKey = config('alipay.alipay_public_key');
$verifyResult = AlipaySdkHelper::rsaCheckV1($_POST, $alipayPublicKey, 'RSA2');
if (!$verifyResult) {
    exit('fail');
}

// After verification: same requirements apply — amount check + idempotency + status check
```

### 10.4 WeChat H5 / JSSDK / Mini Program Login

- `code2session` exchanges code for `openid` / `session_key` — domestic private-server user systems universally use `openid` as the primary identity
- **`session_key` MUST NEVER be sent to the frontend** — roughly 90% of legacy outsourced code gets this wrong
- Decrypt `encryptedData` (phone number, unionId) using AES-128-CBC with `session_key`

---

## 11. PHP Deployment Environments in China (Essential Knowledge)

Over 80% of Chinese PHP deployments use **Baota Panel**; the rest are spread across Docker, manual LNMP setups, and shared hosting:

| Scenario | Characteristics | Audit / maintenance notes |
|---|---|---|
| **Baota Panel** | `/www/wwwroot/<domain>/`, `/www/server/nginx/`, `/www/server/php/74/` (multiple PHP versions coexist) | Default port 8888; weak credentials and known CVEs are common; backups at `/www/backup/` |
| **Manual LNMP** | `/etc/nginx/`, `/etc/php/7.4/fpm/`, socket at `/run/php/` | Config scattered; requires grep to navigate |
| **Docker** | `docker-compose.yml` + multiple services | Generally more structured |
| **Shared hosting** (Aliyun / West.cn / legacy platforms) | PHP 5.6 / 7.0 + Apache, no SSH access | Legacy outsourcing / personal sites |
| **Windows + IIS + PHP** | Government / education legacy systems | `.htaccess` is ineffective; check `web.config` |

**Deployment-related security points**:

- Baota's default `phpinfo.php` at `/phpinfo.php` is exposed publicly
- Older Baota versions expose a `/pma` (phpMyAdmin) symlink by default
- Legacy outsourced projects commonly leave `phpinfo.php` / `info.php` / `test.php` / `1.php` in the web root
- Backup files are often in the site root: `*.sql`, `*.zip`, `*.tar.gz`, `backup_*`, `bak/`, `old/`, `www.zip`
- `.git/` directory exposure (deployed with `git pull` without removing `.git/`) — use `GitTools` to reconstruct source code

## 12. Domestic PHP Giants / Historical Legacy

| Company / Product | PHP Footprint |
|---|---|
| **Sina Weibo** (early) | Heavy PHP usage early on; later migrated to Java + Go, leaving a large PHP legacy |
| **Baidu Wenku / Baidu Zhidao** (early) | PHP + in-house framework (odp) |
| **58.com / Ganji** (early) | PHP |
| **Qunar** (early) | PHP, later polyglot |
| **Weibo (some services)** | Yaf (a C-extension PHP framework by Laruence) |
| **Tencent (some internal services)** | PHP (early QQ Space) |

**Frameworks commonly seen when auditing / rewriting legacy codebases**:

- **Yaf** (by Laruence) — a C-extension PHP framework; high performance, small community, sparse documentation
- **CodeIgniter** (CI) — the standard for early domestic outsourcing; simple and direct; no longer maintained
- **Custom MVC** — large companies' early projects; structure varies by team

---

# Part 2: Identifying Legacy Domestic PHP Code (Audit Assistance)

## 13. Quick Fingerprinting When You Receive an Unknown PHP Source Package

**Do not rush to read code first — fingerprint the project**. Command checklist:

```bash
# 1. Check root directory contents
ls -la

# 2. Check for Composer
test -f composer.json && cat composer.json | head -20

# 3. Find framework indicators
find . -maxdepth 3 -name 'think' -o -name 'artisan' -o -name 'index.php' | head

# 4. Find entry points
grep -rn '<?php' --include='index.php' --include='admin.php' . | head

# 5. Find legacy function usage (PHP 5 signals)
grep -rn 'mysql_query\|mysql_connect\|magic_quotes\|register_globals' . | head -20

# 6. Find backdoor signals
grep -rn 'eval(\$_\|eval(base64_\|assert(\$_\|preg_replace.*\/e' . | head

# 7. Find CMS indicator files
ls plus/ data/ dede/ 2>/dev/null      # DEDECMS
ls api/ phpcms/ caches/ 2>/dev/null   # PHPCMS
ls source/ upload/ template/ 2>/dev/null  # Discuz
```

## 14. Identification Table for Major Legacy CMS Platforms in China

| CMS | Indicator directories / files | Default admin path | Notable vulnerability history |
|---|---|---|---|
| **DEDECMS / DedeCMS** | `plus/`, `include/`, `dede/`, `data/common.inc.php`, `uploads/`, `a/` (static page generation) | `/dede/` | **China's most-exploited CMS**: `tpl.php` backend RCE, `plus/recommend.php` SQLi, `plus/search.php` SQLi, CVE-2018-20129 front-end file upload, CVE-2019-8362, CVE-2023-2928 file inclusion, CVE-2025-6335 dedetag.class.php RCE, `member/uploads_edit.php` variable overwrite, album zip upload extension bypass |
| **PHPCMS** | `phpcms/`, `api/`, `caches/`, `statics/`, URL pattern `index.php?m=xxx&c=xxx&a=xxx` | `/index.php?m=admin` | v9 `api.php?op=swfupload_json` upload, `flash_upload.php` arbitrary file upload, authkey leakage, multiple SQL injections |
| **Discuz!** | `source/`, `uc_server/`, `uc_client/`, `template/`, `config/config_global.php`, `data/cache/` | `/admin.php` | Multiple SQL / SSRF in Discuz X3.x; UC_KEY leakage leading to full-site compromise; `forum.php?mod=ajax&action=downremoteimg` SSRF; multiple plugin vulnerabilities |
| **ECShop** | `admin/`, `api/`, `includes/`, `themes/`, `data/`, `upload/`, `api/client/includes/lib_api.php` | `/admin/` | ECShop 2.x / 3.x `user.php` injection + RCE (referer parameter deserialization → eval) — a top cause of domestic webmaster server compromise |
| **Empire CMS** | `e/`, `d/`, `e/admin/`, `e/data/`, `e/class/connect.php` | `/e/admin/` | Backend SQL injection, template editor RCE |
| **Z-BlogPHP** | `zb_system/`, `zb_users/` | `/zb_system/login.php` | Rare |
| **Typecho** | `var/`, `usr/`, `config.inc.php` | `/admin/` | `install.php` deserialization RCE (CVE-2017-XXXX) |
| **ShopEx / ECStore** | `app/`, `cache/`, `config/` | `/shopadmin/` | No longer maintained; common in old sites |
| **MetInfo** | `admin/`, `include/`, `message/`, `feedback/` | `/admin/` | Multiple SQL injections, file inclusion |
| **CmsEasy** | `admin/`, `lib/`, `celive/`, `template/` | `/admin/` | Multiple RCEs, SQL injections across versions |
| **PHPWind** | `wind/`, `u/`, `bbs/` | No longer maintained | Legacy forum |

### 14.1 DEDECMS / DedeCMS — Extended Notes

**The king of PHP vulnerabilities in China.** The original free distribution caused widespread adoption, but when the vendor switched to a paid license (¥5,800/year) in 2017, most site owners refused to pay, causing **security patches to stall**. As of 2026, a large number of government, education, and small-enterprise sites are still running DEDECMS 5.7 SP2.

**Fingerprints**:

- Root contains `plus/` (front-end dynamic scripts) + `include/` (core library) + `dede/` (backend — directory name can be changed)
- `data/common.inc.php` contains DB credentials
- `member/` is the member center
- Templates are in `templets/`
- URLs often contain `?aid=` / `?tid=`
- Page footer shows "Powered by DedeCMS" or similar

**Audit entry points**:

1. `plus/*.php` — front-end dynamic scripts; **variable-overwrite vulnerabilities are extremely common** (`extract` / `$$var` / `parse_str`)
2. `member/*.php` — member center; exploitable after user registration
3. `dede/tpl.php` — backend template editor; can get a shell (post-authentication)
4. `data/` — cache / backups; often contains sensitive `*.bak` / `mysql_*.txt` files
5. `uploads/` — upload directory; check whether PHP execution is possible

Detailed vulnerability reproduction: https://xz.aliyun.com/t/9705

### 14.2 Legacy ThinkPHP (3.x / 5.x)

The framework itself has critical vulnerabilities:

| TP Version | Historical RCE | Verification method |
|---|---|---|
| TP 3.2.3 | `index.php?m=Home&c=Index&a=index&value[_method]=__construct&method[]=*&filter[]=system&server[]=id` constructor chain | Check for `application/` + `ThinkPHP/Library/Think/` |
| TP 5.0.x | CVE-2018-20062 `?s=/Index/\think\app/invokefunction&function=call_user_func_array&vars[0]=phpinfo&vars[1][]=1` | `composer.json` shows `topthink/framework 5.0.*` |
| TP 5.1.x | Similar invokefunction vector | `5.1.*` |
| TP 5.2 / 6.0 early | Deserialization chains | `6.0.x` |

**The first thing to do when inheriting a legacy TP project**: confirm the `topthink/framework` version in `composer.json`, the actual locked version in `composer.lock`, and the version in the header comment of `vendor/topthink/framework/src/think/App.php`. If the three disagree, the project has been tampered with.

### 14.3 Domestic Private-Server PHP Backends (Typical Source Package Style)

Chinese private servers for games like Legend, Miracle MU, KartRider, MapleStory, and Perfect World — their **recharge sites / GM backends** share common characteristics:

- Most use **loose PHP files** (no framework), or TP3 / CodeIgniter
- Crude directory structure: `pay/`, `gm/`, `admin/`, `api/`, `include/db.php`
- Database credentials hardcoded; commonly `root` + weak or empty password
- Payment callbacks almost always lack signature verification and amount validation
- GM backends often have no authentication, or hardcoded backdoor credentials like `admin/admin`, `gm/123456`
- Recharge tables are named obviously: `card_password`, `pay_log`, `gm_log`
- Commonly include `phpinfo.php`, `info.php`, `shell.php`, `1.php`, `x.php`

**Audit entry point order (private-server backends)**:

1. `include/config.php` / `db.php` / `inc/conn.php` → DB credentials, API keys, third-party platform secrets
2. `pay/*_notify.php` / `pay/notify_*.php` / `recharge.php` → payment callbacks: signature verification / replay / amount bypass
3. `admin/` / `gm/` / `manage/` → GM backend: auth bypass + SQLi + arbitrary file upload
4. `api/` → player endpoints: item operations / auth / horizontal privilege escalation
5. Loose `.php` files in root → debug / backdoor / backup files
6. `upload/` / `uploads/` / `attached/` → check whether PHP execution is possible (does `location ~ \.php$` in Nginx config cover the upload directory?)

**Integration with this skill set**: Private-server business logic vulnerabilities (item duplication, currency farming, injecting GM commands) are covered in `~/.claude/skills/ctf-game/references/server-audit.md`. This file covers PHP engineering standards and general web vulnerability patterns only.

## 15. Legacy PHP Code "Signal Light" Reference Table

When you receive an unknown PHP source package, **grep for these signals immediately** to assess its age and quality:

| Signal | Inference | Risk |
|---|---|---|
| `mysql_query()` / `mysql_connect()` | PHP 5 era (`mysql_*` removed in PHP 7) | Very high SQLi risk |
| `mysqli_query($conn, $sql)` + string concatenation | PHP 5.x; not using prepared statements | High SQLi risk |
| `mssql_query` / `mssql_*` | Ancient SQL Server interface | Fully deprecated |
| `register_globals = On` | PHP < 5.4 | Variable overwrite |
| `magic_quotes_gpc = On` | PHP < 5.4 | False sense of input filtering |
| No `namespace` declaration | Legacy / loose-file code | Global namespace pollution |
| `require_once '../config.php'` everywhere | Flat project, no autoload | Path traversal attack surface |
| `$_GET[...]` concatenated directly into SQL | High-frequency private-server pattern | SQLi |
| `eval(`, `assert(`, `create_function(` | Backdoor or dynamic execution | RCE |
| `base64_decode(` + `eval(` | Classic backdoor pattern | RCE |
| `preg_replace('/.../e', ...)` | `/e` modifier is deprecated and is an RCE vector | RCE |
| `extract($_GET)` / `extract($_POST)` | Variable extraction | Arbitrary variable overwrite |
| `parse_str($_GET['x'])` | Variable injection | Same as above |
| `$$var = ...` (variable variables) | Double-dollar notation | Overwrite arbitrary variables |
| `include $_GET['file']` | File inclusion | LFI / RFI |
| `file_put_contents(..., $_POST[...])` | Arbitrary write | Arbitrary file write / shell upload |
| `system($_GET[...])` / `exec(` / shell concatenation | Command execution | RCE |
| `unserialize($_COOKIE[...])` / `$_POST[...]` | Deserialization sink | POP chain RCE |
| `mt_rand()` / `rand()` used for tokens / passwords | Not cryptographically secure | Predictable values |
| `md5($password)` without salt | Legacy hashing | Rainbow table attack |
| `md5($password . SALT)` with a fixed salt | Weak | Still vulnerable to rainbow tables |
| No `composer.json` | Fully manual project organization | No dependency management |
| Content after closing `?>` in a file | Old style | Output contamination |
| `header("Content-Type: text/html; charset=gb2312")` | Legacy GBK-encoded site | Encoding injection |
| `iconv('GBK', 'UTF-8', ...)` used extensively | GBK legacy Chinese site | Encoding-based bypass |
| `error_reporting(0)` at top of file | Error suppression (common in backdoors) | Anti-detection |
| `@$_GET[...]` error suppression operator | Old-style code | Hides errors |

## 16. Modernization / Rewrite Strategy (when clients want to upgrade)

The migration path from legacy PHP to modern:

```
PHP 5.x legacy code (mysql_*, no namespace, loose files)
  ↓ Step 1: Add Composer + autoloading (PSR-4)
  ↓ Step 2: Add namespaces to .php files (organized by directory)
  ↓ Step 3: mysql_* → PDO + prepared statements, or migrate to a framework ORM
  ↓ Step 4: $_GET / $_POST → validators / FormRequests
  ↓ Step 5: Migrate to ThinkPHP 8 / Laravel 11 (preserve business logic, rewrite the presentation layer)
  ↓ Step 6: DB credentials move to .env; passwords switch to password_hash; sessions move to Redis
```

**Tools**:

- **Rector** — automates steps 1–4 (PHP version upgrades + partial SQL refactoring). Rule set: `Rector\Set\ValueObject\LevelSetList::UP_TO_PHP_83`
- **php-cs-fixer** — consistent code style
- **PHPStan** — catches type errors and undefined variables

---

# Part 3: Anti-Pattern Catalog (ordered by domestic frequency)

## 17. High-Frequency Anti-Patterns (by actual occurrence rate in domestic projects)

| # | Anti-Pattern | Severity | Frequency | Consequence |
|---|---|---|---|---|
| 1 | SQL concatenation (any form) | **Critical** | High | SQLi |
| 2 | WeChat / Alipay callback with no signature verification | **Critical** | High (virtually guaranteed in private servers / outsourced code) | Forged recharge |
| 3 | Payment callback with no amount check / no idempotency | **Critical** | High | ¥1 purchase for ¥1000 worth of credits |
| 4 | md5 / sha1 password hashing (no salt or fixed salt) | **Critical** | High (100% in legacy CMS / private servers) | Rainbow table attack |
| 5 | TP auto-routing + admin controller with no auth middleware | High | Medium | Backend directly accessible |
| 6 | Upload directory under web root with Nginx executing PHP | High | High | Remote shell |
| 7 | DB credentials hardcoded in `.php` files | High | High | Information leakage |
| 8 | Legacy CMS not patched (DEDECMS 5.7 / Discuz 3.x) | **Critical** | High | Known CVEs exploitable directly |
| 9 | Returning Eloquent / TP Model directly as response | High | High | Field leakage (phone numbers / ID numbers / password hashes) |
| 10 | No FormRequest / Validate — using `$request->input()` directly everywhere | Medium | High | Scattered, inconsistent validation |
| 11 | `$_GET` / `$_POST` concatenated into `include` / `file_*` functions | **Critical** | Medium | LFI / arbitrary file access |
| 12 | Missing `declare(strict_types=1)` | Medium | High | Implicit type coercion bugs |
| 13 | God Controller (business logic crammed into controllers) | High | High | Untestable, impossible to refactor |
| 14 | No CSRF protection (non-API routes) | High | Medium | CSRF attacks |
| 15 | Global mutable `$GLOBALS` in legacy code | High | Medium | Implicit hidden dependencies |
| 16 | No type declarations (no parameter or return types) | Medium | High | IDE cannot help; silent bugs |
| 17 | `eval` / `assert` / `preg_replace /e` | **Critical** | Medium (legacy / backdoors) | RCE |
| 18 | Deserializing user input | **Critical** | Medium | POP chain RCE |
| 19 | Using `@` to suppress errors | Medium | High | Hides bugs; performance overhead |
| 20 | Global Facade calls that are hard to mock (Laravel) | Medium | High | Difficult to test |
| 21 | TP / Laravel models without a `$fillable` whitelist | High | High | Mass-assignment vulnerability |
| 22 | `phpinfo.php` / `test.php` / backup `.sql` files exposed in webroot | High | High | Information leakage |
| 23 | `.git/` directory exposed | High | High | Source code leakage |
| 24 | Sessions stored in files on multi-server deployments without sharing | Medium | Medium | Login state lost across servers |
| 25 | Hyperf project using `static` for caching | High | Low | Cross-request data contamination |

## 18. Security Audit Checklist (private servers / outsourced projects)

```
□ Framework version (TP / Laravel / Yii / CMS) and whether the latest patches are applied
□ Where DB credentials are stored (.env / config / hardcoded)
□ Whether .git / .svn / .bak / *.sql / phpinfo / backup archives are exposed
□ Payment callbacks: signature verification + amount check + idempotency
□ File upload: extension whitelist / content inspection / PHP execution blocked in upload directory
□ SQL: are all queries using prepared statements / Query Builder / ORM
□ Command execution: grep system/exec/shell_exec/passthru/popen/proc_open/`/eval/assert
□ Deserialization: unserialize on user input / __wakeup / __destruct classes
□ Authentication: backend middleware / API token / Sanctum / JWT
□ Authorization: horizontal escalation (user A accessing user B's resources) / vertical escalation (regular user accessing admin)
□ XSS: does the template engine escape by default (Blade {{ }} does; TP {$var} does NOT by default!)
□ CSRF: enabled on web routes; notify endpoints excluded from CSRF verification
□ Passwords: password_hash / password_verify; NEVER md5
□ Sessions: Redis / DB storage; cookies with httpOnly + secure + sameSite
□ Logging: are sensitive operations logged; is log content leaking into responses
□ Debug mode disabled in production (APP_DEBUG=false / app_debug=false)
□ CORS: is Access-Control-Allow-Origin too permissive
□ Redis / MySQL: are they bound to 0.0.0.0 and exposed to the public internet
□ Baota Panel: latest version / entry path changed / no weak credentials
```

---

## 19. Authoritative References

**Official / Standards**:

- [PHP-FIG PSR Index](https://www.php-fig.org/psr/)
- [PSR-12 Full Text](https://www.php-fig.org/psr/psr-12/)
- [PHP The Right Way](https://phptherightway.com/) — community index
- [PHP Official Documentation](https://www.php.net/manual/zh/) — Chinese edition

**Frameworks**:

- [ThinkPHP 8 Official Docs](https://doc.thinkphp.cn/v8_0/) — native Chinese
- [ThinkPHP 6 Complete Guide](https://www.kancloud.cn/manual/thinkphp6_0/)
- [Laravel Official](https://laravel.com/docs) / [Learnku Laravel Chinese Docs](https://learnku.com/docs/laravel)
- [Symfony Official](https://symfony.com/doc)
- [Hyperf Official](https://hyperf.wiki/)

**Tools**:

- [PHPStan](https://phpstan.org/) / [Psalm](https://psalm.dev/)
- [Pest PHP](https://pestphp.com/) / [PHPUnit](https://phpunit.de/)
- [Rector](https://getrector.com/) — automated code upgrades

**Domestic SDKs**:

- [EasyWeChat](https://www.easywechat.com/) — the de facto standard for WeChat development in China
- [yansongda/pay](https://pay.yansongda.cn/) — unified payment aggregation
- [WeChat Pay Merchant Documentation](https://pay.weixin.qq.com/doc/v3/merchant/) — payment security specifications
- [Alipay Open Platform Documentation](https://opendocs.alipay.com/)

**Security / Auditing**:

- [Xz.aliyun.com - DEDECMS Vulnerability Summary](https://xz.aliyun.com/t/9705)
- [BaizeSec bylibrary - CMS Vulnerability Library](https://github.com/BaizeSec/bylibrary)
- Private-server / game backend logic vulnerabilities → `~/.claude/skills/ctf-game/references/server-audit.md`
- General web vulnerability patterns → OWASP Top 10 / PortSwigger Academy
