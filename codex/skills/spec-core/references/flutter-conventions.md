---
name: Flutter / Dart Engineering Conventions (China-Focused)
scope: Dart 3 modern language features + real-world Chinese Flutter ecosystem (state management / UI / routing / hybrid stacks / push notifications / mirrors) + anti-patterns
note: Unlike the Western norm of pushing Riverpod/Bloc, this document weights recommendations by actual adoption in Chinese projects — GetX/Provider are honestly listed as the dominant reality, while Riverpod/Bloc appear as advanced/recommended options
audience: Intended for Chinese indie developers, small-to-medium teams, and large enterprise hybrid-stack integrations — not Silicon Valley SaaS teams
---
<!-- GENERATED from core/references/flutter-conventions.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# Flutter / Dart Engineering Conventions (China-Focused)

## 0. Why This Document Is Different

Western Flutter tutorials (resocoder, Code With Andrea, the official architecture guide) default to recommending Riverpod / Bloc + Clean Architecture + feature-based directory layout. **This approach has a real-world adoption rate below 20% in Chinese small-to-medium teams.** The actual landscape in China is:

- **GetX dominates Chinese tutorials and is the default starting point for beginners** (it's an anti-pattern minefield, but you can't ignore it)
- **Provider is heavily promoted on Juejin, Bilibili, and the Flutter Chinese community**, with a massive installed base of existing projects
- **Layer-based flat directory structures** (`pages / widgets / services / models / utils`) are far more common than `features/data/domain/presentation`
- **flutter_screenutil + dio + getx** is the default starter kit in roughly 80% of Chinese tutorials
- **Large enterprise projects are almost always hybrid stacks** (FlutterBoost / in-house hybrid), not pure Flutter apps
- **Package dependencies MUST be configured with a mirror** (`pub.flutter-io.cn`); otherwise `flutter pub get` hangs indefinitely

This document therefore treats "Chinese real-world choices" as the primary content, with **Riverpod 3 / Bloc / Clean Architecture listed as "Western recommendations / advanced options"** — neither dismissed nor aggressively promoted. Each section includes a "domestic frequency" rating and "anti-pattern signals."

---

## 1. Authoritative References and Chinese Resources

| Resource | Link | Purpose |
|---|---|---|
| Effective Dart | https://dart.dev/effective-dart | Naming / documentation / style |
| Flutter Official Architecture Guide | https://docs.flutter.dev/app-architecture/guide | Western mainstream |
| Flutter Chinese Docs | https://docs.flutter.cn | Mirror + translation |
| Flutter Chinese Community | https://flutter-io.cn | Best entry point for Chinese developers |
| Juejin Flutter Tag | https://juejin.cn/tag/Flutter | Highest density of Chinese articles |
| Guo Shuyu / GSYTech | https://guoshuyu.cn | Most comprehensive Chinese Flutter blog |
| Xianyu Tech | https://developer.aliyun.com/group/idlefish | Large-scale Flutter production experience from Alibaba |

**Effective Dart quick reference**:

- Files/libraries: `lowercase_with_underscores` (e.g., `user_profile.dart`); classes: `PascalCase`; variables/methods: `camelCase`
- **Constants: `camelCase`** (Dart-specific — NOT `UPPER_SNAKE`)
- Prefer type inference with `var`; annotate types explicitly on public APIs
- Prefer `final` over `var`
- Use string interpolation `'$name'` for string composition — NEVER use `+`

---

## 2. Mirror Configuration for China (Do This First)

Without a mirror, packages simply won't install. **Official Flutter Chinese Community mirrors**:

```pwsh
# Windows user-level environment variables (pwsh)
[Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', 'https://pub.flutter-io.cn', 'User')
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'User')
```

```bash
# macOS / Linux ~/.zshrc or ~/.bashrc
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

**Backup mirrors**:
- Tsinghua TUNA: `https://mirrors.tuna.tsinghua.edu.cn/flutter/`
- Tencent Cloud: `https://mirrors.cloud.tencent.com/flutter/`

**Private pub repositories** (for internal teams): both JFrog Artifactory and Nexus support pub repos. Enterprise projects should avoid relying on public pub to pull dependencies.

**CI note**: GitHub Actions / GitLab CI runners located in China also need these two variables injected via `env:` in the workflow file.

---

## 3. Default Technology Stack (2026 China Real-World Adoption)

| Dimension | Chinese Mainstream (Share) | Western Recommendation | Advanced / Team Standard |
|---|---|---|---|
| Flutter version | **3.41.x stable** (2026.05) | Same | — |
| Dart version | **3.5+** (records / patterns / sealed) | Same | — |
| State management | **GetX** (≈40% of tutorials) / **Provider** (≈30%) | Riverpod 3 | Riverpod 3 / Bloc |
| Routing | **GetX built-in** (tightly coupled to GetX state) / **fluro** (medium/large apps) / Navigator 2.0 custom | go_router | go_router / auto_route |
| HTTP | **dio** (consistent choice, used everywhere) | dio | — |
| UI components | **flutter_screenutil** (essential for adaptation) + Material/Cupertino | Same | TDesign Flutter (Tencent) |
| Toast | **fluttertoast** / **bot_toast** | — | — |
| DI | GetX built-in `Get.put` / `Get.find` (mixed usage) | get_it + injectable | get_it + injectable |
| JSON | Hand-written fromJson/toJson (common) / json_serializable | freezed + json_serializable | freezed + json_serializable |
| Push notifications | **JPush** (≈50%) / **GeTui** / **Umeng** / **Huawei HMS Push** | FCM (blocked in China) | JPush + OEM channels |
| Hybrid stack | **FlutterBoost** (Alibaba) / in-house | N/A | FlutterBoost |
| Testing | flutter_test + mocktail | Same | — |

**Minimum viable stack for China (recommended for indie developers / small projects)**:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0                 # networking
  get: ^4.6.6                 # state + routing + DI in one (controversial but easy to learn)
  flutter_screenutil: ^5.9.0  # screen adaptation
  fluttertoast: ^8.2.4        # toast
  shared_preferences: ^2.2.2  # local key-value storage
  cached_network_image: ^3.3.0  # network image caching
```

Or the **Provider variant**:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  provider: ^6.1.1
  flutter_screenutil: ^5.9.0
  fluttertoast: ^8.2.4
  shared_preferences: ^2.2.2
  go_router: ^14.0.0          # more modern than fluro
```

---

## 4. State Management: Real-World Decision Guide for China

### 4.1 GetX (Top share in China, most controversial)

**Status in China**: Chinese tutorial volume on Bilibili / Juejin / CSDN ranks as GetX > Provider > Riverpod > Bloc. Roughly 90% of beginners start with GetX.

**Genuine advantages**:
- Extremely fast to get started — three lines of code cover state + routing + DI
- No need to thread `BuildContext` everywhere; `Get.to(Page())` / `Get.back()` are dead simple
- Dense Chinese documentation; questions are searchable on both Stack Overflow and Juejin
- Good performance; reactive updates are granular

**Drawbacks (you MUST know these)**:
- **State + router + DI are tightly coupled**, making unit testing a nightmare
- The main repository has a long-running single-maintainer risk; updates are slow
- Conflicts with Flutter's official navigation philosophy (not built on Navigator 2.0, so deep links / Web / Restoration all suffer)
- Overusing `Get.find` as a global service locator makes mocking in tests impossible

**Minimum discipline when using GetX**:

```dart
// ✅ Controller holds only state and methods — no UI logic
class CounterController extends GetxController {
  final count = 0.obs;
  void increment() => count.value++;
}

// ✅ Use GetView for strongly typed binding
class CounterPage extends GetView<CounterController> {
  const CounterPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Obx(() => Text('${controller.count}')),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: controller.increment,
      child: const Icon(Icons.add),
    ),
  );
}

// ✅ Centralize dependency registration in a Binding (overridable in tests)
class CounterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CounterController());
  }
}
```

**GetX anti-patterns (most common in Chinese codebases — avoid these)**:

```dart
// ❌ Anti-pattern 1: Calling Get.dialog / Get.snackbar inside a Controller — untestable
class BadController extends GetxController {
  Future<void> save() async {
    Get.dialog(LoadingDialog());  // UI side-effects leaking into business logic
    await api.save();
    Get.back();
    Get.snackbar('Success', 'Saved successfully');
  }
}

// ❌ Anti-pattern 2: Using Get.find as a universal service locator
final user = Get.find<UserController>().user;  // implicit dependency, cannot be mocked
final api = Get.find<ApiService>();             // requires global stubs in tests

// ❌ Anti-pattern 3: Embedding navigation decisions inside business logic
void onTap() {
  if (Get.find<AuthController>().isLogin) {
    Get.toNamed('/profile');
  } else {
    Get.toNamed('/login');
  }
}
// This kind of guard logic belongs in the router's middleware/redirect layer
```

### 4.2 Provider (Second in China, large installed base)

**Status in China**: Recommended by the Flutter Chinese community and *Flutter in Action (2nd ed.)* by Du Wen. Still common in existing projects, though new projects are gradually shifting to GetX and Riverpod.

```dart
// ✅ ChangeNotifier pattern
class AuthModel extends ChangeNotifier {
  User? _user;
  User? get user => _user;

  Future<void> login(String email, String pwd) async {
    _user = await authRepo.login(email, pwd);
    notifyListeners();
  }
}

// main
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthModel()),
  ],
  child: const MyApp(),
);

// usage
final user = context.watch<AuthModel>().user;
context.read<AuthModel>().login(email, pwd);
```

**Advantages**: Official backing, gentle learning curve, seamless integration with Flutter's native `InheritedWidget`
**Disadvantages**: Cross-widget-tree data access requires manual `Provider.of` / `Selector`; deep nesting becomes unwieldy in large projects

### 4.3 Riverpod 3 (Western mainstream, advanced choice in China)

**When to choose Riverpod**:
- The team has experienced Flutter developers comfortable with English documentation
- Strict type safety, testability, and `BuildContext`-free state access are requirements
- Medium-to-large projects with significant cross-feature state sharing

```dart
// providers/auth_provider.dart
@riverpod
class Auth extends _$Auth {
  @override
  Future<User?> build() async {
    return await ref.read(authRepoProvider).currentUser();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() =>
      ref.read(authRepoProvider).login(email, password)
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      data: (user) => Text('Hi ${user?.name}'),
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
```

### 4.4 Bloc / Cubit (Western finance / large team choice, rare in China)

In China, Bloc appears almost exclusively in teams with rigorous code review (some top-tier securities firms and bank apps). Cubit is simpler than Bloc; the event-driven model is well-suited for audit-heavy contexts.

### 4.5 Fish-Redux (Xianyu / Alibaba — unmaintained)

A Redux-style component framework originally built by Alibaba's Xianyu team. Development has been essentially stalled since 2020. **Use only for maintaining legacy projects; NEVER use for new ones.** Known migration path from legacy code: decompose Page Components and migrate to Riverpod / Provider.

### 4.6 Decision Tree

```
Indie developer / fast onboarding / small-to-medium project   → GetX (stay within the 4.1 discipline boundaries)
Already on Provider / don't want a big rewrite                → Stick with Provider
New project / team can learn / need testability               → Riverpod 3
Finance / healthcare / strict audit requirements              → Bloc
Large enterprise hybrid stack                                 → Follow company standards (often in-house)
```

---

## 5. Screen Adaptation: flutter_screenutil (Essential in China)

Chinese UI designs are almost universally based on **iPhone 6 (750×1334 @2x, logical 375×667)** or **iPhone X (1125×2436 @3x, logical 375×812)**. Using physical pixels directly will break layouts across Android's wide range of screen sizes.

```dart
// main.dart
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: const Size(375, 812),   // iPhone X logical dimensions
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      title: 'Demo',
      home: const HomePage(),
    ),
  );
}

// Usage (extension methods)
Container(
  width: 100.w,    // scaled proportionally to design width
  height: 50.h,    // scaled proportionally to design height
  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
  child: Text('Hello', style: TextStyle(fontSize: 14.sp)),
)

// Equivalent to ScreenUtil().setWidth(100) etc.
```

**Important caveats**:

- `.sp` (font size) does not follow the system font scale by default, which hurts accessibility — for critical text, use `.sp` but ensure font size settings remain adjustable
- Account for orientation changes by observing `MediaQuery.orientationOf`
- `.r` (radius) = min(.w, .h) — prevents border radii from becoming elliptical
- NEVER apply `.w/.h` everywhere indiscriminately: 1px borders, `SafeArea`, and the status bar do not need adaptation

**Standard design handoff workflow**:

1. Agree on a single baseline design size across the team (iPhone X 375×812 or iPhone 6 375×667) — everyone MUST use the same
2. Use Figma / Lanhu / MasterGo for annotation; use `pt` (logical pixels) as the unit
3. Export icons at 1x/2x/3x, or use SVG (recommended: `flutter_svg`)

---

## 6. UI Component Library Selection for China

| Library | Source | Domestic Frequency | When to Use |
|---|---|---|---|
| **Material + Cupertino** | Official | Highest | Default starting point |
| **TDesign Flutter** | Tencent | Medium | Enterprise projects / unified design language |
| **flutter_screenutil** | OpenFlutter | Essential | Screen adaptation |
| **fluttertoast** | Community | High | Simple toasts |
| **bot_toast** | Community | Medium | Advanced toasts / loading overlays |
| **cached_network_image** | Community | Essential | Network image caching |
| **flutter_svg** | Community | High | SVG icons |
| **photo_view** | Community | High | Image browsing with zoom |
| **flutter_easyloading** | Community | Medium | Global loading indicator |
| **WeChat Assets Picker** | fluttercandies | High | WeChat-style image/video picker |

**TDesign Flutter quick reference** (Tencent, enterprise-grade):

```yaml
dependencies:
  tdesign_flutter: ^0.2.0
```

```dart
import 'package:tdesign_flutter/tdesign_flutter.dart';

TDButton(
  text: 'Confirm',
  theme: TDButtonTheme.primary,
  onTap: () {},
)
```

Compared to Western alternatives like shadcn / Material You: Chinese projects care more about visual consistency with WeChat / Alipay. TDesign has a solid reputation in B-side back-office systems and enterprise apps. Consumer-facing apps still tend toward fully custom UI.

---

## 7. Routing

### 7.1 Comparison of Common Approaches in China

| Approach | Domestic Frequency | Best For |
|---|---|---|
| **GetX routing** (`Get.toNamed`) | High | Projects already using GetX |
| **fluro** | Medium | Medium/large apps, named routes + parameter parsing |
| **go_router** | Growing | New projects, Web / deep link scenarios |
| **auto_route** | Low | Teams who prefer codegen-based type safety |
| Navigator 2.0 custom | Medium | Large enterprise / hybrid stacks |

### 7.2 go_router (Recommended for projects not using GetX)

```dart
final router = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    final isLogin = AuthService.instance.isLogin;
    if (!isLogin && state.matchedLocation != '/login') return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomePage(),
      routes: [
        GoRoute(
          path: 'detail/:id',
          builder: (_, state) => DetailPage(id: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);
```

### 7.3 fluro (Established choice for medium/large apps)

```dart
final router = FluroRouter();
router.define('/user/:id', handler: Handler(
  handlerFunc: (ctx, params) => UserPage(id: params['id']![0]),
));
router.navigateTo(context, '/user/123', transition: TransitionType.fadeIn);
```

---

## 8. Networking: dio + Chinese Interceptor Patterns

The "standard playbook" for networking in Chinese apps: unified token injection, unified loading state, unified toast messages, 401 redirect to login, request signing, and encryption. **Every project reimplements this from scratch**. The Western pattern of retrofit_dart + freezed is rarely seen in China.

```dart
// core/network/dio_client.dart
class DioClient {
  static late final Dio dio;

  static void init() {
    dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.addAll([
      _TokenInterceptor(),
      _LoadingInterceptor(),
      _ResponseInterceptor(),
      if (kDebugMode) LogInterceptor(responseBody: true),
    ]);
  }
}

// 1. Token interceptor: injects token automatically; refreshes on 401
class _TokenInterceptor extends QueuedInterceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = TokenStore.instance.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final ok = await TokenStore.instance.refresh();
      if (ok) {
        // Retry the original request
        final response = await DioClient.dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } else {
        // Navigate to login (using global navigatorKey to avoid context dependency)
        AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login', (_) => false,
        );
      }
    }
    handler.next(err);
  }
}

// 2. Global loading indicator
class _LoadingInterceptor extends Interceptor {
  int _count = 0;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['showLoading'] == true) {
      if (_count == 0) EasyLoading.show();
      _count++;
    }
    handler.next(options);
  }
  @override
  void onResponse(Response r, ResponseInterceptorHandler handler) {
    _dismiss(r.requestOptions);
    handler.next(r);
  }
  @override
  void onError(DioException e, ErrorInterceptorHandler handler) {
    _dismiss(e.requestOptions);
    handler.next(e);
  }
  void _dismiss(RequestOptions o) {
    if (o.extra['showLoading'] == true) {
      _count--;
      if (_count <= 0) { _count = 0; EasyLoading.dismiss(); }
    }
  }
}

// 3. Unified response unwrapping + toast
class _ResponseInterceptor extends Interceptor {
  @override
  void onResponse(Response r, ResponseInterceptorHandler handler) {
    final data = r.data as Map;
    final code = data['code'] as int;
    if (code == 0) {
      r.data = data['data'];
      handler.next(r);
    } else {
      Fluttertoast.showToast(msg: data['msg'] ?? 'Request failed');
      handler.reject(DioException(
        requestOptions: r.requestOptions,
        response: r,
        message: data['msg'],
      ));
    }
  }
}
```

**Typical API call**:

```dart
class UserApi {
  Future<User> getProfile() async {
    final r = await DioClient.dio.get(
      '/user/profile',
      options: Options(extra: {'showLoading': true}),
    );
    return User.fromJson(r.data);
  }
}
```

---

## 9. Project Directory Structure

### 9.1 Layer-Based Flat Layout (Chinese Mainstream, Small/Medium Projects)

```
lib/
├── api/                 ← all API definitions
│   ├── user_api.dart
│   └── order_api.dart
├── models/              ← data models (hand-written fromJson or json_serializable)
│   ├── user.dart
│   └── order.dart
├── pages/               ← pages (route-level)
│   ├── home/
│   │   ├── home_page.dart
│   │   └── home_controller.dart   ← GetX / Provider model
│   ├── login/
│   └── profile/
├── widgets/             ← shared components
│   ├── app_button.dart
│   └── loading_view.dart
├── services/            ← business services / local storage / push / analytics
│   ├── auth_service.dart
│   ├── push_service.dart
│   └── storage_service.dart
├── routes/              ← route table
│   └── app_routes.dart
├── utils/               ← utility functions (date / string / validation)
│   ├── date_util.dart
│   └── validator.dart
├── constants/           ← constants (colors / fonts / dimensions / API paths)
│   ├── app_colors.dart
│   └── api_paths.dart
├── core/                ← core infrastructure (networking / theme / config)
│   ├── network/
│   ├── theme/
│   └── env.dart
└── main.dart
```

**Best for**: fewer than 30 pages, 1–3 person teams, fast-moving requirements, low onboarding cost. **80% of Chinese projects look like this.**

### 9.2 Feature-Based + Clean Architecture (Western Mainstream, Large Projects)

Only adopt this when there are 3 or more independent business domains, an architect on the team, and a long-term project horizon (2+ years):

```
lib/
├── core/
│   ├── error/        ← Failure / Exception
│   ├── network/      ← dio client / interceptors
│   ├── theme/
│   ├── utils/
│   └── di.dart       ← get_it registrations
├── features/         ← ★ split by business domain
│   └── auth/
│       ├── data/
│       │   ├── datasources/    remote / local
│       │   ├── models/         JSON DTOs (freezed)
│       │   └── repositories/   Repository implementations
│       ├── domain/
│       │   ├── entities/
│       │   ├── repositories/   abstract
│       │   └── usecases/
│       └── presentation/
│           ├── pages/
│           ├── widgets/
│           └── viewmodels/     ViewModel / Bloc / Cubit
├── shared/           ← cross-feature components
└── main.dart
```

**Unidirectional dependency**: `presentation → domain ← data` (domain is the core and MUST NOT depend on outer layers)

### 9.3 How to Choose

- Solo / two-person / MVP stage → 9.1 flat layout
- Team standards required, stable requirements, architecture review in place → 9.2
- Large enterprise hybrid stack → follow company standards

**Anti-patterns**: forcing Clean Architecture at MVP stage, only to have PM churn requirements and leave everything broken within three months; or letting a grown project accumulate 50+ files in `pages/` with tangled cross-references.

---

## 10. Hybrid Stacks: FlutterBoost (Large Enterprise Scenarios)

Major Chinese tech companies (Alibaba, ByteDance, Meituan, JD, Tencent) almost never ship pure Flutter apps. **The dominant pattern is a Native host app with embedded Flutter pages.** The native `FlutterEngine.add` API suffers from poor performance, rapid memory growth, and chaotic lifecycle management — which is why Alibaba's Xianyu team open-sourced **FlutterBoost**.

```yaml
dependencies:
  flutter_boost:
    git:
      url: https://github.com/alibaba/flutter_boost.git
      ref: master
```

**Core concepts**:
- **Shared Engine**: all Flutter pages share a single `FlutterEngine`, keeping memory under control
- **Hybrid stack**: Native and Flutter pages push and pop within the same native navigation stack
- **Unified lifecycle**: both Native and Flutter go through `PageVisibilityObserver`

```dart
// main.dart
void main() {
  CustomFlutterBinding();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => FlutterBoostApp(
    routeFactory,
    appBuilder: (home) => MaterialApp(home: home),
  );
}

Route<dynamic>? routeFactory(RouteSettings settings, String? uniqueId) {
  if (settings.name == 'flutterPage1') {
    return MaterialPageRoute(builder: (_) => const FlutterPage1());
  }
  return null;
}

// Navigate to a native page
BoostNavigator.instance.push('nativePage', arguments: {'id': 1});

// Navigate to a Flutter page
BoostNavigator.instance.push('flutterPage1');
```

**Pitfalls**:

- Conflicts with GetX routing (FlutterBoost MUST take ownership of routing) → NEVER use GetX routing when integrating a hybrid stack
- Resources / fonts / themes must be configured separately on both the Native and Flutter sides
- Flutter upgrades carry significant risk; FlutterBoost tends to lag behind Flutter's release cadence

**ByteDance in-house hybrid stack**: Feishu, Douyin, and TikTok use proprietary solutions that are not open-sourced. If you're doing Flutter work within ByteDance, follow internal standards.

**Pure Flutter app scenarios** (indie developers / utility apps) do not need FlutterBoost — just follow 9.1 or 9.2.

---

## 11. Push Notifications: JPush / GeTui / Umeng / OEM Channels

**What makes Chinese push notifications unique**: FCM is blocked in China, so domestic push services are mandatory. You MUST also integrate OEM push channels (Huawei / Xiaomi / OPPO / VIVO / Meizu / Honor) — without them, push notifications will not arrive after the app is killed in the background.

| Service | Characteristics | Domestic Frequency |
|---|---|---|
| **JPush (Aurora)** | Comprehensive docs, official Flutter plugin, active community | Highest |
| **GeTui** | Established, stable, enterprise-grade | High |
| **Umeng UPush** | Alibaba ecosystem, often used alongside Umeng analytics | Medium |
| **Huawei HMS Push** | Required for Huawei devices | Essential OEM channel |
| **Xiaomi MiPush** | Required for Xiaomi devices | Essential OEM channel |

**JPush integration example**:

```yaml
dependencies:
  jpush_flutter: ^3.4.4
```

```dart
class PushService {
  static final jpush = JPush();

  static Future<void> init() async {
    jpush.setup(
      appKey: Env.jpushAppKey,
      channel: 'developer-default',
      production: kReleaseMode,
      debug: kDebugMode,
    );

    jpush.addEventHandler(
      onReceiveNotification: (msg) async {
        // Notification received
      },
      onOpenNotification: (msg) async {
        // User tapped notification → navigate to the relevant page
        final pageRoute = msg['extras']?['cn.jpush.android.EXTRA']?['route'];
        if (pageRoute != null) AppRouter.go(pageRoute);
      },
    );

    jpush.applyPushAuthority(const NotificationSettingsIOS(
      sound: true, alert: true, badge: true,
    ));
  }

  static Future<String?> getRegistrationId() => jpush.getRegistrationID();
}
```

**OEM channel integration**: JPush and GeTui both offer "one-click OEM channel packaging." You need to register an AppKey from each OEM's developer portal and add it to `manifestPlaceholders` in `AndroidManifest.xml`. **This step is notoriously tedious** — budget 1–2 days for debugging.

---

## 12. Dart 3 Modern Features (You MUST Use These)

### 12.1 Records

```dart
(String, int) splitName(String full) {
  final parts = full.split(' ');
  return (parts.first, parts.length);
}

({String name, int age}) getUser() => (name: 'Alice', age: 30);
final user = getUser();
print(user.name);
```

### 12.2 Pattern Matching + sealed

```dart
sealed class Result<T> {}
class Success<T> extends Result<T> { final T data; Success(this.data); }
class Failure<T> extends Result<T> { final String message; Failure(this.message); }

String render(Result<User> r) => switch (r) {
  Success(data: final user) => 'Hi ${user.name}',
  Failure(message: final msg) => 'Error: $msg',
};
```

### 12.3 Null Safety

```dart
String? maybeName;
final name = maybeName ?? 'Unknown';
final length = maybeName?.length;
late final String token;
```

---

## 13. In-App Update Checks (Essential in China — No Google Play)

Chinese apps are distributed through a fragmented set of app stores (Huawei / Xiaomi / Tencent MyApp / OPPO / official website downloads). **Google Play in-app updates are unavailable**, so update detection MUST be implemented manually.

```dart
class UpdateService {
  static Future<void> checkUpdate(BuildContext context) async {
    final r = await DioClient.dio.get('/app/version', queryParameters: {
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'channel': await _getChannel(),  // app store channel
      'version': await _getCurrentVersion(),
    });
    final info = AppVersionInfo.fromJson(r.data);
    if (!info.hasUpdate) return;

    showDialog(context: context, barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdateDialog(info: info));
  }
}
```

Note: iOS does not allow apps to directly download an ipa — you MUST redirect to the App Store. Android can use a channel-specific download URL or direct apk download (requires the `INSTALL_PACKAGES` permission, plus Android 8.0+ install permission dialog).

---

## 14. Flutter vs Mini Programs: A Common Dilemma for Chinese Developers

| Dimension | Flutter | WeChat Mini Program / uni-app |
|---|---|---|
| Distribution | Own app, app store | Opened inside WeChat, zero installation |
| Performance | Near-native | WebView rendering, one tier slower |
| Package size | 5–10 MB baseline | < 2 MB (main package) |
| Release | App store review (Tencent MyApp: days / iOS: 1–7 days) | WeChat review (1–3 days) |
| Traffic | Own user base | Leverages WeChat ecosystem for acquisition |
| Complexity | High (native integrations / push / offline) | Medium (constrained by WeChat APIs) |
| Team | Single language (Dart) end-to-end | JS / Vue friendly |

**Typical Chinese project decisions**:
- Lightweight consumer features (campaigns / micro-tools / marketing pages) → Mini Program
- Consumer app with long-tail users, push notifications, offline support, or complex interactions → Flutter
- B-side enterprise internal apps → Flutter (no dependency on WeChat ecosystem)
- Both in parallel: Flutter App + Mini Program portfolio (complementary traffic channels)

Do not start with Flutter at MVP stage — validate with a Mini Program first, then build the Flutter app once the feature set has stabilized.

---

## 15. Recommended analysis_options.yaml

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - avoid_print
    - always_declare_return_types
    - prefer_single_quotes
    - require_trailing_commas
    - sort_pub_dependencies

analyzer:
  errors:
    invalid_annotation_target: ignore  # freezed compatibility
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/generated/**"
```

---

## 16. Widget Composition and Performance

```dart
// ❌ Bloated build method
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(/* 50 lines */),
    body: Column(children: [/* 100 lines */]),
  );
}

// ✅ Extract into small widgets
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    appBar: _HomeAppBar(),
    body: _HomeBody(),
  );
}
```

**`const` MUST be used wherever possible**:

```dart
Column(children: const [
  Padding(padding: EdgeInsets.all(8), child: Text('Static')),
  SizedBox(height: 16),
])
```

**`ListView` optimization**: for long lists, ALWAYS use `ListView.builder` — NEVER `ListView(children: [...])`. Cache network images with `cached_network_image`. Provide `itemExtent` when item height is fixed.

---

## 17. Testing

```dart
testWidgets('Login button triggers auth flow', (tester) async {
  final authRepo = MockAuthRepo();
  when(() => authRepo.login(any(), any())).thenAnswer((_) async => testUser);

  await tester.pumpWidget(MaterialApp(
    home: LoginPage(repo: authRepo),  // dependency injection — avoid Get.find
  ));

  await tester.enterText(find.byKey(const Key('email')), 'a@b.com');
  await tester.enterText(find.byKey(const Key('password')), 'pw');
  await tester.tap(find.byKey(const Key('submit')));
  await tester.pumpAndSettle();

  verify(() => authRepo.login('a@b.com', 'pw')).called(1);
});
```

Tools: **mocktail** (no codegen required); for GetX projects, use `Get.testMode = true` + `Get.put` to override dependencies.

---

## 18. Anti-Pattern Reference (Ranked by Domestic Frequency)

| Anti-Pattern | Domestic Frequency | Consequence |
|---|---|---|
| **GetX all-in-one overuse** (state + router + Get.find DI all together) | Very high | Unit testing nightmare, high refactoring cost |
| **Calling `Get.dialog` / `Get.snackbar` inside a Controller** | Very high | UI side-effects leak into business logic; untestable |
| **Skipping mirror configuration, causing `pub get` failures** | High | Day-one blocker that drives away new team members |
| **Not using `flutter_screenutil`, hardcoding px values** | High | Broken layouts on Android's diverse screen sizes |
| **`build()` method exceeding 50 lines** | High | Hard to maintain; poor performance |
| **Missing `const` constructors** | High | Unnecessary full-tree rebuilds; performance loss |
| **Hand-writing hundreds of lines of fromJson/toJson on models** | High | Error-prone when fields change; use json_serializable / freezed instead |
| **Rewriting dio interceptors per project** (no reuse) | High | Compounding maintenance cost across multi-project teams |
| **Using GetX routing after integrating a hybrid stack** | Medium | Two routing systems conflict |
| **Overusing `StatefulWidget`** (use stateless whenever possible) | Medium | Unnecessary rebuilds |
| **Calling networking/DB directly from widgets** | Medium | MUST go through a Repository / Service layer |
| **No layering (model / api / page all mixed together)** | Medium | Refactoring hell as the project scales |
| **Not integrating OEM push channels, relying only on the JPush main channel** | Medium | Push not received after background process kill |
| **Not declaring iOS / Android permissions in manifest / Info.plist** | Medium | App store rejection |
| **Using `dynamic` instead of concrete types** | Low | Loss of type checking |
| **Not using records / sealed in Dart 3+** | Low | Missing out on type-safe tools |
| **Not enforcing strict lint with `analysis_options.yaml`** | Low | Code smell accumulates |

---

## 19. Minimum Viable Project Template for China

```
lib/
├── api/                  ← UserApi / OrderApi
├── models/               ← User / Order (json_serializable)
├── pages/                ← home / login / profile
├── widgets/              ← AppButton / LoadingView
├── services/             ← AuthService / PushService
├── routes/app_routes.dart
├── core/
│   ├── network/dio_client.dart    ← Token / Loading / Response interceptors
│   ├── theme/app_theme.dart
│   └── env.dart
├── constants/
│   ├── app_colors.dart
│   └── api_paths.dart
├── utils/
└── main.dart
```

**Starter `pubspec.yaml` checklist**:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  get: ^4.6.6                   # or provider / flutter_riverpod
  flutter_screenutil: ^5.9.0
  fluttertoast: ^8.2.4
  flutter_easyloading: ^3.0.5
  cached_network_image: ^3.3.0
  shared_preferences: ^2.2.2
  flutter_svg: ^2.0.10
  jpush_flutter: ^3.4.4         # push notifications
  package_info_plus: ^5.0.1     # version number
  device_info_plus: ^9.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mocktail: ^1.0.3
```

---

## 20. Information Sources

**China-based**:
- [Flutter Chinese Docs](https://docs.flutter.cn)
- [Flutter Chinese Community flutter-io.cn](https://flutter-io.cn)
- [Guo Shuyu / GSYTech Blog](https://guoshuyu.cn)
- [Xianyu Tech - Alibaba Cloud Developer](https://developer.aliyun.com/group/idlefish)
- [Juejin Flutter Tag](https://juejin.cn/tag/Flutter)
- [Tsinghua TUNA Flutter Mirror](https://mirrors.tuna.tsinghua.edu.cn/help/flutter/)

**Framework official**:
- [GetX](https://pub.dev/packages/get) / [Provider](https://pub.dev/packages/provider) / [Riverpod](https://riverpod.dev/) / [Bloc](https://bloclibrary.dev/)
- [flutter_screenutil](https://pub.dev/packages/flutter_screenutil)
- [TDesign Flutter](https://tdesign.tencent.com/flutter/getting-started)
- [FlutterBoost](https://github.com/alibaba/flutter_boost)
- [JPush](https://github.com/jpush/jpush-flutter-plugin)
- [go_router](https://pub.dev/packages/go_router) / [fluro](https://pub.dev/packages/fluro)
- [dio](https://pub.dev/packages/dio)

**Effective Dart / Official Architecture**:
- [Effective Dart](https://dart.dev/effective-dart)
- [Flutter App Architecture Guide](https://docs.flutter.dev/app-architecture/guide)
- [Flutter Samples](https://github.com/flutter/samples)
