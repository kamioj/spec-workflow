---
name: Python Engineering Conventions (Practitioner's Perspective)
scope: General Python + Chinese domestic Web backends (Flask / Django+DRF / FastAPI) + domestic toolchains and deployment
note: PEP 8 / 257 / 484 are not reproduced here; this document focuses on what is actually prevalent in Chinese production codebases, with international recommendations noted as upgrade paths
audience: Python backend / full-stack / web scraping / AI services / enterprise/government outsourcing / quantitative finance scenarios in the Chinese domestic market
---
<!-- GENERATED from core/references/python-conventions.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# Python Engineering Conventions (Practitioner's Perspective)

> Perspective: "mainstream" in this document refers to **common practices found in Chinese production codebases circa 2024–2026**, not what PyPA / Real Python / Tiangolo consider international best practice. The differences are simply facts, not value judgments. **New-project upgrade paths** are called out explicitly so teams can migrate incrementally.

## 1. Official References and Baseline Code Style

Rather than reproducing the PEPs, links are provided below:

| Document | Link | Scope |
|---|---|---|
| **PEP 8** | https://peps.python.org/pep-0008/ | Code style baseline (required reading) |
| **PEP 257** | https://peps.python.org/pep-0257/ | Docstring conventions |
| **PEP 484** | https://peps.python.org/pep-0484/ | Type hints |
| **PEP 526** | https://peps.python.org/pep-0526/ | Variable annotation syntax |
| **Alibaba Python Development Manual** | Many internal derivatives exist; no official public release | Strict naming / docstring / exception rules |

**How Chinese teams typically apply PEP 8 in practice**:

- 4-space indentation (no tabs)
- Max line length ≤ 120 characters (teams commonly relax this to 100–120; 79 or 89 is rarely enforced — Chinese comments and long variable names simply don't fit)
- Functions / variables in `snake_case`, classes in `PascalCase`, constants in `UPPER_SNAKE`
- Import order: stdlib → third-party → local, blank line between groups (isort default profile)
- Chinese inline comments are common; key business logic MUST be commented; many teams also write Chinese docstrings (perfectly acceptable for internal-only code)
- Private methods prefixed with `_`, strictly private with `__` (rarely used — too easy to collide with dunder names)

**Docstring style in Chinese codebases**: Legacy projects often use reStructuredText; Google style is most common in new projects; NumPy style is preferred by data science and algorithm teams. **Many companies do not enforce docstrings at all**, reserving them for SDK-style public-facing libraries.

---

## 2. Toolchain: Domestic Reality vs. International Recommendations

### 2.1 Package Management (Domestic Reality)

| Tool | Domestic adoption (estimated) | Typical use case |
|---|---|---|
| **pip + requirements.txt + venv / virtualenv** | ★★★★★ 60–75% (dominant) | Default choice; the starting point for virtually every tutorial, training course, and outsourced project |
| **pip + requirements.txt + conda** | ★★★★ 15–25% | Data science / algorithm / AI / quant teams |
| **Pipenv** | ★ < 5% | Had a moment of hype; essentially nobody starts new projects with it now |
| **Poetry** | ★★ 5–10% | Mid-to-large internet companies and teams that care about dependency locking |
| **uv** | ★ < 5% (growing fast) | New projects in 2026, CI speed-up use cases |
| **pdm / hatch** | ★ < 2% | Rarely seen |

**Typical `requirements.txt` (the standard)**:

```text
# requirements.txt  ← production dependencies
Flask==2.3.3
SQLAlchemy==2.0.25
redis==5.0.1
celery==5.3.4
requests==2.31.0
gunicorn==21.2.0

# requirements-dev.txt  ← dev tooling, optionally split out
pytest==7.4.3
flake8==6.1.0
black==23.12.1
isort==5.13.2
ipython
```

**Domestic default mirror** (configured in `~/.pip/pip.conf` or `pip.ini`):

```ini
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
# Alternatives:
# https://mirrors.aliyun.com/pypi/simple
# https://pypi.mirrors.ustc.edu.cn/simple
# https://mirrors.cloud.tencent.com/pypi/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
```

**Pinned versions**: Virtually 100% of Chinese projects use `==` to hard-pin every version, unlike international projects where `~=` or `>=` are common. The reason: painful production incidents caused by transitive dependency drift have left a lasting impression.

**Virtual environment location**:
- `venv/` or `.venv/` in the project root (most common)
- Legacy projects use `virtualenv` (functionally equivalent to `python -m venv`); new projects go straight to `python -m venv .venv`
- Data science / AI teams typically use `conda env` + `environment.yml`

### 2.2 Upgrade Path: uv (Recommended for New Projects)

uv is a Rust-based tool from Astral, 10–100× faster than pip. It is growing rapidly in 2026 but is far from mainstream domestically. **New projects should adopt uv from the start; legacy projects can stay on pip.**

```bash
# Getting started with uv
uv init my-service
uv add fastapi 'pydantic>=2.9' sqlalchemy
uv add --dev pytest ruff mypy
uv run python -m app
uv sync  # team members sync their environment

# Export requirements.txt for compatibility with legacy CI
uv export --format requirements-txt > requirements.txt
```

`pyproject.toml` (uv / modern template):

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

### 2.3 Lint / Format (Domestic Reality)

| Tool combination | Domestic adoption | Notes |
|---|---|---|
| **flake8 + black + isort (the triple)** | ★★★★★ mainstream | Appears in tutorials, job postings, and internally at Alibaba / ByteDance |
| **pylint** | ★★ legacy projects / strict teams | Noisy and fiddly to configure; few new projects adopt it |
| **autopep8 / yapf** | ★ occasional | yapf is Google style; rarely seen domestically |
| **ruff** | ★★ growing | Adopted in some new projects at large companies; as of 2026, many teams know about it but haven't switched |

**Most common `.flake8` configuration**:

```ini
[flake8]
max-line-length = 120
exclude = .git,__pycache__,venv,.venv,migrations
ignore =
    E203,  # conflicts with black (slice spacing)
    W503,  # binary operator line break (black does the opposite)
    E501,  # line length (delegated to black)
per-file-ignores =
    __init__.py:F401  # allow unused imports (used for re-exports)
```

**black + isort in `pyproject.toml`**:

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
profile = "black"      # compatible with black
line_length = 120
known_first_party = ["app", "myproject"]
```

### 2.4 Upgrade Path: ruff (Replaces flake8 + isort + parts of black)

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

**Migration suggestion**: Keep `black` for formatting (your colleagues already know it) and let `ruff` take over `flake8 + isort`. Transition gradually.

### 2.5 Type Checking (Domestic Reality)

Type hint coverage is significantly lower in Chinese codebases than internationally:
- **New projects annotate function signatures** (roughly 60–70%); **legacy projects almost never backfill**
- **mypy strict mode**: Only used at large companies and in SDK-type projects
- **pyright / Pylance**: Used in editors if available; CI enforcement is rare
- **TypedDict / Protocol / generics**: Rarely used; most teams stop at "function signatures + container types"

**Pragmatic approach**:

```python
# Domestic pragmatic style: annotate boundaries; skip simple internals
def get_user_by_id(user_id: int) -> dict | None:
    # Temporary variables in the implementation body don't need annotations
    rows = db.execute(...).fetchall()
    if not rows:
        return None
    return {"id": rows[0][0], "name": rows[0][1]}

# Boundaries (API / library functions) MUST be annotated
def create_order(
    user_id: int,
    items: list[dict],
    coupon_code: str | None = None,
) -> Order:
    ...
```

---

## 3. Type Hints in Practice

```python
# ✅ Use | instead of Optional in Python 3.10+ (Optional still appears in 3.9-era projects)
def fetch(id: int) -> User | None: ...

# ✅ Use built-in collection types; avoid List / Dict (typing module is deprecated for these in 3.9+)
def names(users: list[User]) -> dict[int, str]: ...

# ✅ TypedDict for fixed-field dictionaries
from typing import TypedDict
class OrderDict(TypedDict):
    order_id: int
    amount: float
    status: str

# ✅ Pydantic for API / config boundaries
from pydantic import BaseModel, EmailStr, Field

class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=32)
    email: EmailStr
    age: int = Field(ge=0, le=150)

# ✅ dataclass for internal DTOs
from dataclasses import dataclass
@dataclass
class PriceCalcResult:
    subtotal: float
    tax: float
    total: float
```

**When to use what**:

| Scenario | Choice |
|---|---|
| HTTP API request / response | **Pydantic** (runtime validation, native FastAPI integration) |
| Flask / Django forms / serialization | **WTForms / DRF Serializer** (framework-native; no need to force Pydantic in) |
| Internal data passing | `dataclass` / `TypedDict` |
| Configuration (.env) | `pydantic-settings` / Django's built-in settings / `os.environ` |
| Domain objects | `dataclass` with methods; full classes for heavy logic |

---

## 4. Decision Matrix: The Three Major Web Frameworks (with Domestic Context)

| Dimension | Django | FastAPI | Flask |
|---|---|---|---|
| Positioning | Full-stack batteries-included | Modern async API | Minimal microframework |
| ORM | Built-in Django ORM | SQLAlchemy / SQLModel | Your choice (Flask-SQLAlchemy is standard) |
| Admin | ✅ Built-in (the go-to for domestic back-office) | ❌ | ❌ |
| Forms / validation | Django Forms / DRF Serializer | Native Pydantic | WTForms / hand-rolled |
| Auto API docs | drf-spectacular / drf-yasg | ✅ Native OpenAPI | apispec / flasgger (manual) |
| Async | Partial support; rarely used domestically | ✅ Native | Limited |
| Learning curve | Medium (opinionated conventions) | Low (declarative) | Low (high freedom) |
| Domestic use cases | **Government/enterprise OA / CRM / back-office / content platforms / private domain tools** | **AI services / microservices / greenfield APIs / quant interfaces** | **Scraper dashboards / small utilities / legacy systems / individual freelance projects** |
| Domestic adoption (estimated) | ★★★★ 35% | ★★★ 25% (fast-rising) | ★★★★ 35% (large installed base; declining for new projects) |
| Hiring demand | Django + DRF is still the most stable Python web job requirement | Fastest-growing | Common in vague "Python full-stack" roles |

**Default recommendations (domestic pragmatic edition)**:

- Government/enterprise outsourcing / internal back-office / content management → **Django + DRF** (the Admin alone saves half a person-month)
- AI inference / model serving / microservices → **FastAPI** (async + auto-docs + Pydantic, all in one)
- Scraper dashboards / small utilities / personal projects / maintaining legacy systems → **Flask**
- Quant strategy / data APIs → **FastAPI** (performance + type safety)
- Uncertain team composition or many Java developers → **Django** (explicit conventions reduce arguments)

---

## 5. Flask Project Structure (Domestic Mainstream vs. Flask's Official Recommendation)

### 5.1 Dominant Domestic Pattern: Layer-Based Flat Layout (Ported from Java SSM)

Over 80% of Chinese Flask projects follow this structure. It is influenced by Java Spring SSM (Controller-Service-DAO) and is easy to onboard for cross-language teams.

```
my_flask_app/
├── app/
│   ├── __init__.py             ← create_app() factory + extension initialization
│   ├── config.py               ← Config classes (Dev / Prod / Test)
│   ├── extensions.py           ← db / redis / migrate / cache singletons all live here
│   ├── controllers/            ← Routes + HTTP I/O (thin)
│   │   ├── __init__.py
│   │   ├── user_controller.py
│   │   ├── order_controller.py
│   │   └── auth_controller.py
│   ├── services/               ← Business logic (thick)
│   │   ├── __init__.py
│   │   ├── user_service.py
│   │   ├── order_service.py
│   │   └── auth_service.py
│   ├── models/                 ← SQLAlchemy ORM
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── order.py
│   │   └── base.py
│   ├── schemas/                ← Marshmallow / Pydantic serialization (optional)
│   │   ├── user_schema.py
│   │   └── order_schema.py
│   ├── utils/                  ← Utility functions (the junk drawer — keep it from becoming a garbage bin)
│   │   ├── jwt_helper.py
│   │   ├── redis_helper.py
│   │   └── decorators.py
│   ├── tasks/                  ← Celery tasks
│   │   ├── __init__.py
│   │   └── email_tasks.py
│   └── exceptions.py           ← Custom exceptions
├── migrations/                 ← Flask-Migrate / alembic
├── tests/
├── logs/
├── requirements.txt
├── requirements-dev.txt
├── .flaskenv
├── config.py                   ← Top-level config or .env
├── manage.py / run.py / wsgi.py
└── README.md
```

**Typical `app/__init__.py`**:

```python
# app/__init__.py
from flask import Flask
from app.extensions import db, migrate, redis_client, jwt
from app.config import config_map


def create_app(env: str = "dev") -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_map[env])

    # Initialize extensions
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    redis_client.init_app(app)

    # Register blueprints (one blueprint per controller file, no nesting)
    from app.controllers.user_controller import user_bp
    from app.controllers.order_controller import order_bp
    from app.controllers.auth_controller import auth_bp

    app.register_blueprint(user_bp, url_prefix="/api/users")
    app.register_blueprint(order_bp, url_prefix="/api/orders")
    app.register_blueprint(auth_bp, url_prefix="/api/auth")

    # Global error handlers
    from app.exceptions import register_error_handlers
    register_error_handlers(app)

    return app
```

**Typical controller**:

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
        return jsonify({"code": 404, "msg": "user not found"}), 404
    return jsonify({"code": 0, "data": user})
```

**Typical service**:

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

**Characteristics of this pattern**:
- `controller / service / model` are all flat at the top level, **organized by file type**
- Blueprints are **one per controller file**, with no nested packages
- `Service` classes are typically implemented with `@staticmethod` (Java static utility class mentality); some teams use module-level functions instead
- `to_dict()` is attached directly to the Model (many teams don't bother introducing Marshmallow)
- `extensions.py` centralizes singletons like `db = SQLAlchemy()` to prevent circular imports

### 5.2 Flask's Official Recommendation: Feature-Based Blueprint Layout (International Standard)

The Flask official tutorial, Miguel Grinberg, and zhanymkanov's FastAPI Best Practices all favor **organizing by business feature**:

```
my_flask_app/
├── app/
│   ├── __init__.py
│   ├── auth/                   ← By feature: each module owns its routes/services/models
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

**Comparison**:

| Dimension | Layer-based flat (domestic standard) | Feature-based blueprints (international recommendation) |
|---|---|---|
| Mental model | "I need to change a route → go to controllers/" | "I need to change the user module → go to users/" |
| Cross-language portability | Friendly to Java / Go / PHP developers | Friendly to Python / Ruby / DDD practitioners |
| Module boundaries | Weak (files in the same layer can import each other freely) | Strong (modules are self-contained) |
| Extracting microservices | Hard (requires horizontal slicing by business domain) | Easy (one module is already a candidate service) |
| Team size fit | Works well for ≤ 10 people | Scales better for 10+ / multiple product lines |
| File lookup | Fast when you know the file type | Fast when you know the business domain |

**Takeaway**: The flat layer-based layout is fine for most domestic projects, **but once the project exceeds 30 controller files**, strongly consider switching to feature-based modules — otherwise the `services/` directory becomes a 50-file nightmare.

---

## 6. Django + DRF Project Structure (Domestic Mainstream)

90% of Chinese Django projects use **DRF (Django REST Framework)** for the API layer.

```
my_django_project/
├── manage.py
├── requirements.txt
├── config/                     ← Project configuration directory (not named mysite anymore; this is the convention)
│   ├── __init__.py
│   ├── settings/               ← Splitting by environment is strongly recommended domestically
│   │   ├── __init__.py
│   │   ├── base.py             ← Shared settings
│   │   ├── dev.py              ← from .base import *
│   │   ├── test.py
│   │   └── prod.py
│   ├── urls.py                 ← Root URL conf (includes each app)
│   ├── wsgi.py
│   └── asgi.py
├── apps/                       ← Domestic must-have: all apps live under apps/ for unified management
│   ├── __init__.py
│   ├── users/
│   │   ├── __init__.py
│   │   ├── apps.py
│   │   ├── models.py           ← ORM models
│   │   ├── serializers.py      ← DRF serializers
│   │   ├── views.py            ← DRF ViewSet / APIView
│   │   ├── urls.py             ← Sub-routes
│   │   ├── admin.py            ← Django Admin configuration
│   │   ├── permissions.py      ← Custom permissions (optional)
│   │   ├── filters.py          ← django-filter (optional)
│   │   ├── services.py         ← Business logic layer (common domestically; not part of standard Django)
│   │   ├── tasks.py            ← Celery tasks (optional)
│   │   └── migrations/
│   ├── orders/
│   │   └── ...
│   └── common/                 ← Shared app: base models / utilities
├── utils/                      ← Project-level utilities (not belonging to any single app)
├── templates/
├── static/
├── media/
├── logs/
└── README.md
```

**Key conventions**:

- In `INSTALLED_APPS`, write `apps.users` rather than `users` (because the app lives under `apps/`)
- Each app MUST set `name = "apps.users"` in `apps.py`
- Splitting `settings/` by environment is **essentially the domestic standard**; a single `settings.py` at the root is only seen in tutorial projects
- **`services.py` emerged organically in Chinese Django projects** (Django has no official service layer concept) to extract business logic out of views and serializers

### 6.1 Typical DRF View

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
        return Response({"msg": "reset successful"})
```

### 6.2 Typical DRF Serializer

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
            raise serializers.ValidationError("email already registered")
        return value

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)
```

### 6.3 Common Patterns in Domestic DRF Projects

- **Unified response envelope**: Custom `Response` subclass or renderer to deliver `{code, msg, data}` to every frontend consumer
- **JWT authentication**: `djangorestframework-simplejwt` (has become the de facto standard)
- **Pagination**: Customize DRF's built-in pagination classes; standardize on `?page=&size=`
- **API documentation**: `drf-spectacular` (OpenAPI 3, recommended) / `drf-yasg` (legacy, Swagger 2)
- **Filtering and search**: `django-filter` + DRF `filter_backends`
- **Internationalization**: Rarely used in government/enterprise projects; Django i18n for externally-facing products

---

## 7. FastAPI Project Structure

### 7.1 Domestic Mainstream: Layer-Based (Opposite of zhanymkanov's Recommendation)

Chinese FastAPI projects heavily carry over the "layer-based flat" mindset from Flask / Django. zhanymkanov's [FastAPI Best Practices](https://github.com/zhanymkanov/fastapi-best-practices) recommends organizing by domain feature, but **layer-based layouts still dominate domestically**:

```
my_fastapi_app/
├── app/
│   ├── __init__.py
│   ├── main.py                 ← FastAPI instance + include_router
│   ├── core/
│   │   ├── config.py           ← pydantic-settings
│   │   ├── security.py         ← JWT / password hashing
│   │   ├── database.py         ← SQLAlchemy engine / session
│   │   └── deps.py             ← Common dependencies (get_db / get_current_user)
│   ├── routers/                ← API routes (thin)
│   │   ├── __init__.py
│   │   ├── users.py
│   │   ├── orders.py
│   │   └── auth.py
│   ├── services/               ← Business logic
│   │   ├── user_service.py
│   │   └── order_service.py
│   ├── models/                 ← SQLAlchemy ORM
│   │   ├── user.py
│   │   └── order.py
│   ├── schemas/                ← Pydantic (request / response)
│   │   ├── user.py
│   │   └── order.py
│   ├── crud/                   ← Optional: DB access layer (Repository style)
│   ├── tasks/                  ← Celery
│   └── utils/
├── tests/
├── alembic/                    ← Migrations
├── alembic.ini
├── requirements.txt
└── README.md
```

### 7.2 International Recommendation: Domain-Based Feature Layout (zhanymkanov)

```
src/
├── auth/                       ← Each domain is self-contained
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

**Differences and recommendations**:

| Dimension | Domestic layer-based | International feature-based |
|---|---|---|
| Onboarding difficulty | Low (Flask / Django devs understand it instantly) | Medium (requires understanding domain boundaries first) |
| Small projects (< 5 modules) | ✅ Cleaner | Too many module shells |
| Large projects (> 10 modules) | services/ will explode | ✅ Scales naturally |
| Splitting into microservices | Hard | ✅ One directory per service |

**Practical guidance**:
- Project expects < 10 business modules / team < 5 people → layer-based flat is fine
- Long-lived project / multiple product lines / team > 5 people → go domain-based from the start

### 7.3 Typical Router / Service

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
        raise HTTPException(status_code=400, detail="email already exists")
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

## 8. ORM Selection (Domestic Reality)

| ORM | Use case | Domestic adoption |
|---|---|---|
| **Django ORM** | Built into Django; simple and approachable | 100% of Django projects |
| **SQLAlchemy 2.0** | Mainstream for FastAPI / Flask; supports async | Standard for mid-to-large projects |
| **Flask-SQLAlchemy** | Thin wrapper around SQLAlchemy for Flask projects | 80%+ of Flask projects |
| **Peewee** | Lightweight, easy to learn; legacy projects / small utilities | Personal projects / legacy outsourced code |
| **Tortoise ORM** | Fully async; mimics Django ORM's style | Niche FastAPI choice |
| **SQLModel** | Pydantic + SQLAlchemy in one | FastAPI experimentation; not yet widespread |

**SQLAlchemy async template**:

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

**Domestic database preferences**:
- MySQL is the overwhelming choice (80%+); charset MUST be `utf8mb4` (emoji compatibility)
- PostgreSQL is gaining ground in AI, data, and greenfield internet projects
- SQLite for local development / testing only
- Domestic databases (DM / KingBase / OceanBase): required in government/enterprise projects; adapted via SQLAlchemy dialects
- Migration tooling: Django uses its built-in `makemigrations`; everything else uses **alembic**

---

## 9. Async Task Queues: Celery Is the Domestic Standard

```
[Producer]  --send-->  [Broker: Redis / RabbitMQ]  --pull-->  [Worker]
                                                                  |
                                                          [Backend: Redis]
```

| Role | Common choices domestically |
|---|---|
| Broker (message queue) | **Redis** (mainstream for small-to-medium projects) / RabbitMQ (large-scale / strict reliability) |
| Backend (result storage) | Redis |
| Monitoring | Flower (web UI) / custom monitoring |
| Scheduled tasks | celery beat / APScheduler |

**Typical configuration**:

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
    worker_max_tasks_per_child=1000,  # prevent memory leaks
    broker_connection_retry_on_startup=True,
)
```

```python
# app/tasks/email_tasks.py
from app.celery_app import celery_app

@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def send_email_task(self, to: str, subject: str, body: str):
    try:
        # call email SDK
        ...
    except Exception as exc:
        raise self.retry(exc=exc)
```

**Start commands (production)**:

```bash
celery -A app.celery_app worker -l info -c 8 --max-tasks-per-child=1000
celery -A app.celery_app beat -l info       # scheduled tasks
celery -A app.celery_app flower             # monitoring UI
```

**Common pitfalls domestically**:
- Using Redis as broker means tasks can be lost (no ACK mechanism) — switch to RabbitMQ for strict reliability requirements
- `celery beat` MUST run as a single instance (multiple instances cause duplicate firing) — use `celery-beat-cluster` or `redbeat` to solve this
- Timezone MUST be `Asia/Shanghai` with `enable_utc=False` (otherwise beat scheduled tasks fire 8 hours off)

---

## 10. Deployment: Domestic Reality

### 10.1 Domestic Deployment Distribution

| Approach | Domestic adoption | Use case |
|---|---|---|
| **uWSGI + Nginx + Supervisor** | ★★★★ legacy projects / government-enterprise / outsourcing default | Slightly better performance; more configuration overhead |
| **Gunicorn + Nginx + Supervisor / systemd** | ★★★★ mainstream for new projects | Simple configuration; pure Python |
| **BaoTa Panel (uWSGI / Gunicorn auto-configured)** | ★★★ individuals / SMBs | GUI-friendly; low operational barrier |
| **Docker + Docker Compose** | ★★★ mainstream at internet companies | Standardized; easy to migrate |
| **K8s** | ★★ large companies / platform teams | Complex; high operational overhead |
| **Serverless (Alibaba FC / Tencent SCF)** | ★ niche; AI / bursty traffic | Cold start latency; domestic ecosystem is reasonably mature |
| **uvicorn (FastAPI single process) + Nginx** | ★★ FastAPI projects | Fine for dev; production MUST use `gunicorn -k uvicorn.workers.UvicornWorker` |

### 10.2 Typical Gunicorn + Nginx + Supervisor Setup

**`gunicorn_config.py`**:

```python
import multiprocessing

bind = "127.0.0.1:8000"
workers = multiprocessing.cpu_count() * 2 + 1   # classic formula
worker_class = "sync"                            # FastAPI: use "uvicorn.workers.UvicornWorker"
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

**`/etc/supervisor/conf.d/myapp.conf`**:

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

**Nginx reverse proxy**:

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

### 10.3 uWSGI Mode (Still Common in Legacy Projects)

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

**Nginx with uwsgi protocol** (not HTTP):

```nginx
location / {
    include uwsgi_params;
    uwsgi_pass 127.0.0.1:8000;
}
```

### 10.4 BaoTa Panel Deployment

Extremely common for small domestic projects, personal projects, and outsourced work. The workflow:

1. Install BaoTa → Python Project Manager plugin
2. Upload project / git clone
3. Create virtual environment (select Python version via GUI)
4. Set startup command: `gunicorn -c gunicorn_config.py wsgi:app` (or uwsgi)
5. Configure reverse proxy → bind domain → request Let's Encrypt certificate
6. Process management: BaoTa ships with Supervisor built in

**Note**: BaoTa installs an older Python from yum/apt by default. **Install Python 3.10+ before creating the project** or packages like fastapi will fail to install.

### 10.5 Docker Standardized Deployment

```dockerfile
FROM python:3.12-slim
WORKDIR /app

# Domestic mirror acceleration
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

## 11. Async Usage Principles

```python
# ✅ Use async for I/O-bound work
@router.get("/users")
async def list_users(db: AsyncSession = Depends(get_db)):
    return await user_service.list(db)

# ✅ Use synchronous def for CPU-bound work (FastAPI automatically runs it in a thread pool)
@router.post("/heavy-calc")
def calc_pi(n: int):
    return compute_pi(n)

# ❌ Calling blocking libraries inside async (time.sleep / requests.get / pymysql)
@router.get("/bad")
async def bad():
    time.sleep(5)              # blocks the entire event loop
    return requests.get(url).json()

# ✅ Correct async approach
@router.get("/good")
async def good():
    await asyncio.sleep(5)
    async with httpx.AsyncClient() as c:
        return (await c.get(url)).json()

# Last resort: wrap in a thread pool
from fastapi.concurrency import run_in_threadpool
result = await run_in_threadpool(blocking_func, arg)
```

**Common pitfalls domestically**:
- Using `requests` / `pymysql` / synchronous Redis clients inside `async def` — performance becomes worse than plain synchronous code
- Django async views look supported, but synchronous ORM calls still block — not worth forcing async on Django
- Celery workers default to process / thread mode; it is perfectly safe to write synchronous code inside tasks

---

## 12. Testing (pytest Is the Standard)

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
    res = client.post("/api/users", json={"name": "Alice", "email": "alice@x.com", "password": "123456"})
    assert res.status_code == 201
    assert res.get_json()["data"]["name"] == "Alice"
```

**Domestic reality**:
- Automated test coverage is generally low (business timelines are the usual excuse)
- API contract testing is most commonly done with **Postman / Apifox**; unit tests are sparse
- Running pytest in CI is the baseline; 60–80% coverage is considered respectable
- Performance testing: **Locust** (Python scripts) / JMeter

---

## 13. Configuration and Environments

```python
# Domestic pragmatic approach
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

**`.env`** (NEVER commit to git):

```bash
APP_ENV=dev
SECRET_KEY=<random-string>
DATABASE_URL=mysql+pymysql://user:pass@127.0.0.1:3306/myapp?charset=utf8mb4
REDIS_URL=redis://127.0.0.1:6379/0
```

**Upgrade**: `pydantic-settings` (automatic validation + type coercion) — recommended, but `python-dotenv + os.environ` is currently more prevalent domestically.

---

## 14. Logging (Domestic Pragmatic Template)

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

**Upgrade**: `structlog` (structured JSON logging, ideal for ELK / Loki ingestion) — standard at large companies; not yet widespread at smaller ones.

---

## 15. Anti-Pattern Catalogue (Ranked by Domestic Frequency)

| Anti-pattern | Frequency | Consequences |
|---|---|---|
| **Business logic stuffed into views / controllers** (no service layer; route functions hundreds of lines long) | ★★★★★ | Refactoring hell; untestable; reuse by copy-paste |
| **Raw string SQL concatenation** (`f"SELECT * FROM user WHERE id={id}"`) | ★★★★★ | **SQL injection** — the most common security incident domestically |
| **No dev / test / prod config split** | ★★★★ | Going live pointed at the test database; debug mode left on |
| **Global db singletons everywhere** + circular imports | ★★★★ | Especially common in Flask projects; new team members can't make changes |
| **No type hints** (not even in new projects) | ★★★★ | IDE can't help; refactoring is guesswork |
| **`print` statements left in production** | ★★★ | Can't find critical issues in logs |
| **`from x import *`** | ★★★ | Namespace pollution; persists silently until pylint catches it |
| **Returning ORM model instances directly via jsonify** (no schema / serializer) | ★★★ | Field leakage (`password_hash` and internal fields sent to the frontend) |
| **Blocking libraries called inside `async def`** (`requests` / `pymysql` / `time.sleep`) | ★★★ | FastAPI performance collapses; worse than synchronous code |
| **Modifying the database directly without a migration tool** (manual `ALTER TABLE`) | ★★★ | Team members end up with out-of-sync database schemas |
| **Unpinned versions in `requirements.txt`** | ★★★ | Deployments break a month later |
| **Celery tasks accessing the current request context / `Flask current_app`** (missing proper argument passing) | ★★ | Tasks throw `RuntimeError` |
| **Storing passwords in plaintext** / weak hashing (md5 / sha1) | ★★ | A stolen database dump fully exposes all users; use bcrypt / argon2 |
| **JWT tokens with no expiry / no blacklist** | ★★ | Logout is meaningless; tokens are valid forever |
| **Overusing `*args, **kwargs`** | ★★ | Type information lost; callers have no idea what to pass |
| **Raising bare `Exception("...")` directly** (no custom exception classes) | ★★ | Callers cannot catch and handle specific error categories |
| **Flat top-level controllers/services with 50+ files and no module split** | ★★ | Cross-domain file lookups become painful |
| **`Optional[X]` old syntax** (use `X \| None` in Python 3.10+) | ★ | Style inconsistency; no functional impact |
| **Circular imports** (A imports B, B imports A) | ★★★ | Common in Flask / Django projects; requires lazy imports or refactoring to resolve |

---

## 16. New Project Launch Checklist

Decisions that should be made on day one of any new Python project:

- [ ] **Python version**: ≥ 3.10 (`X | None` syntax / match statements / performance improvements)
- [ ] **Package management**: pip + requirements.txt (conservative, stable) / uv (new project upgrade)
- [ ] **Virtual environment**: `.venv/` in the project root, **not committed**
- [ ] **Lint / format**: flake8 + black + isort (conservative) / ruff (upgrade path)
- [ ] **Type checking**: Pylance in the editor (required); CI mypy (optional)
- [ ] **Web framework**: Django+DRF (back-office / enterprise) / FastAPI (API / AI) / Flask (small utilities)
- [ ] **ORM**: Django ORM / SQLAlchemy 2.0
- [ ] **Migrations**: Django makemigrations / alembic
- [ ] **Configuration**: `.env` + `python-dotenv` (conservative) / `pydantic-settings` (upgrade)
- [ ] **Logging**: standard logging + TimedRotatingFileHandler (conservative) / structlog (upgrade)
- [ ] **Async tasks**: Celery + Redis (default) / + RabbitMQ (high reliability)
- [ ] **Testing**: pytest + pytest-cov; CI runs coverage
- [ ] **Deployment**: Gunicorn / uWSGI + Nginx + Supervisor (or Docker)
- [ ] **`.gitignore`**: `.venv/ __pycache__/ *.pyc .env logs/ .pytest_cache/ .mypy_cache/`
- [ ] **`pip.conf`**: switch to Tsinghua / Aliyun mirror
- [ ] **Unified response envelope** (API projects): agree on `{code, msg, data}` from the very beginning
- [ ] **README**: local startup steps + deployment steps + environment variable list

---

## 17. Common Business Templates for Domestic Scenarios

| Business type | Recommended stack | Notes |
|---|---|---|
| **Enterprise OA / CRM / content management** | Django + DRF + MySQL + Celery + Redis | Admin alone saves half the schedule |
| **AI inference services (LLM / vision models)** | FastAPI + async + Redis + model framework (vllm / transformers) | Async + streaming response are the core requirements |
| **Scraper management dashboards** | Flask + Celery + Redis + Scrapy / Playwright | Flexible scheduling; Flask is quick to get up and running |
| **Quantitative trading interfaces** | FastAPI + async + Polars / Pandas + Redis cache | Low latency + strict typing |
| **Government/enterprise outsourcing (including domestic-tech mandates)** | Django + domestic databases (DM / KingBase) + Kylin OS | Adaptation work often outweighs actual business work |
| **Private-domain tools / WeChat ecosystem** | Flask / FastAPI + WeChat SDK + Redis | Heavy WeChat callback integration; signature verification has many edge cases |
| **Mini-program backends** | FastAPI / Django + JWT + WeChat Login | API standards + authentication are the main focus |

---

## 18. Authoritative References

**Official / International**:
- [PEP 8](https://peps.python.org/pep-0008/) / [PEP 257](https://peps.python.org/pep-0257/) / [PEP 484](https://peps.python.org/pep-0484/)
- [Flask official docs](https://flask.palletsprojects.com/) / [Flask Chinese docs](https://dormousehole.readthedocs.io/)
- [Django official docs](https://docs.djangoproject.com/) / [DRF official docs](https://www.django-rest-framework.org/)
- [FastAPI official docs](https://fastapi.tiangolo.com/) / [FastAPI Best Practices (zhanymkanov)](https://github.com/zhanymkanov/fastapi-best-practices)
- [Pydantic v2](https://docs.pydantic.dev/) / [SQLAlchemy 2.0](https://docs.sqlalchemy.org/)
- [Celery official docs](https://docs.celeryq.dev/)
- [Ruff](https://docs.astral.sh/ruff/) / [uv](https://docs.astral.sh/uv/)
- [Cosmic Python](https://www.cosmicpython.com/) — the authoritative international reference for Repository / UnitOfWork patterns

**Domestic communities**:
- SegmentFault / Juejin / Zhihu / CSDN: abundant practical articles; quality varies widely — look for high-vote, recent content
- learnku.com (Python / Laravel Chinese community)
- v2ex.com `/go/python` board: higher-quality tech discussion
- Bilibili Python tutorials: high quality for beginners; check the uploader's reputation for advanced content

**Domestic style guides (reference only)**:
- Alibaba Java Development Manual (useful by analogy for naming / exceptions / logging / mandatory style rules)
- Most large-company internal Python style guides are derived from PEP 8 + Google Python Style Guide

---

## 19. Closing Thoughts

Domestic mainstream practices are not inferior — they are reasonable choices shaped by real engineering constraints: team composition, the hiring market, cross-language migration costs, and operational infrastructure. The **international recommendation sections** in this document are upgrade paths, not current requirements. When making technology decisions, match the choice to your team, project stage, and business complexity. **Do not chase "cutting-edge" for its own sake.**

Starting a new project today: use Python 3.10+ if you possibly can, write type hints instead of avoiding them, and extract a service layer instead of stuffing everything into views. Do these three things and you are already ahead of the vast majority of Python projects in the domestic ecosystem.
