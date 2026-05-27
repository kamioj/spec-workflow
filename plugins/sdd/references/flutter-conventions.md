---
name: Flutter / Dart 工程化规范（国内向）
scope: Dart 3 语言现代特性 + 国内 Flutter 真实生态（状态管理 / UI / 路由 / 混合栈 / 推送 / 镜像）+ 反模式
note: 区别于国外 Riverpod/Bloc 主推，本文以国内项目真实占比为权重，GetX/Provider 作为现实主流坦诚列出，Riverpod/Bloc 作进阶推荐
audience: 给国内独立开发者、中小团队、大厂混合栈接入方使用，不是给硅谷 SaaS 团队
---

# Flutter / Dart 工程化规范（国内向）

## 0. 这份文档为什么不一样

国外 Flutter 教程（resocoder、Code With Andrea、官方 architecture guide）默认推 Riverpod / Bloc + Clean Architecture + feature-based 目录。**这套在国内中小团队真实落地率不到 20%**。国内现实是：

- **GetX 是中文教程最多、新手第一选择**（虽然是反模式重灾区，但绕不开）
- **Provider 是中文掘金 / B站 / Flutter 中文社区主推**，存量项目巨大
- **目录按层平铺**（pages / widgets / services / models / utils）远多于 features/data/domain/presentation
- **flutter_screenutil + dio + getx** 三件套是国内 80% 教程的起手配置
- **大厂场景几乎都是混合栈**（FlutterBoost / 自研 hybrid），不是纯 Flutter App
- **包依赖必须配镜像**（pub.flutter-io.cn），否则 `flutter pub get` 卡死

所以本文以"国内真实选型"为正文，**Riverpod 3 / Bloc / Clean Architecture 作为"国外推荐 / 进阶可选"列出**，不打压也不强推。每节附"国内频率"和"反模式信号"。

---

## 1. 官方权威与中文资源

| 资源 | 链接 | 用途 |
|---|---|---|
| Effective Dart | https://dart.dev/effective-dart | 命名 / 文档 / 风格 |
| Flutter 官方架构指南 | https://docs.flutter.dev/app-architecture/guide | 国外主流 |
| Flutter 中文文档 | https://docs.flutter.cn | 镜像 + 翻译 |
| Flutter 中文社区 | https://flutter-io.cn | 国内入门首选 |
| 掘金 Flutter 专栏 | https://juejin.cn/tag/Flutter | 国内文章密度最高 |
| 郭树煜 GSYTech | https://guoshuyu.cn | 国内最系统的 Flutter 中文博客 |
| 闲鱼技术 | https://developer.aliyun.com/group/idlefish | 国内 Flutter 大厂实践 |

**Effective Dart 速查**：

- 库 / 文件 `lowercase_with_underscores`（`user_profile.dart`），类 `PascalCase`，变量 / 方法 `camelCase`
- **常量 `camelCase`**（Dart 特殊，不是 `UPPER_SNAKE`）
- 类型推导优先 `var`，公开 API 显式标注
- 优先 `final` 而非 `var`
- 字符串拼接用插值 `'$name'` 不用 `+`

---

## 2. 国内 Flutter 镜像配置（必做第一步）

不配镜像装不上。**Flutter 中文社区官方镜像**：

```pwsh
# Windows 用户级环境变量（pwsh）
[Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', 'https://pub.flutter-io.cn', 'User')
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'User')
```

```bash
# macOS / Linux ~/.zshrc 或 ~/.bashrc
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

**备用镜像**：
- 清华 TUNA：`https://mirrors.tuna.tsinghua.edu.cn/flutter/`
- 腾讯云：`https://mirrors.cloud.tencent.com/flutter/`

**私有 pub 仓库**（团队内部）：JFrog Artifactory / Nexus 都支持 pub repo，企业项目避免依赖公共 pub 拉取。

**CI 注意**：GitHub Actions / GitLab CI 在国内 runner 上也要在 workflow 里 `env:` 注入这两个变量。

---

## 3. 默认技术栈选型（2026 国内真实占比）

| 维度 | 国内主流（占比） | 国外推荐 | 进阶 / 团队规范场景 |
|---|---|---|---|
| Flutter 版本 | **3.41.x stable**（2026.05） | 同 | — |
| Dart 版本 | **3.5+**（records / patterns / sealed） | 同 | — |
| 状态管理 | **GetX**（≈40% 教程）/ **Provider**（≈30%）| Riverpod 3 | Riverpod 3 / Bloc |
| 路由 | **GetX 内置**（与 GetX 状态绑死） / **fluro**（中大型）/ Navigator 2.0 自实现 | go_router | go_router / auto_route |
| HTTP | **dio**（一致选择，国内国外都用） | dio | — |
| UI 组件 | **flutter_screenutil**（适配必备）+ Material/Cupertino | 同 | TDesign Flutter（腾讯） |
| Toast | **fluttertoast** / **bot_toast** | — | — |
| DI | GetX 自带 `Get.put` / `Get.find`（混用）| get_it + injectable | get_it + injectable |
| JSON | 手写 fromJson/toJson（多）/ json_serializable | freezed + json_serializable | freezed + json_serializable |
| 推送 | **极光 JPush**（≈50%）/ **个推** / **友盟** / **华为 HMS Push** | FCM（国内不可用）| 极光 + 厂商通道 |
| 混合栈 | **FlutterBoost**（阿里）/ 自研 | 不涉及 | FlutterBoost |
| 测试 | flutter_test + mocktail | 同 | — |

**国内真实最小可用栈（独立开发者 / 小项目首选）**：

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0                 # 网络
  get: ^4.6.6                 # 状态 + 路由 + DI 三合一（争议但好上手）
  flutter_screenutil: ^5.9.0  # 屏幕适配
  fluttertoast: ^8.2.4        # toast
  shared_preferences: ^2.2.2  # 本地 KV
  cached_network_image: ^3.3.0  # 网络图片
```

或者 **Provider 派**：

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  provider: ^6.1.1
  flutter_screenutil: ^5.9.0
  fluttertoast: ^8.2.4
  shared_preferences: ^2.2.2
  go_router: ^14.0.0          # 比 fluro 现代
```

---

## 4. 状态管理：国内真实选型决策

### 4.1 GetX（国内第一占比，争议最大）

**国内地位**：B 站 / 掘金 / CSDN 中文教程数量 GetX > Provider > Riverpod > Bloc。新手入门 90% 从 GetX 开始。

**优点（实事求是）**：
- 上手极快，三行代码搞定状态 + 路由 + DI
- 不需要 `BuildContext` 传递，`Get.to(Page())` / `Get.back()` 极简
- 国内中文文档密集，问题 stackoverflow + 掘金都搜得到
- 性能不错，响应式更新粒度细

**缺点（必须知道）**：
- **state + router + DI 三合一耦合**，单元测试地狱
- 主仓库长期 single maintainer 风险，更新慢
- 与 Flutter 官方架构哲学冲突（导航不走 Navigator 2.0 ，深链 / Web / Restoration 都吃亏）
- 滥用 `Get.find` 当全局 service locator → 测试无法 mock

**用 GetX 的最低自律**：

```dart
// ✅ Controller 只放状态和方法，不做 UI
class CounterController extends GetxController {
  final count = 0.obs;
  void increment() => count.value++;
}

// ✅ 用 GetView 绑定，强类型
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

// ✅ Binding 集中注册依赖，可被覆盖（测试入口）
class CounterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CounterController());
  }
}
```

**GetX 反模式（国内最常见，必须警惕）**：

```dart
// ❌ 反模式 1：Controller 里直接 Get.dialog / Get.snackbar，无法测试
class BadController extends GetxController {
  Future<void> save() async {
    Get.dialog(LoadingDialog());  // UI 副作用混进业务逻辑
    await api.save();
    Get.back();
    Get.snackbar('成功', '保存完成');
  }
}

// ❌ 反模式 2：Get.find 当万能 service locator
final user = Get.find<UserController>().user;  // 隐式依赖，无法 mock
final api = Get.find<ApiService>();             // 测试要全局桩

// ❌ 反模式 3：路由跳转穿插业务逻辑
void onTap() {
  if (Get.find<AuthController>().isLogin) {
    Get.toNamed('/profile');
  } else {
    Get.toNamed('/login');
  }
}
// 这种判断应该在 router 的 middleware/redirect 层做
```

### 4.2 Provider（国内第二，存量大）

**国内地位**：Flutter 中文社区、《Flutter 实战·第二版》（杜文）主推。存量项目仍多，新项目逐渐被 GetX 和 Riverpod 蚕食。

```dart
// ✅ ChangeNotifier 模式
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

// 用法
final user = context.watch<AuthModel>().user;
context.read<AuthModel>().login(email, pwd);
```

**优点**：官方背书、上手温和、与 Flutter 原生 InheritedWidget 无缝
**缺点**：跨层级传值要手动 `Provider.of` / `Selector`，大型项目嵌套地狱

### 4.3 Riverpod 3（国外主推，国内进阶）

**何时选 Riverpod**：
- 团队有 Flutter 老人，能接受英文文档
- 需要严格类型安全、可测试性、不依赖 `BuildContext`
- 中大型项目，跨 feature 状态共享多

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

### 4.4 Bloc / Cubit（国外金融 / 大团队选择，国内少）

国内只在严格 code review 团队（部分头部券商 / 银行 App）见过。Cubit 比 Bloc 简单，事件驱动适合审计场景。

### 4.5 Fish-Redux（闲鱼，已停维护）

阿里闲鱼自研的 Redux 风格组件化框架，2020 年后基本停更。**仅遗留项目维护**，新项目禁用。已知遗留代码迁移路径：拆 Page Component → 切到 Riverpod / Provider。

### 4.6 决策树

```
独立开发者 / 上手快 / 中小项目     → GetX（守住 4.1 自律线）
已有 Provider 存量 / 不想大改      → Provider 继续
新项目 / 团队能学 / 要可测试性     → Riverpod 3
金融 / 医疗 / 强审计               → Bloc
混合栈大厂场景                     → 看公司规范（往往是自研）
```

---

## 5. 屏幕适配：flutter_screenutil（国内必备）

国内 UI 稿基本按 **iPhone 6（750×1334 @2x，逻辑 375×667）**或 **iPhone X（1125×2436 @3x，逻辑 375×812）**出。直接用物理像素会在 Android 各种尺寸上崩。

```dart
// main.dart
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: const Size(375, 812),   // iPhone X 逻辑尺寸
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      title: 'Demo',
      home: const HomePage(),
    ),
  );
}

// 用法（扩展方法）
Container(
  width: 100.w,    // 按设计稿宽度比例
  height: 50.h,    // 按设计稿高度比例
  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
  child: Text('Hello', style: TextStyle(fontSize: 14.sp)),
)

// 等价于 ScreenUtil().setWidth(100) 等
```

**注意点**：

- `.sp`（字体）默认不跟系统字号缩放，无障碍用户体验差 → 关键文本用 `.sp` 但确保设置可调
- 横竖屏切换要在 `MediaQuery.orientationOf` 变化时考虑
- `.r`（半径）= min(.w, .h)，避免圆角变椭圆
- 不要全局滥用 `.w/.h`：边框 1px、SafeArea、状态栏不需要适配

**国内设计稿对接 SOP**：

1. 设计稿统一一种基准（iPhone X 375×812 或 iPhone 6 375×667），全队统一
2. 标注用 Figma / 蓝湖 / MasterGo，单位用 `pt`（逻辑像素）
3. icon 切 1x/2x/3x 三套，或 svg（推荐 flutter_svg）

---

## 6. 国内 UI 组件库选型

| 组件库 | 来源 | 国内频率 | 何时用 |
|---|---|---|---|
| **Material + Cupertino** | 官方 | 最高 | 默认起手 |
| **TDesign Flutter** | 腾讯 | 中 | 企业项目 / 想要统一设计语言 |
| **flutter_screenutil** | OpenFlutter | 必备 | 屏幕适配 |
| **fluttertoast** | 社区 | 高 | 简单 toast |
| **bot_toast** | 社区 | 中 | 高级 toast / loading 弹层 |
| **cached_network_image** | 社区 | 必备 | 网络图缓存 |
| **flutter_svg** | 社区 | 高 | SVG 图标 |
| **photo_view** | 社区 | 高 | 图片浏览缩放 |
| **flutter_easyloading** | 社区 | 中 | 全局 loading |
| **WeChat Assets Picker** | fluttercandies | 高 | 仿微信图片/视频选择 |

**TDesign Flutter 速查**（腾讯出品，企业级）：

```yaml
dependencies:
  tdesign_flutter: ^0.2.0
```

```dart
import 'package:tdesign_flutter/tdesign_flutter.dart';

TDButton(
  text: '确认',
  theme: TDButtonTheme.primary,
  onTap: () {},
)
```

对比国外 shadcn / Material You：国内更看重"和微信 / 支付宝视觉一致"，TDesign 在 B 端中后台和企业 App 有口碑。C 端 App 仍多自定义。

---

## 7. 路由方案

### 7.1 国内常见方案对比

| 方案 | 国内频率 | 适用 |
|---|---|---|
| **GetX 路由**（`Get.toNamed`）| 高 | 用了 GetX 就跟着用 |
| **fluro** | 中 | 中大型，命名路由 + 参数解析 |
| **go_router** | 上升中 | 新项目、Web / 深链场景 |
| **auto_route** | 低 | 喜欢 codegen 类型安全 |
| Navigator 2.0 自实现 | 中 | 大厂自研 / 混合栈 |

### 7.2 go_router 推荐（无 GetX 项目首选）

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

### 7.3 fluro（老牌中大型）

```dart
final router = FluroRouter();
router.define('/user/:id', handler: Handler(
  handlerFunc: (ctx, params) => UserPage(id: params['id']![0]),
));
router.navigateTo(context, '/user/123', transition: TransitionType.fadeIn);
```

---

## 8. 网络层：dio + 国内拦截器套路

国内 App 网络层的"标准动作"：统一 token / 统一 loading / 统一 toast / 401 跳登录 / 验签 / 加密。**所有项目都自实现一遍**，国外 retrofit_dart + freezed 那一套在国内反而少用。

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

// 1. Token 拦截器：自动加 token，401 自动刷新
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
        // 重发请求
        final response = await DioClient.dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } else {
        // 跳登录（用全局 navigatorKey，避免 context 依赖）
        AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login', (_) => false,
        );
      }
    }
    handler.next(err);
  }
}

// 2. 全局 Loading
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

// 3. 统一响应解包 + toast
class _ResponseInterceptor extends Interceptor {
  @override
  void onResponse(Response r, ResponseInterceptorHandler handler) {
    final data = r.data as Map;
    final code = data['code'] as int;
    if (code == 0) {
      r.data = data['data'];
      handler.next(r);
    } else {
      Fluttertoast.showToast(msg: data['msg'] ?? '请求失败');
      handler.reject(DioException(
        requestOptions: r.requestOptions,
        response: r,
        message: data['msg'],
      ));
    }
  }
}
```

**典型 API 调用**：

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

## 9. 项目目录结构

### 9.1 按层平铺（国内主流，中小项目）

```
lib/
├── api/                 ← 所有接口定义
│   ├── user_api.dart
│   └── order_api.dart
├── models/              ← 数据模型（手写 fromJson 或 json_serializable）
│   ├── user.dart
│   └── order.dart
├── pages/               ← 页面（路由级）
│   ├── home/
│   │   ├── home_page.dart
│   │   └── home_controller.dart   ← GetX / Provider model
│   ├── login/
│   └── profile/
├── widgets/             ← 通用组件
│   ├── app_button.dart
│   └── loading_view.dart
├── services/            ← 业务服务 / 本地存储 / 推送 / 埋点
│   ├── auth_service.dart
│   ├── push_service.dart
│   └── storage_service.dart
├── routes/              ← 路由表
│   └── app_routes.dart
├── utils/               ← 工具函数（日期 / 字符串 / 校验）
│   ├── date_util.dart
│   └── validator.dart
├── constants/           ← 常量（颜色 / 字体 / 尺寸 / 接口路径）
│   ├── app_colors.dart
│   └── api_paths.dart
├── core/                ← 核心（网络 / 主题 / 配置）
│   ├── network/
│   ├── theme/
│   └── env.dart
└── main.dart
```

**适用**：< 30 个页面、1-3 人团队、需求迭代快、招新人成本要低。**国内 80% 项目长这样**。

### 9.2 Feature-based + Clean Architecture（国外主流，大项目）

3 个以上独立业务域、团队有架构师、长期项目（≥ 2 年）才上这套：

```
lib/
├── core/
│   ├── error/        ← Failure / Exception
│   ├── network/      ← dio client / interceptors
│   ├── theme/
│   ├── utils/
│   └── di.dart       ← get_it 注册
├── features/         ← ★ 按业务功能拆
│   └── auth/
│       ├── data/
│       │   ├── datasources/    远程 / 本地
│       │   ├── models/         JSON DTO（freezed）
│       │   └── repositories/   Repository 实现
│       ├── domain/
│       │   ├── entities/
│       │   ├── repositories/   abstract
│       │   └── usecases/
│       └── presentation/
│           ├── pages/
│           ├── widgets/
│           └── viewmodels/     ViewModel / Bloc / Cubit
├── shared/           ← 跨 feature 组件
└── main.dart
```

**单向依赖**：`presentation → domain ← data`（domain 是核心，不依赖外层）

### 9.3 怎么选

- 单人 / 双人 / MVP 阶段 → 9.1 按层平铺
- 团队规范要求、需求稳定、有架构 review → 9.2
- 大厂混合栈 → 看公司规范

**反模式**：MVP 阶段强上 Clean Architecture，三个月就被 PM 改需求拆烂；或者项目做大了还在 `pages/` 里堆 50 个文件，互相引用乱成一团。

---

## 10. 混合栈：FlutterBoost（阿里大厂场景）

国内大厂（阿里、字节、美团、京东、腾讯）几乎没有纯 Flutter App，**主流是 Native 主体 + Flutter 页面嵌入**。原生的 `FlutterEngine.add` API 性能差、内存涨快、生命周期乱，所以阿里闲鱼开源了 **FlutterBoost**。

```yaml
dependencies:
  flutter_boost:
    git:
      url: https://github.com/alibaba/flutter_boost.git
      ref: master
```

**核心概念**：
- **共享 Engine**：所有 Flutter 页面共用一个 `FlutterEngine`，内存可控
- **混合栈**：Native 和 Flutter 页面在同一个原生栈里互相 push / pop
- **生命周期统一**：原生 / Flutter 都走 `PageVisibilityObserver`

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

// 跳原生页面
BoostNavigator.instance.push('nativePage', arguments: {'id': 1});

// 跳 Flutter 页面
BoostNavigator.instance.push('flutterPage1');
```

**陷阱**：

- 与 GetX 路由冲突（FlutterBoost 必须接管路由）→ 接入混合栈就**不要用 GetX 路由**
- 资源 / 字体 / 主题需要在 Native 和 Flutter 两边各配一份
- Flutter 升级风险大，FlutterBoost 跟 Flutter 主版本节奏有滞后

**字节自研 hybrid stack**：飞书、抖音、TikTok 国际版用自研方案，不开源。如果你在字节系做 Flutter，按内部规约走。

**纯 Flutter App 场景**（独立开发者 / 工具类 App）不需要 FlutterBoost，按 9.1 / 9.2 走就好。

---

## 11. 推送：极光 / 个推 / 友盟 / 厂商通道

**国内推送的特殊性**：FCM 在国内被墙，必须用国产推送服务。**且必须接厂商通道**（华为 / 小米 / OPPO / VIVO / 魅族 / 荣耀），否则后台杀进程后收不到推送。

| 服务 | 特点 | 国内频率 |
|---|---|---|
| **极光 JPush** | 文档全、Flutter 插件官方维护、社区活跃 | 最高 |
| **个推 GeTui** | 老牌、稳定、企业方案 | 高 |
| **友盟 UPush** | 阿里系、配合统计一起用 | 中 |
| **华为 HMS Push** | 华为机型必须 | 必备厂商通道 |
| **小米 MiPush** | 小米机型 | 必备厂商通道 |

**极光集成示例**：

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
        // 收到通知
      },
      onOpenNotification: (msg) async {
        // 用户点击通知 → 跳对应页
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

**厂商通道集成**：极光 / 个推都提供"厂商通道一键打包"，需要在各厂商开发者后台申请 AppKey，配进 `AndroidManifest.xml` 的 `manifestPlaceholders`。**这一步特别折腾**，预留 1-2 天调试。

---

## 12. Dart 3 现代特性（一定要用）

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

### 12.2 Pattern matching + sealed

```dart
sealed class Result<T> {}
class Success<T> extends Result<T> { final T data; Success(this.data); }
class Failure<T> extends Result<T> { final String message; Failure(this.message); }

String render(Result<User> r) => switch (r) {
  Success(data: final user) => 'Hi ${user.name}',
  Failure(message: final msg) => 'Error: $msg',
};
```

### 12.3 Null safety

```dart
String? maybeName;
final name = maybeName ?? 'Unknown';
final length = maybeName?.length;
late final String token;
```

---

## 13. 应用更新检测（国内必备，无 Google Play）

国内 App 走应用商店各种渠道分发（华为 / 小米 / 应用宝 / OPPO / 自有官网下载），**Google Play 内更新不可用**，必须自实现更新检测。

```dart
class UpdateService {
  static Future<void> checkUpdate(BuildContext context) async {
    final r = await DioClient.dio.get('/app/version', queryParameters: {
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'channel': await _getChannel(),  // 商店渠道
      'version': await _getCurrentVersion(),
    });
    final info = AppVersionInfo.fromJson(r.data);
    if (!info.hasUpdate) return;

    showDialog(context: context, barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdateDialog(info: info));
  }
}
```

注意：iOS 不允许 App 内直接下载 ipa，只能跳 App Store；Android 可以走渠道接口或直接下载 apk（需要 `INSTALL_PACKAGES` 权限、Android 8.0+ 弹安装许可）。

---

## 14. Flutter vs 小程序：国内开发者经常纠结

| 维度 | Flutter | 微信小程序 / uni-app |
|---|---|---|
| 渠道 | 自有 App，商店分发 | 微信内打开，零安装 |
| 性能 | 接近原生 | WebView 渲染，差一档 |
| 包大小 | 起步 5-10MB | < 2MB（主包） |
| 上线 | 商店审核（应用宝几天 / iOS 1-7 天） | 微信审核（1-3 天） |
| 流量 | 自有用户 | 借微信生态拉新 |
| 复杂度 | 高（原生交互 / 推送 / 离线） | 中（受微信 API 限制） |
| 团队 | Dart 一门语言全栈 | JS / Vue 友好 |

**国内典型选型**：
- C 端轻量功能（活动 / 小工具 / 营销页）→ 小程序
- C 端长尾用户、需要推送 / 离线 / 复杂交互 → Flutter
- B 端企业内部应用 → Flutter（不依赖微信生态）
- 两者并存：Flutter App + 小程序矩阵（流量场景互补）

不要在 MVP 阶段做 Flutter，先做小程序验证；功能稳定再做 Flutter App。

---

## 15. analysis_options.yaml 推荐

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
    invalid_annotation_target: ignore  # freezed 兼容
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/generated/**"
```

---

## 16. Widget 组合与性能

```dart
// ❌ build 方法臃肿
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(/* 50 行 */),
    body: Column(children: [/* 100 行 */]),
  );
}

// ✅ 拆小 widget
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    appBar: _HomeAppBar(),
    body: _HomeBody(),
  );
}
```

**const 必须用**：

```dart
Column(children: const [
  Padding(padding: EdgeInsets.all(8), child: Text('Static')),
  SizedBox(height: 16),
])
```

**ListView 优化**：长列表强制 `ListView.builder`，不要 `ListView(children: [...])`；图片用 `cached_network_image`；高度固定时给 `itemExtent`。

---

## 17. 测试

```dart
testWidgets('Login button triggers auth flow', (tester) async {
  final authRepo = MockAuthRepo();
  when(() => authRepo.login(any(), any())).thenAnswer((_) async => testUser);

  await tester.pumpWidget(MaterialApp(
    home: LoginPage(repo: authRepo),  // 依赖注入，不要 Get.find
  ));

  await tester.enterText(find.byKey(const Key('email')), 'a@b.com');
  await tester.enterText(find.byKey(const Key('password')), 'pw');
  await tester.tap(find.byKey(const Key('submit')));
  await tester.pumpAndSettle();

  verify(() => authRepo.login('a@b.com', 'pw')).called(1);
});
```

工具：**mocktail**（无 codegen）；GetX 项目用 `Get.testMode = true` + `Get.put` 覆盖依赖。

---

## 18. 反模式清单（按国内频率排序）

| 反模式 | 国内频率 | 后果 |
|---|---|---|
| **GetX 三合一滥用**（state + router + Get.find DI 全用）| 极高 | 单元测试地狱，重构高成本 |
| **Controller 里写 `Get.dialog` / `Get.snackbar`** | 极高 | UI 副作用混进业务逻辑，无法测试 |
| **没配镜像导致 `pub get` 失败** | 高 | 新人入坑第一天劝退 |
| **不用 `flutter_screenutil`，硬编码 px** | 高 | Android 各种屏幕崩 |
| **build() 方法超 50 行** | 高 | 难维护，性能差 |
| **不加 `const` constructor** | 高 | rebuild 全树，性能损失 |
| **手写 fromJson/toJson 几百行 model** | 高 | 字段加减易错，应用 json_serializable / freezed |
| **dio 拦截器每个项目重写一遍**（不复用）| 高 | 团队多项目维护成本叠加 |
| **混合栈接入还坚持用 GetX 路由** | 中 | 路由两套系统打架 |
| **`StatefulWidget` 滥用**（能 stateless 就别 stateful）| 中 | 不必要 rebuild |
| **widget 内直调网络/DB** | 中 | 必须经 Repository / Service |
| **没分层（model / api / page 混一起）**| 中 | 项目做大后重构地狱 |
| **不接厂商推送通道，只接极光主通道** | 中 | 后台杀进程收不到推送 |
| **iOS / Android 各种权限不在 manifest / Info.plist 声明** | 中 | 上架被拒 |
| **用 dynamic 代替具体类型** | 低 | 失去类型检查 |
| **Dart 3+ 不用 records / sealed** | 低 | 错过类型安全工具 |
| **不用 `analysis_options.yaml` 严格 lint** | 低 | 坏味道堆积 |

---

## 19. 国内 Flutter 项目最小可用启动模板

```
lib/
├── api/                  ← UserApi / OrderApi
├── models/               ← User / Order（json_serializable）
├── pages/                ← home / login / profile
├── widgets/              ← AppButton / LoadingView
├── services/             ← AuthService / PushService
├── routes/app_routes.dart
├── core/
│   ├── network/dio_client.dart    ← Token / Loading / Response 三拦截器
│   ├── theme/app_theme.dart
│   └── env.dart
├── constants/
│   ├── app_colors.dart
│   └── api_paths.dart
├── utils/
└── main.dart
```

**`pubspec.yaml` 起手清单**：

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  get: ^4.6.6                   # 或 provider / flutter_riverpod
  flutter_screenutil: ^5.9.0
  fluttertoast: ^8.2.4
  flutter_easyloading: ^3.0.5
  cached_network_image: ^3.3.0
  shared_preferences: ^2.2.2
  flutter_svg: ^2.0.10
  jpush_flutter: ^3.4.4         # 推送
  package_info_plus: ^5.0.1     # 版本号
  device_info_plus: ^9.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mocktail: ^1.0.3
```

---

## 20. 信息源

**国内**：
- [Flutter 中文文档](https://docs.flutter.cn)
- [Flutter 中文社区 flutter-io.cn](https://flutter-io.cn)
- [郭树煜 GSYTech 博客](https://guoshuyu.cn)
- [闲鱼技术 - 阿里云开发者](https://developer.aliyun.com/group/idlefish)
- [掘金 Flutter 标签](https://juejin.cn/tag/Flutter)
- [清华 TUNA Flutter 镜像](https://mirrors.tuna.tsinghua.edu.cn/help/flutter/)

**框架官方**：
- [GetX](https://pub.dev/packages/get) / [Provider](https://pub.dev/packages/provider) / [Riverpod](https://riverpod.dev/) / [Bloc](https://bloclibrary.dev/)
- [flutter_screenutil](https://pub.dev/packages/flutter_screenutil)
- [TDesign Flutter](https://tdesign.tencent.com/flutter/getting-started)
- [FlutterBoost](https://github.com/alibaba/flutter_boost)
- [极光 JPush](https://github.com/jpush/jpush-flutter-plugin)
- [go_router](https://pub.dev/packages/go_router) / [fluro](https://pub.dev/packages/fluro)
- [dio](https://pub.dev/packages/dio)

**Effective Dart / 官方架构**：
- [Effective Dart](https://dart.dev/effective-dart)
- [Flutter App Architecture Guide](https://docs.flutter.dev/app-architecture/guide)
- [Flutter Samples](https://github.com/flutter/samples)
