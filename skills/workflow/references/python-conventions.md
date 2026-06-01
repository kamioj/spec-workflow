---
name: Python 工程化规范（自写 / 国内主流视角）
scope: 通用 Python 规范 + 国内 Web 后端（Flask / Django+DRF / FastAPI）+ 国内工具链与部署
note: PEP 8 / 257 / 484 不重抄；本文件聚焦国内实战主流，国外推荐作为升级路径标注
audience: 国内 Python 后端 / 全栈 / 爬虫 / AI 服务 / 政企外包 / 量化场景
---

# Python 工程化规范（国内主流视角）

> 写作立场：本文档的"主流"指**中国大陆 2024-2026 实际生产代码库中的常见做法**，不是 PyPA / Real Python / Tiangolo 视角的"国际最佳实践"。差异本身就是事实，不做价值判断；但**新项目升级路径**会单独标注，便于团队渐进迁移。

## 1. 官方权威与编码风格基线

PEP 不抄，链接即可：

| 文档 | 链接 | 范围 |
|---|---|---|
| **PEP 8** | https://peps.python.org/pep-0008/ | 代码风格基线（必须读） |
| **PEP 257** | https://peps.python.org/pep-0257/ | docstring 约定 |
| **PEP 484** | https://peps.python.org/pep-0484/ | type hints |
| **PEP 526** | https://peps.python.org/pep-0526/ | 变量类型注解语法 |
| **阿里巴巴 Python 开发手册** | 各大厂内部派生版较多，未官方公开 | 强约束命名 / docstring / 异常 |

**国内团队 PEP 8 常见落地**：

- 缩进 4 空格（不用 Tab）
- 单行 ≤ 120 字符（国内团队普遍放宽到 100-120，89/79 罕见 —— 中文注释 + 长变量名挤不下）
- 函数 / 变量 `snake_case`，类 `PascalCase`，常量 `UPPER_SNAKE`
- import 顺序：stdlib → 第三方 → 本地，组间空行（isort 默认 profile）
- 中文注释占比高，关键业务逻辑必写；docstring 不少团队写中文（对内不对外则无所谓）
- 私有方法 `_` 前缀，严格私有 `__` 前缀（很少用，dunder 冲突）

**国内 docstring 现状**：reStructuredText 老项目沿用，Google style 新项目居多，Numpy style 数据 / 算法团队偏好。**很多公司压根不强制 docstring**，只在 SDK 类对外项目里写。

---

## 2. 工具链：国内现实 vs 国外推荐

### 2.1 包管理（国内现实）

| 工具 | 国内占比（估测） | 场景 |
|---|---|---|
| **pip + requirements.txt + venv / virtualenv** | ★★★★★ 60-75%（绝对主流） | 默认选择，所有教程、培训、外包项目起手式 |
| **pip + requirements.txt + conda** | ★★★★ 15-25% | 数据 / 算法 / AI / 量化团队 |
| **Pipenv** | ★ < 5% | 中期网红，现在基本无人新用 |
| **Poetry** | ★★ 5-10% | 互联网中大厂、对依赖锁有要求的团队 |
| **uv** | ★ < 5%（增长快） | 2026 新项目尝鲜，CI 提速场景 |
| **pdm / hatch** | ★ < 2% | 极少 |

**国内典型 `requirements.txt`**（必备）：

```text
# requirements.txt  ← 业务依赖
Flask==2.3.3
SQLAlchemy==2.0.25
redis==5.0.1
celery==5.3.4
requests==2.31.0
gunicorn==21.2.0

# requirements-dev.txt  ← 开发工具，可选拆分
pytest==7.4.3
flake8==6.1.0
black==23.12.1
isort==5.13.2
ipython
```

**国内默认源**（写在 `~/.pip/pip.conf` 或 `pip.ini`）：

```ini
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
# 备选：
# https://mirrors.aliyun.com/pypi/simple
# https://pypi.mirrors.ustc.edu.cn/simple
# https://mirrors.cloud.tencent.com/pypi/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
```

**版本钉死**：国内项目几乎 100% 用 `==` 完全钉版本，不像国际项目流行 `~=` / `>=`。原因：依赖混乱导致上线翻车的伤太深。

**虚拟环境位置约定**：
- 项目根目录下 `venv/` 或 `.venv/`（最常见）
- 老项目用 `virtualenv`（功能等同 `python -m venv`），新项目直接 `python -m venv .venv`
- 算法 / AI 团队普遍用 `conda env` + `environment.yml`

### 2.2 升级路径：uv（推荐新项目逐步引入）

uv 是 Astral 出的 Rust 实现，10-100× 快于 pip，2026 在国内增长极快但远未成主流。**新项目建议直接上 uv**，老项目维持 pip。

```bash
# uv 起手
uv init my-service
uv add fastapi 'pydantic>=2.9' sqlalchemy
uv add --dev pytest ruff mypy
uv run python -m app
uv sync  # 团队成员同步

# 仍可导出 requirements.txt 兼容老 CI
uv export --format requirements-txt > requirements.txt
```

`pyproject.toml`（uv / 现代化模板）：

```toml
[project]
name = "my-service"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "fastapi>=0.115",
    "pydantic>=2.9",
    "sqlalchemy>=2.0",
]

[dependency-groups]
dev = ["pytest>=8", "pytest-asyncio", "httpx", "ruff>=0.6", "mypy>=1.11"]
```

### 2.3 Lint / Format（国内现实）

| 工具组合 | 国内占比 | 备注 |
|---|---|---|
| **flake8 + black + isort（三件套）** | ★★★★★ 主流 | 教程、招聘要求、阿里 / 字节内部均常见 |
| **pylint** | ★★ 老项目 / 部分严格团队 | 报错多、配置烦，新项目少用 |
| **autopep8 / yapf** | ★ 个别 | yapf 是 Google 风格，国内少 |
| **ruff** | ★★ 增长中 | 大厂部分项目 / 新项目，2026 处于"知道但还没换"阶段 |

**国内最常见 `.flake8`**：

```ini
[flake8]
max-line-length = 120
exclude = .git,__pycache__,venv,.venv,migrations
ignore =
    E203,  # 与 black 冲突（slice 空格）
    W503,  # 二元运算符换行（black 风格相反）
    E501,  # 行长（交给 black）
per-file-ignores =
    __init__.py:F401  # 允许未使用的 import（包导出用）
```

**pyproject.toml 中的 black + isort**：

```toml
[tool.black]
line-length = 120
target-version = ['py310']
extend-exclude = '''
/(
  | migrations
  | \.venv
)/
'''

[tool.isort]
profile = "black"      # 与 black 兼容
line_length = 120
known_first_party = ["app", "myproject"]
```

### 2.4 升级路径：ruff（替代 flake8 + isort + 部分 black）

```toml
[tool.ruff]
line-length = 120
target-version = "py310"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "SIM"]
ignore = ["E501"]

[tool.ruff.format]
quote-style = "double"
```

**迁移建议**：保留 `black` 做 format（同事熟），`ruff` 接管 `flake8 + isort`，渐进过渡。

### 2.5 类型检查（国内现状）

国内 type hints 覆盖率远低于国外：
- **新项目函数签名写**（约 60-70%），**老项目几乎不补**
- **mypy strict 严格模式**：仅大厂内部 / SDK 类项目用
- **pyright / Pylance**：编辑器层面有就用，CI 强校验罕见
- **TypedDict / Protocol / 泛型**：用得少，多数停留在"函数签名 + 容器类型"层面

**务实策略**：

```python
# 国内务实风格：边界写、内部简单的不写
def get_user_by_id(user_id: int) -> dict | None:
    # 内部实现里临时变量不强求注解
    rows = db.execute(...).fetchall()
    if not rows:
        return None
    return {"id": rows[0][0], "name": rows[0][1]}

# 边界（API / 库函数）必须写
def create_order(
    user_id: int,
    items: list[dict],
    coupon_code: str | None = None,
) -> Order:
    ...
```

---

## 3. Type Hints 实战要点

```python
# ✅ Python 3.10+ 用 | 而非 Optional（Optional 在 3.9 老项目仍可见）
def fetch(id: int) -> User | None: ...

# ✅ 内置容器类型，不写 List / Dict（typing 模块在 3.9+ 已弱化）
def names(users: list[User]) -> dict[int, str]: ...

# ✅ TypedDict 描述固定字段字典
from typing import TypedDict
class OrderDict(TypedDict):
    order_id: int
    amount: float
    status: str

# ✅ Pydantic 用于 API / 配置 边界
from pydantic import BaseModel, EmailStr, Field

class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=32)
    email: EmailStr
    age: int = Field(ge=0, le=150)

# ✅ dataclass 用于内部 DTO
from dataclasses import dataclass
@dataclass
class PriceCalcResult:
    subtotal: float
    tax: float
    total: float
```

**何时用什么**：

| 场景 | 选择 |
|---|---|
| HTTP API 请求 / 响应 | **Pydantic**（运行时校验，FastAPI 原生） |
| Flask / Django 表单 / 序列化 | **WTForms / DRF Serializer**（生态自有方案，不强切 Pydantic） |
| 内部数据传递 | `dataclass` / `TypedDict` |
| 配置（.env） | `pydantic-settings` / Django 自带 settings / `os.environ` |
| 业务领域对象 | `dataclass` + 方法，重逻辑用类 |

---

## 4. 三大 Web 框架决策矩阵（含国内场景倾向）

| 维度 | Django | FastAPI | Flask |
|---|---|---|---|
| 定位 | 全栈 batteries-included | 现代异步 API | 极简微框架 |
| ORM | 内置 Django ORM | SQLAlchemy / SQLModel | 自选（Flask-SQLAlchemy 主流） |
| Admin | ✅ 内置（国内后台首选） | ❌ | ❌ |
| 表单 / 校验 | Django Forms / DRF Serializer | Pydantic 原生 | WTForms / 手写 |
| 自动 API 文档 | drf-spectacular / drf-yasg | ✅ OpenAPI 原生 | apispec / flasgger（手动） |
| async | 部分支持，国内少用 | ✅ 原生 | 有限 |
| 学习曲线 | 中（约定多） | 低（声明式） | 低（自由度高） |
| 国内场景倾向 | **政企 OA / CRM / 后台 / 内容平台 / 私域工具** | **AI 服务 / 微服务 / 新 API / 量化接口** | **爬虫管理后台 / 中小工具 / 老项目 / 个人外包** |
| 国内占比（估测） | ★★★★ 35% | ★★★ 25%（快速上升） | ★★★★ 35%（存量大，新项目下降） |
| 招聘需求 | Django + DRF 仍是最稳的 Python Web 岗 | 增长最快 | 多见于"Python 全栈"模糊岗 |

**默认建议（国内务实版）**：

- 政企外包 / 企业后台 / 内容管理 → **Django + DRF**（Admin 直接省一半人月）
- AI 推理 / 模型服务 / 微服务 → **FastAPI**（异步 + 文档 + Pydantic 一站式）
- 爬虫管理 / 小工具 / 个人项目 / 维护老系统 → **Flask**
- 量化策略 / 数据接口 → **FastAPI**（性能 + 类型）
- 不确定 + 团队多 Java 背景 → **Django**（约定明确，撕逼少）

---

## 5. Flask 项目结构（国内主流 vs Flask 官方推荐）

### 5.1 国内绝对主流：按层平铺（Java SSM 风格移植）

国内 Flask 项目 80%+ 采用此结构。受 Java Spring SSM（Controller-Service-DAO）影响，团队成员易上手，跨语言迁移成本低。

```
my_flask_app/
├── app/
│   ├── __init__.py             ← create_app() 工厂 + 扩展初始化
│   ├── config.py               ← 配置类（Dev / Prod / Test）
│   ├── extensions.py           ← db / redis / migrate / cache 实例统一在这
│   ├── controllers/            ← 路由 + HTTP I/O（薄）
│   │   ├── __init__.py
│   │   ├── user_controller.py
│   │   ├── order_controller.py
│   │   └── auth_controller.py
│   ├── services/               ← 业务逻辑（厚）
│   │   ├── __init__.py
│   │   ├── user_service.py
│   │   ├── order_service.py
│   │   └── auth_service.py
│   ├── models/                 ← SQLAlchemy ORM
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── order.py
│   │   └── base.py
│   ├── schemas/                ← Marshmallow / Pydantic 序列化（可选）
│   │   ├── user_schema.py
│   │   └── order_schema.py
│   ├── utils/                  ← 工具函数（杂物间，注意别变垃圾桶）
│   │   ├── jwt_helper.py
│   │   ├── redis_helper.py
│   │   └── decorators.py
│   ├── tasks/                  ← Celery 任务
│   │   ├── __init__.py
│   │   └── email_tasks.py
│   └── exceptions.py           ← 自定义异常
├── migrations/                 ← Flask-Migrate / alembic
├── tests/
├── logs/
├── requirements.txt
├── requirements-dev.txt
├── .flaskenv
├── config.py                   ← 顶层配置或 .env
├── manage.py / run.py / wsgi.py
└── README.md
```

**典型 `app/__init__.py`**：

```python
# app/__init__.py
from flask import Flask
from app.extensions import db, migrate, redis_client, jwt
from app.config import config_map


def create_app(env: str = "dev") -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_map[env])

    # 扩展初始化
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    redis_client.init_app(app)

    # 注册蓝图（每个 controller 一个蓝图，单文件不嵌套）
    from app.controllers.user_controller import user_bp
    from app.controllers.order_controller import order_bp
    from app.controllers.auth_controller import auth_bp

    app.register_blueprint(user_bp, url_prefix="/api/users")
    app.register_blueprint(order_bp, url_prefix="/api/orders")
    app.register_blueprint(auth_bp, url_prefix="/api/auth")

    # 全局错误处理
    from app.exceptions import register_error_handlers
    register_error_handlers(app)

    return app
```

**典型 controller**：

```python
# app/controllers/user_controller.py
from flask import Blueprint, request, jsonify
from app.services.user_service import UserService
from app.utils.decorators import login_required

user_bp = Blueprint("user", __name__)


@user_bp.route("", methods=["GET"])
@login_required
def list_users():
    page = int(request.args.get("page", 1))
    size = int(request.args.get("size", 20))
    data, total = UserService.list_users(page, size)
    return jsonify({"code": 0, "data": data, "total": total})


@user_bp.route("/<int:user_id>", methods=["GET"])
def get_user(user_id: int):
    user = UserService.get_user(user_id)
    if not user:
        return jsonify({"code": 404, "msg": "用户不存在"}), 404
    return jsonify({"code": 0, "data": user})
```

**典型 service**：

```python
# app/services/user_service.py
from app.extensions import db
from app.models.user import User


class UserService:
    @staticmethod
    def list_users(page: int, size: int) -> tuple[list[dict], int]:
        query = User.query.filter_by(is_deleted=False)
        total = query.count()
        users = query.offset((page - 1) * size).limit(size).all()
        return [u.to_dict() for u in users], total

    @staticmethod
    def get_user(user_id: int) -> dict | None:
        user = User.query.get(user_id)
        return user.to_dict() if user else None

    @staticmethod
    def create_user(name: str, email: str, password: str) -> User:
        user = User(name=name, email=email)
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        return user
```

**国内特征**：
- `controller / service / model` 全部顶层平铺，**按文件类型组织**
- 蓝图通常**一个 controller 文件一个蓝图**，不再嵌套包
- `Service` 多写成 `@staticmethod` 类（Java 静态工具类思路），也有人写模块级函数
- `to_dict()` 直接挂在 Model 上（很多团队懒得引入 Marshmallow）
- `extensions.py` 集中放 `db = SQLAlchemy()` 等单例，避免循环 import

### 5.2 Flask 官方推荐：按功能分蓝图（国外主流）

Flask 官方教程 + Miguel Grinberg + zhanymkanov FastAPI Best Practices 都倾向**按业务功能分模块**：

```
my_flask_app/
├── app/
│   ├── __init__.py
│   ├── auth/                   ← 按功能：每个模块自带 routes/services/models
│   │   ├── __init__.py
│   │   ├── routes.py
│   │   ├── services.py
│   │   ├── models.py
│   │   └── forms.py
│   ├── orders/
│   │   ├── routes.py
│   │   ├── services.py
│   │   └── models.py
│   ├── users/
│   │   └── ...
│   └── core/
│       ├── config.py
│       └── extensions.py
└── ...
```

**对照表**：

| 维度 | 按层平铺（国内主流） | 按功能分蓝图（国外推荐） |
|---|---|---|
| 心智模型 | "我要改路由 → controllers/" | "我要改用户模块 → users/" |
| 跨语言迁移 | Java / Go / PHP 友好 | Python / Ruby / DDD 友好 |
| 模块边界 | 弱（同层文件互相 import 容易） | 强（模块自治） |
| 拆分微服务 | 难（要按业务横切） | 易（一个模块就是一个候选服务） |
| 团队规模 | 适合 ≤ 10 人小团队 | 适合 10+ 人 / 多业务线 |
| 文件查找 | 类型已知时快 | 业务已知时快 |

**结论**：国内主流按层平铺没问题，**但项目超过 30 个 controller 文件**时强烈建议切按功能分模块，否则 `services/` 目录会变成 50 个文件的灾难。

---

## 6. Django + DRF 项目结构（国内主流）

国内 Django 项目 90% 用 **DRF（Django REST Framework）** 做 API。

```
my_django_project/
├── manage.py
├── requirements.txt
├── config/                     ← 项目配置目录（不叫 mysite 了，约定俗成）
│   ├── __init__.py
│   ├── settings/               ← 国内强烈推荐拆分多环境
│   │   ├── __init__.py
│   │   ├── base.py             ← 公共配置
│   │   ├── dev.py              ← from .base import *
│   │   ├── test.py
│   │   └── prod.py
│   ├── urls.py                 ← 根 URL（include 各 app）
│   ├── wsgi.py
│   └── asgi.py
├── apps/                       ← 国内必备：把所有 app 装在 apps/ 下统一管理
│   ├── __init__.py
│   ├── users/
│   │   ├── __init__.py
│   │   ├── apps.py
│   │   ├── models.py           ← ORM 模型
│   │   ├── serializers.py      ← DRF 序列化器
│   │   ├── views.py            ← DRF ViewSet / APIView
│   │   ├── urls.py             ← 子路由
│   │   ├── admin.py            ← Django Admin 配置
│   │   ├── permissions.py      ← 自定义权限（可选）
│   │   ├── filters.py          ← django-filter（可选）
│   │   ├── services.py         ← 业务逻辑层（国内常加，标准 Django 没有）
│   │   ├── tasks.py            ← Celery 任务（可选）
│   │   └── migrations/
│   ├── orders/
│   │   └── ...
│   └── common/                 ← 公共 app：基础模型 / 工具
├── utils/                      ← 项目级工具（不属于任何 app）
├── templates/
├── static/
├── media/
├── logs/
└── README.md
```

**关键约定**：

- `INSTALLED_APPS` 里写 `apps.users` 而非 `users`（因为 app 在 `apps/` 目录下）
- 每个 app 要在 `apps.py` 设 `name = "apps.users"`
- `settings/` 拆分多环境**几乎是国内标配**，根目录单 `settings.py` 仅见于教程项目
- **services.py 是国内 Django 项目自发演化出来的**（Django 官方没有 service 层概念），用来从 view / serializer 里抽取业务逻辑

### 6.1 典型 DRF 视图

```python
# apps/users/views.py
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from apps.users.models import User
from apps.users.serializers import UserSerializer, UserCreateSerializer
from apps.users.services import UserService


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.filter(is_deleted=False)
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.action == "create":
            return UserCreateSerializer
        return UserSerializer

    @action(detail=True, methods=["post"])
    def reset_password(self, request, pk=None):
        user = self.get_object()
        UserService.reset_password(user, request.data.get("new_password"))
        return Response({"msg": "重置成功"})
```

### 6.2 典型 DRF 序列化器

```python
# apps/users/serializers.py
from rest_framework import serializers
from apps.users.models import User


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "username", "email", "created_at"]
        read_only_fields = ["id", "created_at"]


class UserCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = User
        fields = ["username", "email", "password"]

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("邮箱已注册")
        return value

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)
```

### 6.3 国内 DRF 项目常见模式

- **统一响应格式**：自定义 `Response` 或 renderer，让前端固定收 `{code, msg, data}` 格式
- **JWT 鉴权**：`djangorestframework-simplejwt`（已成事实标准）
- **分页**：DRF 自带分页类自定义，统一 `?page=&size=`
- **API 文档**：`drf-spectacular`（OpenAPI 3，推荐）/ `drf-yasg`（老，Swagger 2）
- **过滤搜索**：`django-filter` + DRF `filter_backends`
- **国际化**：政企项目少用，对外项目用 Django i18n

---

## 7. FastAPI 项目结构

### 7.1 国内主流：按层分（与 zhanymkanov 推荐相反）

国内 FastAPI 项目大量沿用 Flask / Django 的"按层平铺"思维。zhanymkanov 的 [FastAPI Best Practices](https://github.com/zhanymkanov/fastapi-best-practices) 推荐"按功能分领域"，**国内仍以按层为主**：

```
my_fastapi_app/
├── app/
│   ├── __init__.py
│   ├── main.py                 ← FastAPI 实例 + include_router
│   ├── core/
│   │   ├── config.py           ← pydantic-settings
│   │   ├── security.py         ← JWT / 密码哈希
│   │   ├── database.py         ← SQLAlchemy engine / session
│   │   └── deps.py             ← 通用依赖（get_db / get_current_user）
│   ├── routers/                ← API 路由（薄）
│   │   ├── __init__.py
│   │   ├── users.py
│   │   ├── orders.py
│   │   └── auth.py
│   ├── services/               ← 业务逻辑
│   │   ├── user_service.py
│   │   └── order_service.py
│   ├── models/                 ← SQLAlchemy ORM
│   │   ├── user.py
│   │   └── order.py
│   ├── schemas/                ← Pydantic（请求/响应）
│   │   ├── user.py
│   │   └── order.py
│   ├── crud/                   ← 可选：DB 访问层（Repository 风格）
│   ├── tasks/                  ← Celery
│   └── utils/
├── tests/
├── alembic/                    ← 迁移
├── alembic.ini
├── requirements.txt
└── README.md
```

### 7.2 国外推荐：按功能分领域（zhanymkanov）

```
src/
├── auth/                       ← 每个领域自包含
│   ├── router.py
│   ├── schemas.py
│   ├── models.py
│   ├── service.py
│   ├── dependencies.py
│   ├── exceptions.py
│   └── constants.py
├── users/
├── orders/
├── core/
└── main.py
```

**差异与建议**：

| 维度 | 国内按层 | 国外按功能 |
|---|---|---|
| 上手难度 | 低（Flask / Django 用户秒懂） | 中（要先理解领域边界） |
| 小项目（< 5 模块） | ✅ 更清晰 | 模块壳太多 |
| 大项目（> 10 模块） | services/ 会爆炸 | ✅ 自然伸展 |
| 拆微服务 | 难 | ✅ 一个目录拆一个 |

**实用建议**：
- 项目预计 < 10 个业务模块 / 团队 < 5 人 → 按层平铺即可
- 项目长期演进 / 多业务线 / 团队 > 5 人 → 直接上按功能分领域

### 7.3 典型 router / service

```python
# app/routers/users.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db, get_current_user
from app.schemas.user import UserCreate, UserOut
from app.services import user_service

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("", response_model=list[UserOut])
async def list_users(
    page: int = 1,
    size: int = 20,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_user),
):
    return await user_service.list_users(db, page, size)


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(data: UserCreate, db: AsyncSession = Depends(get_db)):
    if await user_service.email_exists(db, data.email):
        raise HTTPException(status_code=400, detail="邮箱已存在")
    return await user_service.create_user(db, data)
```

```python
# app/services/user_service.py
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.user import UserCreate


async def list_users(db: AsyncSession, page: int, size: int) -> list[User]:
    stmt = select(User).offset((page - 1) * size).limit(size)
    return (await db.execute(stmt)).scalars().all()


async def email_exists(db: AsyncSession, email: str) -> bool:
    stmt = select(User).where(User.email == email)
    return (await db.execute(stmt)).scalar_one_or_none() is not None


async def create_user(db: AsyncSession, data: UserCreate) -> User:
    user = User(email=data.email, name=data.name)
    user.set_password(data.password)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user
```

---

## 8. ORM 选型（国内现状）

| ORM | 场景 | 国内占比 |
|---|---|---|
| **Django ORM** | Django 项目自带，简单易用 | Django 项目 100% |
| **SQLAlchemy 2.0** | FastAPI / Flask 主流，支持异步 | 大中型项目主流 |
| **Flask-SQLAlchemy** | Flask 项目薄封装 SQLAlchemy | Flask 项目 80%+ |
| **Peewee** | 轻量、易学，老项目 / 小工具 | 个人项目 / 老外包 |
| **Tortoise ORM** | 全异步、模仿 Django ORM 风格 | FastAPI 小众选择 |
| **SQLModel** | Pydantic + SQLAlchemy 一体 | FastAPI 新尝试，未普及 |

**SQLAlchemy 异步模板**：

```python
# app/core/database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

DATABASE_URL = "mysql+aiomysql://user:pass@127.0.0.1:3306/mydb?charset=utf8mb4"

engine = create_async_engine(DATABASE_URL, pool_size=20, pool_recycle=3600, echo=False)
async_session = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with async_session() as session:
        yield session
```

**国内数据库偏好**：
- MySQL 绝对主流（80%+），字符集**必须** `utf8mb4`（emoji 兼容）
- PostgreSQL 上升中，AI / 数据 / 互联网新项目偏好
- SQLite 仅本地开发 / 测试
- 国产数据库（达梦 / 人大金仓 / OceanBase）：政企项目需要时通过 SQLAlchemy 方言适配
- 迁移工具：Django 用自带 `makemigrations`，其他用 **alembic**

---

## 9. 异步任务：Celery 是国内事实标准

```
[Producer]  --send-->  [Broker: Redis / RabbitMQ]  --pull-->  [Worker]
                                                                  |
                                                          [Backend: Redis]
```

| 角色 | 国内常见选择 |
|---|---|
| Broker（消息队列） | **Redis**（小中型项目主流）/ RabbitMQ（大型 / 严格可靠性） |
| Backend（结果存储） | Redis |
| 监控 | Flower（Web UI）/ 自建监控 |
| 定时任务 | celery beat / APScheduler |

**典型配置**：

```python
# app/celery_app.py
from celery import Celery

celery_app = Celery(
    "my_app",
    broker="redis://127.0.0.1:6379/1",
    backend="redis://127.0.0.1:6379/2",
    include=["app.tasks.email_tasks", "app.tasks.report_tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Asia/Shanghai",
    enable_utc=False,
    task_track_started=True,
    task_time_limit=600,
    worker_max_tasks_per_child=1000,  # 防内存泄漏
    broker_connection_retry_on_startup=True,
)
```

```python
# app/tasks/email_tasks.py
from app.celery_app import celery_app

@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def send_email_task(self, to: str, subject: str, body: str):
    try:
        # 调邮件 SDK
        ...
    except Exception as exc:
        raise self.retry(exc=exc)
```

**启动命令**（生产）：

```bash
celery -A app.celery_app worker -l info -c 8 --max-tasks-per-child=1000
celery -A app.celery_app beat -l info       # 定时任务
celery -A app.celery_app flower             # 监控 UI
```

**国内常见坑**：
- Redis 当 broker 时 task 可能丢失（无 ACK 机制）—— 严格场景换 RabbitMQ
- `celery beat` 单实例运行（多实例会重复触发）—— 用 `celery-beat-cluster` 或 `redbeat` 解决
- 时区一定要 `Asia/Shanghai` 并 `enable_utc=False`（否则 beat 定时差 8 小时）

---

## 10. 部署：国内现实

### 10.1 国内部署方案分布

| 方案 | 国内占比 | 场景 |
|---|---|---|
| **uWSGI + Nginx + Supervisor** | ★★★★ 老项目 / 政企 / 外包默认 | 性能略优，配置烦 |
| **Gunicorn + Nginx + Supervisor / systemd** | ★★★★ 新项目主流 | 配置简单，Python 自身 |
| **宝塔面板（uWSGI / Gunicorn 自动配置）** | ★★★ 个人 / 中小企业 | GUI 友好，运维门槛低 |
| **Docker + Docker Compose** | ★★★ 互联网公司主流 | 标准化、易迁移 |
| **K8s** | ★★ 大厂 / 中台 | 复杂、配套运维成本高 |
| **Serverless（阿里云 FC / 腾讯云 SCF）** | ★ 小众，AI / 突发流量 | 冷启动慢，国内生态成熟度仍可 |
| **uvicorn（FastAPI 单进程）+ Nginx** | ★★ FastAPI 项目 | dev 用，prod 要 `gunicorn -k uvicorn.workers.UvicornWorker` |

### 10.2 典型 Gunicorn + Nginx + Supervisor

**`gunicorn_config.py`**：

```python
import multiprocessing

bind = "127.0.0.1:8000"
workers = multiprocessing.cpu_count() * 2 + 1   # 经典公式
worker_class = "sync"                            # FastAPI 用 "uvicorn.workers.UvicornWorker"
worker_connections = 1000
timeout = 60
keepalive = 5
accesslog = "/var/log/myapp/access.log"
errorlog = "/var/log/myapp/error.log"
loglevel = "info"
preload_app = True
max_requests = 5000
max_requests_jitter = 500
```

**`/etc/supervisor/conf.d/myapp.conf`**：

```ini
[program:myapp]
command=/var/www/myapp/.venv/bin/gunicorn -c gunicorn_config.py wsgi:app
directory=/var/www/myapp
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/supervisor/myapp.log
environment=APP_ENV="prod",PATH="/var/www/myapp/.venv/bin:%(ENV_PATH)s"
```

**Nginx 反代**：

```nginx
server {
    listen 80;
    server_name api.example.com;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }

    location /static/ {
        alias /var/www/myapp/static/;
        expires 30d;
    }
}
```

### 10.3 uWSGI 模式（老项目仍多见）

```ini
# uwsgi.ini
[uwsgi]
module = wsgi:app
master = true
processes = 8
threads = 2
socket = 127.0.0.1:8000
chmod-socket = 660
vacuum = true
die-on-term = true
buffer-size = 32768
harakiri = 60
max-requests = 5000
logto = /var/log/myapp/uwsgi.log
```

**Nginx 配 uwsgi 协议**（注意不是 http）：

```nginx
location / {
    include uwsgi_params;
    uwsgi_pass 127.0.0.1:8000;
}
```

### 10.4 宝塔面板部署

国内中小项目 / 个人项目 / 外包项目极多用宝塔。流程：

1. 宝塔安装 → Python 项目管理器插件
2. 上传项目 / git clone
3. 创建虚拟环境（图形化选 Python 版本）
4. 设置启动命令：`gunicorn -c gunicorn_config.py wsgi:app`（或 uwsgi）
5. 配置反代 → 网站绑域名 → 申请 Let's Encrypt
6. 守护进程：宝塔自带 Supervisor

**注意**：宝塔默认 Python 来自 yum/apt 老版本，**先装 Python 3.10+ 再建项目**，否则装 fastapi 等会失败。

### 10.5 Docker 标准化部署

```dockerfile
FROM python:3.12-slim
WORKDIR /app

# 国内镜像加速
ENV PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
CMD ["gunicorn", "-c", "gunicorn_config.py", "wsgi:app"]
```

```yaml
# docker-compose.yml
services:
  web:
    build: .
    ports: ["8000:8000"]
    environment:
      - APP_ENV=prod
    depends_on: [db, redis]
  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PWD}
      MYSQL_DATABASE: myapp
    volumes:
      - db_data:/var/lib/mysql
  redis:
    image: redis:7-alpine
  worker:
    build: .
    command: celery -A app.celery_app worker -l info
    depends_on: [redis, db]
volumes:
  db_data:
```

---

## 11. async 使用原则

```python
# ✅ I/O bound 用 async
@router.get("/users")
async def list_users(db: AsyncSession = Depends(get_db)):
    return await user_service.list(db)

# ✅ CPU bound 用同步 def（FastAPI 自动走线程池）
@router.post("/heavy-calc")
def calc_pi(n: int):
    return compute_pi(n)

# ❌ async 内调阻塞库（time.sleep / requests.get / pymysql）
@router.get("/bad")
async def bad():
    time.sleep(5)              # 阻塞整个事件循环
    return requests.get(url).json()

# ✅ 正确异步
@router.get("/good")
async def good():
    await asyncio.sleep(5)
    async with httpx.AsyncClient() as c:
        return (await c.get(url)).json()

# 不得已：用线程池兜底
from fastapi.concurrency import run_in_threadpool
result = await run_in_threadpool(blocking_func, arg)
```

**国内常见坑**：
- 用 `requests` / `pymysql` / 同步 Redis 客户端却写在 `async def` 里 → 性能比同步还差
- Django async view 看似支持，但 ORM 同步调用照样阻塞 —— 没必要硬上
- Celery worker 默认进程 / 线程模式，task 内可以放心写同步代码

---

## 12. 测试（pytest 主流）

```python
# tests/conftest.py
import pytest
from app import create_app
from app.extensions import db

@pytest.fixture
def app():
    app = create_app("test")
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()

@pytest.fixture
def client(app):
    return app.test_client()

# tests/test_user.py
def test_create_user(client):
    res = client.post("/api/users", json={"name": "张三", "email": "zhangsan@x.com", "password": "123456"})
    assert res.status_code == 201
    assert res.get_json()["data"]["name"] == "张三"
```

**国内现状**：
- 自动化测试覆盖率普遍较低（业务赶时间常见）
- 接口联调多用 **Postman / Apifox**，单元测试少
- CI 上跑 pytest 是基础，覆盖率 60-80% 已算良好
- 性能压测：**Locust**（Python 写脚本）/ JMeter

---

## 13. 配置与环境

```python
# 国内务实派
import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SECRET_KEY = os.environ["SECRET_KEY"]
    DATABASE_URL = os.environ["DATABASE_URL"]
    REDIS_URL = os.environ.get("REDIS_URL", "redis://127.0.0.1:6379/0")
    DEBUG = False

class DevConfig(Config):
    DEBUG = True

class ProdConfig(Config):
    pass

config_map = {"dev": DevConfig, "prod": ProdConfig}
```

**`.env`**（**永远不提交 git**）：

```bash
APP_ENV=dev
SECRET_KEY=随机串
DATABASE_URL=mysql+pymysql://user:pass@127.0.0.1:3306/myapp?charset=utf8mb4
REDIS_URL=redis://127.0.0.1:6379/0
```

**升级**：`pydantic-settings`（自动校验 + 类型）—— 推荐，但国内目前 `python-dotenv + os.environ` 更普及。

---

## 14. 日志（国内务实模板）

```python
# app/utils/logger.py
import logging
import logging.handlers
import os

def setup_logger(name: str = "app", log_dir: str = "logs") -> logging.Logger:
    os.makedirs(log_dir, exist_ok=True)
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)

    fmt = logging.Formatter(
        "%(asctime)s | %(levelname)-7s | %(name)s | %(filename)s:%(lineno)d | %(message)s"
    )

    file_handler = logging.handlers.TimedRotatingFileHandler(
        f"{log_dir}/app.log", when="midnight", backupCount=30, encoding="utf-8"
    )
    file_handler.setFormatter(fmt)

    console = logging.StreamHandler()
    console.setFormatter(fmt)

    logger.addHandler(file_handler)
    logger.addHandler(console)
    return logger
```

**升级**：`structlog`（结构化 JSON 日志，便于 ELK / Loki 采集）—— 大厂主流，中小公司未普及。

---

## 15. 反模式清单（按国内高频度排序）

| 反模式 | 频度 | 后果 |
|---|---|---|
| **业务逻辑塞 view / controller 里**（没有 service 层，路由函数几百行） | ★★★★★ | 重构地狱，无法测试，复用全靠复制 |
| **裸字符串拼 SQL**（`f"SELECT * FROM user WHERE id={id}"`） | ★★★★★ | **SQL 注入** —— 国内最高频安全事故 |
| **不分 dev / test / prod 配置** | ★★★★ | 上线连测试库 / 调试模式忘关 |
| **全局 db 实例 / 单例满天飞** + 循环 import | ★★★★ | Flask 项目尤其常见，新人改不动 |
| **不写 type hints**（新项目也不写） | ★★★★ | IDE 帮不上忙，重构靠运气 |
| **用 print 调试上线** | ★★★ | 关键问题查不到日志 |
| **`from x import *`** | ★★★ | 命名空间污染，pylint 不查就一直存在 |
| **ORM 模型直接 jsonify 返回**（无 schema / serializer） | ★★★ | 字段泄漏（password_hash / 内部字段一起送给前端） |
| **`async def` 内调阻塞库**（requests / pymysql / time.sleep） | ★★★ | FastAPI 性能崩，比同步还差 |
| **不用迁移工具直接改库**（手动 alter table） | ★★★ | 团队成员库结构对不齐 |
| **`requirements.txt` 不钉版本** | ★★★ | 隔月部署崩 |
| **Celery task 内调当前请求上下文 / Flask current_app**（不正确传参） | ★★ | task 报 RuntimeError |
| **明文存密码** / 弱哈希（md5 / sha1） | ★★ | 拖库即裸奔，应 bcrypt / argon2 |
| **JWT 不设过期 / 不放黑名单** | ★★ | 退出登录无效，token 永久有效 |
| **滥用 `*args, **kwargs`** | ★★ | 类型丢失，调用方不知道传啥 |
| **直接 `raise Exception("xxx")`**（不自定义异常类） | ★★ | 上层无法分类处理 |
| **顶层 controllers/services 平铺到 50+ 文件不拆模块** | ★★ | 跨业务找文件痛苦 |
| **`Optional[X]` 老语法**（Python 3.10+ 用 `X \| None`） | ★ | 风格不一致，无功能问题 |
| **循环 import**（A 导 B，B 导 A） | ★★★ | Flask / Django 项目常见，要靠延迟导入 / 重构 |

---

## 16. 新项目落地清单

写新 Python 项目第一天就该定的：

- [ ] **Python 版本**：≥ 3.10（`X | None` 语法 / match 语句 / 性能提升）
- [ ] **包管理**：pip + requirements.txt（保守稳）/ uv（新项目升级）
- [ ] **虚拟环境**：`.venv/` 在项目根，**不提交**
- [ ] **lint / format**：flake8 + black + isort（保守）/ ruff（升级）
- [ ] **类型检查**：编辑器 Pylance 必开，CI mypy 可选
- [ ] **Web 框架**：Django+DRF（后台 / 政企）/ FastAPI（API / AI）/ Flask（小工具）
- [ ] **ORM**：Django ORM / SQLAlchemy 2.0
- [ ] **迁移**：Django makemigrations / alembic
- [ ] **配置**：`.env` + `python-dotenv`（保守）/ `pydantic-settings`（升级）
- [ ] **日志**：标准 logging + TimedRotatingFileHandler（保守）/ structlog（升级）
- [ ] **异步任务**：Celery + Redis（默认）/ + RabbitMQ（高可靠）
- [ ] **测试**：pytest + pytest-cov，CI 跑覆盖率
- [ ] **部署**：Gunicorn / uWSGI + Nginx + Supervisor（或 Docker）
- [ ] **`.gitignore`**：`.venv/ __pycache__/ *.pyc .env logs/ .pytest_cache/ .mypy_cache/`
- [ ] **`pip.conf`**：换清华 / 阿里源
- [ ] **统一响应格式**（API 项目）：`{code, msg, data}` 一开始就约定
- [ ] **README**：本地启动步骤 + 部署步骤 + 环境变量列表

---

## 17. 国内场景常见业务模板

| 业务类型 | 推荐技术栈 | 备注 |
|---|---|---|
| **企业 OA / CRM / 内容管理** | Django + DRF + MySQL + Celery + Redis | Admin 即赚一半工期 |
| **AI 推理服务（LLM / 视觉模型）** | FastAPI + 异步 + Redis + 模型框架（vllm / transformers） | 异步 + 流式响应是核心 |
| **爬虫管理后台** | Flask + Celery + Redis + Scrapy / Playwright | 调度灵活，Flask 上手快 |
| **量化交易接口** | FastAPI + 异步 + Polars / Pandas + Redis 缓存 | 低延迟 + 类型严格 |
| **政企外包（含信创）** | Django + 国产数据库（达梦 / 人大金仓）+ 麒麟 OS | 适配工作量大于业务工作量 |
| **私域工具 / 微信生态** | Flask / FastAPI + 微信 SDK + Redis | 多对接微信回调，签名验证细节多 |
| **小程序后端** | FastAPI / Django + JWT + 微信登录 | 接口规范 + 鉴权是重点 |

---

## 18. 权威信息源

**官方 / 国际**：
- [PEP 8](https://peps.python.org/pep-0008/) / [PEP 257](https://peps.python.org/pep-0257/) / [PEP 484](https://peps.python.org/pep-0484/)
- [Flask 官方](https://flask.palletsprojects.com/) / [Flask 中文文档](https://dormousehole.readthedocs.io/)
- [Django 官方](https://docs.djangoproject.com/) / [DRF 官方](https://www.django-rest-framework.org/)
- [FastAPI 官方](https://fastapi.tiangolo.com/) / [FastAPI Best Practices (zhanymkanov)](https://github.com/zhanymkanov/fastapi-best-practices)
- [Pydantic v2](https://docs.pydantic.dev/) / [SQLAlchemy 2.0](https://docs.sqlalchemy.org/)
- [Celery 官方](https://docs.celeryq.dev/)
- [Ruff](https://docs.astral.sh/ruff/) / [uv](https://docs.astral.sh/uv/)
- [Cosmic Python](https://www.cosmicpython.com/) — Repository / UnitOfWork 国际权威

**国内社区**：
- 思否 / 掘金 / 知乎 / CSDN：实战文章多，质量参差，看高赞 + 看时间
- learnku.com（Python / Laravel 中文社区）
- v2ex.com `/go/python` 节点：技术选型讨论质量较高
- B 站 Python 教程：入门质量高，进阶看 up 主口碑

**国产规约**（参考性）：
- 阿里巴巴 Java 开发手册（Python 类比借鉴：命名 / 异常 / 日志 / 强制约束的写法风格）
- 各大厂内部 Python 风格指南多基于 PEP 8 + Google Python Style Guide 派生

---

## 19. 结语

国内主流不等于落后，是工程现实约束（团队构成 / 招聘市场 / 跨语言迁移成本 / 运维基础设施）下的合理选择。本规范的**国外推荐章节**是升级路径，不是当前必须；选型时优先匹配团队、项目阶段和业务复杂度，**不要为了"先进"而先进**。

新项目从今天开始：能上 Python 3.10+ 就别用 3.8、能写 type hints 就别躲、能拆 service 就别全塞 view —— 这三件事做到了，已经领先国内一大半项目。
