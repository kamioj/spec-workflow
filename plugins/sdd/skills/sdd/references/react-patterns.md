---
name: React 工程化与设计模式（国内主流版）
companion: bulletproof-react.md（国外社区 fork，作为现代化升级路径参考）+ js-style.md / ts-conventions.md
note: 本文聚焦"国内 React 项目怎么组织"。通用语法 / 命名 / TS 规则见 google-ts-style.md。
---

# React 工程化与设计模式（国内实战导向）

国内 React 生态与国外社区差异极大。Bulletproof-React / Zustand / TanStack 全家桶是国外推荐，但国内 80%+ 的 React 项目（尤其中后台）跑在 **Umi + Ant Design + dva/RTK** 这套阿里事实标准上。本文以国内现状作为**默认推荐**，国外栈作为可选升级路径。

`bulletproof-react.md` 是国外参考；本文是国内决策 + 设计模式 + 反模式。

---

## 1. 国内 React 项目类型分布（前提认知）

按出现频次排：

| 类型 | 占比（粗估）| 典型场景 | 主推栈 |
|---|---|---|---|
| **企业中后台**（admin / 管理后台 / SaaS）| ~60% | OA、CRM、数据平台、内部工具 | **Umi + Ant Design Pro + dva** |
| **C 端 H5**（活动页、营销、官网）| ~20% | 电商活动、落地页、轻应用 | Vite + React + 轻量 UI |
| **小程序 / 跨端**（微信 / 抖音 / 京东等）| ~15% | 商城、工具类小程序 | **Taro** |
| **SSR / 全栈**（NextJS / Umi SSR）| ~5% | 内容站、SEO 需求 | Umi SSR > Next.js（国内 Next 受 GFW 影响小但生态弱）|

**重要事实**：

- 国内 React 项目 ≈ 中后台项目。"React 工程化"在国内语境下默认指**中后台工程化**
- C 端高性能场景仍以 Vue 居多（尤努雨溪国内号召力 + 字节系部分团队偏好）
- React 19 国内普及度低，存量大量 React 17 / 18 项目；Class Component 老项目仍占可观比例

---

## 2. 默认技术栈选型（国内 2026 主流）

### 2.1 中后台（首选场景）

| 维度 | 国内主流 | 国外参考（升级路径）|
|---|---|---|
| 框架 | **UmiJS 4**（阿里出品 / Ant Design Pro 默认）| Vite + React Router |
| 脚手架 | **Ant Design Pro** | create-vite + 手搭 |
| 路由 | Umi 约定式路由（`src/pages/` 自动映射）| TanStack Router |
| UI 库 | **Ant Design 5** + **Pro Components** | shadcn/ui / Radix |
| 数据流 | **dva**（Umi 内置）/ **@umijs/max** model | Zustand / Jotai |
| 请求 | **umi-request** / **axios** + Pro Service 约定 | TanStack Query |
| 表单 | **Ant Design Form** + `ProForm` | react-hook-form + zod |
| 表格 | **ProTable**（杀手锏）| TanStack Table |
| 图表 | **AntV G2 / G6 / X6** | Recharts / D3 |
| 样式 | Less / CSS Modules（Umi 默认）| Tailwind CSS |
| 构建 | Umi 内置（基于 Vite / Webpack 可切）| Vite |
| 类型 | TypeScript（Ant Design Pro 5 起默认）| 同 |
| 测试 | Jest + RTL（Umi 内置）| Vitest + RTL |

### 2.2 C 端 H5

| 维度 | 国内主流 | 备注 |
|---|---|---|
| 构建 | **Vite** | 新项目 |
| UI | **Vant**（有赞）/ **NutUI**（京东）/ **Antd Mobile** | 移动端三大件 |
| 路由 | React Router v6 | 简单够用 |
| 状态 | useState + Context / Zustand | 不引入 dva |
| 请求 | axios + 自封装 hooks | 不上 TanStack Query 也行 |
| 兼容 | 关注 iOS Safari / 微信内置浏览器 | 国内必须 |

### 2.3 小程序 / 跨端

- **Taro**（京东开源）—— 国内事实标准，一套 React 代码编译到微信 / 支付宝 / 抖音 / 京东 / 百度 / QQ / 鸿蒙 / H5 / RN
- **Remax**（蚂蚁）—— 已不太活跃，存量项目
- **uni-app（Vue 系）** —— 跨端最强但是 Vue，React 团队基本不选

### 2.4 不建议在新项目用

- `create-react-app`（已废弃）
- Webpack 4 / Babel 6 老配置
- Class Component（仅老项目）
- dva 直接版（用 Umi 内置的 `@umijs/max` 数据流，等价但配置少）
- Arco Design（**字节官方维护近乎停滞**，2025 起社区报告 issue 堆积、核心贡献者离场，不建议新项目选型）
- Next.js（除非明确需要 Vercel / 国外部署；国内 Umi SSR 生态适配更好）
- styled-components（国内基本不用，Less / CSS Modules 占绝对主流）

---

## 3. 国内中后台标准目录结构（Umi + Ant Design Pro 约定）

```
src/
├── pages/                    ← ★ 约定式路由（Umi 核心）
│   ├── index.tsx             →  /
│   ├── user/
│   │   ├── list.tsx          →  /user/list
│   │   ├── detail.[id].tsx   →  /user/detail/:id
│   │   └── components/       页面专属组件
│   └── 404.tsx
├── components/               ← 跨页面复用组件（按层平铺）
│   ├── RightContent/
│   ├── HeaderDropdown/
│   └── Footer/
├── services/                 ← ★ 接口层（按业务域组织）
│   ├── user.ts               所有 user 相关接口
│   ├── order.ts
│   └── typings.d.ts          接口类型定义
├── models/                   ← ★ dva / @umijs/max model
│   ├── user.ts               全局用户态
│   └── global.ts             全局配置态
├── layouts/                  ← 布局组件
│   └── BasicLayout.tsx
├── utils/                    ← 纯函数工具
├── hooks/                    ← 跨页面 hooks
├── constants/                ← 枚举 / 常量
├── locales/                  ← i18n（zh-CN / en-US）
├── assets/                   ← 图片 / 字体
├── access.ts                 ← Umi 权限配置
├── app.tsx                   ← Umi 运行时配置（请求拦截、布局、初始数据）
├── global.less
└── typings.d.ts

config/
├── config.ts                 ← Umi 主配置
├── routes.ts                 ← 路由配置（也可走约定式）
├── proxy.ts                  ← 本地代理
└── defaultSettings.ts        ← Pro Layout 配置
```

**国内目录结构的核心特征**：**按层平铺**（pages / services / models / components）而非 Bulletproof 的**按 feature 拆分**。原因：

1. **Umi 约定式路由强制 `src/pages/`** —— 框架定死了入口
2. **Ant Design Pro 脚手架就是这个结构** —— 新人接手成本低
3. **国内中后台业务边界模糊**，按 feature 拆完反而难维护（feature 之间频繁互调）
4. **大厂二开模板都是按层** —— 阿里 / 蚂蚁内部模板沿用此约定

> 国外的 Bulletproof `features/` 结构更"工程正确"但国内团队普遍**不买账**——新人不熟、模板不匹配、跟阿里官方文档对不上。仅在「大型 SaaS / 长期演进项目 / 团队有 React 老兵把控」时才考虑迁移到 feature-based。

---

## 4. 国内 C 端 H5 项目结构

H5 项目要轻，不上 Umi：

```
src/
├── pages/                    ← 按页面平铺
│   ├── Home/
│   │   ├── index.tsx
│   │   ├── index.module.less
│   │   └── components/
│   └── Order/
├── components/               ← 通用组件
├── api/                      ← 接口封装（不用叫 services 也行）
├── hooks/
├── utils/
├── store/                    ← Zustand / 简单 Context
├── styles/
│   ├── reset.less
│   └── variables.less
├── App.tsx
└── main.tsx                  ← Vite 入口
```

**H5 关注点**：

- 首屏体积（路由懒加载 + Vant 按需引入）
- 适配（rem / vw）—— `postcss-pxtorem`
- 微信浏览器兼容（iOS WKWebView 坑多）
- 不要套 Umi（杀鸡用牛刀，构建慢）

---

## 5. Taro 跨端项目结构

```
src/
├── pages/
│   ├── index/
│   │   ├── index.tsx
│   │   ├── index.config.ts   ← 小程序页面配置（导航栏、tabBar）
│   │   └── index.less
├── components/
├── services/
├── store/
├── utils/
├── app.tsx                   ← 应用入口
├── app.config.ts             ← 全局配置（pages 列表、tabBar）
└── app.less
config/
├── index.ts
├── dev.ts
└── prod.ts
```

**Taro 关键约定**：

- 每个页面带 `.config.ts`（小程序原生约定）
- 用 `Taro.request` 或封装版，不能直接 `fetch`
- DOM API 不可用（小程序无 window / document）
- 样式单位用 `rpx` 或配置 `pxTransform`
- React 写法基本一致但**事件名要查 Taro 文档**（`onClick` → 小程序自动转 `bindtap`）

跨端兼容需写**条件编译**：

```typescript
if (process.env.TARO_ENV === 'weapp') {
  // 微信特有逻辑
} else if (process.env.TARO_ENV === 'h5') {
  // H5 特有逻辑
}
```

---

## 6. dva / @umijs/max model（国内中后台数据流核心）

Umi 4 + `@umijs/max` 内置 model 方案，是 dva 的简化版。**国内中后台数据流的绝对默认**。

```typescript
// src/models/user.ts
import { useState, useCallback } from 'react'

export default function useUserModel() {
  const [currentUser, setCurrentUser] = useState<API.User | null>(null)
  const [loading, setLoading] = useState(false)

  const fetchUser = useCallback(async () => {
    setLoading(true)
    try {
      const user = await services.getCurrentUser()
      setCurrentUser(user)
    } finally {
      setLoading(false)
    }
  }, [])

  return { currentUser, loading, fetchUser }
}
```

```typescript
// 任意组件消费
import { useModel } from '@umijs/max'

function Header() {
  const { currentUser, loading } = useModel('user')
  return <div>{currentUser?.name}</div>
}
```

**与传统 dva 的区别**：

- 不再需要写 `namespace / state / effects / reducers` 四件套
- model = 一个 hook，纯 React 心智
- 老 dva 项目可继续使用 `dva` 包，新项目直接用 `@umijs/max` model

**dva model 何时仍合理**：项目已存在大量 dva 代码、团队熟悉 redux-saga、需要严格的 action 审计日志。

---

## 7. Ant Design 实战要点

### 7.1 表单（国内 99% 用 AntD Form，react-hook-form 占比 < 5%）

```typescript
// ✅ 推荐：ProForm（中后台杀手锏）
import { ProForm, ProFormText, ProFormSelect } from '@ant-design/pro-components'

<ProForm
  onFinish={async (values) => {
    await services.createUser(values)
    message.success('提交成功')
    return true
  }}
>
  <ProFormText name="name" label="姓名" rules={[{ required: true }]} />
  <ProFormSelect
    name="role"
    label="角色"
    request={async () => services.getRoleOptions()}  // 远程加载
  />
</ProForm>
```

```typescript
// ✅ 普通 Form（C 端 / 复杂自定义）
const [form] = Form.useForm()

<Form form={form} layout="vertical" onFinish={onSubmit}>
  <Form.Item name="name" label="姓名" rules={[{ required: true, message: '请输入' }]}>
    <Input />
  </Form.Item>
</Form>
```

### 7.2 ProTable（中后台标配，省 80% 表格样板）

```typescript
<ProTable<API.User>
  columns={columns}
  request={async (params) => {
    // params 含 current / pageSize / 搜索字段
    const { data, total } = await services.queryUsers(params)
    return { data, total, success: true }
  }}
  rowKey="id"
  search={{ labelWidth: 'auto' }}
  toolBarRender={() => [<Button type="primary">新建</Button>]}
/>
```

ProTable 内置搜索表单、分页、列设置、密度切换、导出—— **国内中后台不上 ProTable 等于自虐**。

### 7.3 全局配置

```typescript
// app.tsx
import zhCN from 'antd/locale/zh_CN'
import { ConfigProvider } from 'antd'

export function rootContainer(container) {
  return <ConfigProvider locale={zhCN} theme={{ token: { colorPrimary: '#1677ff' } }}>{container}</ConfigProvider>
}
```

---

## 8. Custom Hooks（仍是核心模式，用国内场景举例）

国内项目常见 hooks：

```typescript
// 1. usePermission —— RBAC 权限判断（中后台高频）
export function usePermission() {
  const { initialState } = useModel('@@initialState')
  const access = initialState?.currentUser?.access ?? []

  return {
    can: (code: string) => access.includes(code),
    canAny: (codes: string[]) => codes.some(c => access.includes(c)),
  }
}

// 2. useUrlState —— 表格筛选条件同步到 URL（避免刷新丢状态）
import { useUrlState } from 'ahooks'

const [filter, setFilter] = useUrlState({ status: 'all', page: 1 })

// 3. useRequest（ahooks 出品，国内中后台请求事实标准）
import { useRequest } from 'ahooks'

const { data, loading, run, refresh } = useRequest(
  (id) => services.getUserDetail(id),
  { manual: true, debounceWait: 300 }
)
```

**ahooks**（阿里出品）国内使用率极高，包含 useRequest / useDebounce / useUrlState / useAntdTable 等 60+ hooks，**是国内 React 项目的瑞士军刀**，地位类似 lodash。

### 何时拆 Hook

| 场景 | 是否拆 |
|---|---|
| 多组件相同响应式逻辑 | ✅ 必须 |
| 单组件超 300 行 | ✅ 拆 |
| 涉及多 lifecycle 配合 | ✅ Hook 是唯一方式 |
| 纯计算（无 state / effect）| ❌ 放 `utils/` |
| 一次性逻辑不复用 | ❌ 直接写组件内 |

---

## 9. 状态管理决策矩阵（国内实战版）

```
状态种类：
├── 服务端数据（API 响应）
│   ├── 中后台 → ahooks useRequest / ProTable.request
│   └── 国外升级路径 → TanStack Query / SWR
├── 全局客户端（用户、主题、菜单、权限）
│   ├── 中后台 → @umijs/max model / dva
│   ├── H5 / Taro → Zustand（够轻）
│   └── 大型存量 → Redux Toolkit
├── 组件本地 / 表单 → useState / AntD Form
└── URL 状态 → useUrlState / 路由参数
```

**国内反模式**：

- 中后台不用 ProTable.request，自己写 `useEffect + setState` 管列表数据
- 全局态全塞 dva model，包括只有一个页面用到的临时态
- model 之间互相 import 形成环
- 用 Redux 但不用 RTK，写一堆 `actionType` 字符串常量

---

## 10. 设计模式（国内场景适配）

| 模式 | 状态 | 国内典型用法 |
|---|---|---|
| **Custom Hooks** | ✅ 核心 | 90% 复用场景；ahooks 是范本 |
| **Compound Components** | ✅ 仍有价值 | Ant Design 内部大量使用（Tabs / Form.Item / Select.Option）|
| **HOC** | ⚠️ 减少但仍见 | `withAuth` / dva 的 `connect()` |
| **Provider** | ✅ 慎用 | `ConfigProvider` / 主题；高频值禁用 |
| **Render Props** | ❌ 过时 | 被 hooks 取代 |
| **Container/Presenter** | ⚠️ 弱化 | 用 hooks 自然分层 |

### Compound Components 国内典型：ProTable Columns

```typescript
const columns: ProColumns<User>[] = [
  { title: '姓名', dataIndex: 'name', copyable: true },
  { title: '状态', dataIndex: 'status', valueType: 'select', valueEnum: { 0: '禁用', 1: '启用' } },
  {
    title: '操作',
    valueType: 'option',
    render: (_, record) => [
      <a key="edit" onClick={() => handleEdit(record)}>编辑</a>,
      <a key="del" onClick={() => handleDel(record)}>删除</a>,
    ],
  },
]
```

`valueType` + `valueEnum` 是 Pro Components 的"约定即配置"模式核心。

---

## 11. 反模式清单（按国内项目高频度排序）

| 反模式 | 频次 | 后果 |
|---|---|---|
| **dva model 过大**（单 model 上千行 / 50+ effects）| ★★★★★ | 改一处影响一片，无法热更新精确定位 |
| **AntD Form 嵌套 Form.List 超过 2 层** | ★★★★★ | 性能崩溃 + 验证逻辑写不出 |
| **Ant Design 二次封装失控**（封了个 `MyButton` 改了 50 个 props）| ★★★★☆ | 升级 AntD 一次炸全站 |
| **ProTable request 内做复杂数据 transform** | ★★★★☆ | 排序 / 分页参数错乱 |
| **services 文件按页面拆**（`pages/user/services.ts`）| ★★★★☆ | 接口复用困难，缓存 / mock 配置散乱 |
| **`useEffect` 链式依赖**（A 改 B，B 改 C，C 改 A）| ★★★★☆ | 死循环 / 难以追溯 |
| **dva connect 进所有组件**（不该拿全局态的也拿）| ★★★★ | 任何全局 state 变都触发大面积 re-render |
| **不用 ProForm / Form 自动校验，自己 setState 校验** | ★★★★ | 重复造轮子且不一致 |
| **服务端数据塞 dva**（自己手动缓存 + 失效逻辑）| ★★★ | 重复造 useRequest |
| **Class Component 与 Hooks 混用** | ★★★ | 团队习惯混乱，老项目重灾区 |
| **Context 管高频变化**（如鼠标位置 / 滚动位置）| ★★★ | 全树 re-render |
| **props drilling > 3 层** | ★★★ | 重构成本陡增 |
| **`key={index}` 列表** | ★★★ | reorder bug 经典案例 |
| **`useEffect` 没 cleanup** | ★★ | 内存泄漏 |
| **Redux 不用 RTK，原版 `createStore`** | ★★ | 样板地狱 |
| **跨页面直接 import `pages/xxx/components/Foo`** | ★★ | 路由解耦失败，重构难 |
| **`React.FC` 写新代码** | ★ | 影响泛型，被官方反推荐 |

---

## 12. 性能模式（国内中后台关注点）

| 场景 | 做法 |
|---|---|
| 大列表（>500 行）| 虚拟滚动（rc-virtual-list / ProTable 配置 `scroll.y`）|
| Form.List 长表单 | 拆子组件 + `React.memo`，避免整表单 re-render |
| 路由级懒加载 | Umi 自动 split + `dynamic()`；非 Umi 用 `lazy()` |
| AntD 按需加载 | Umi / Ant Design Pro 默认开启 babel-plugin-import |
| 图表 | AntV G2 按需引入；大数据量用 G2 + Web Worker |
| 防 re-render | `React.memo` + 稳定引用；ahooks `useMemoizedFn` |
| 静态资源 | 阿里云 OSS / 腾讯云 COS + CDN；不要直接 import 大图 |

**国内 React 19 Compiler 普及度低**，多数项目仍需手动 `useMemo / useCallback`。

---

## 13. SOLID 在 React 中（简版）

| 原则 | React 表现 |
|---|---|
| S 单一职责 | 一个组件一个职责；超 300 行拆 |
| O 开闭 | props 扩展 + slot-style children；ProComponents `fieldProps` 模式 |
| L 里氏替换 | 衍生组件应能替代基础组件 |
| I 接口隔离 | props 精确，不传 `Record<string, any>` |
| D 依赖反转 | 组件依赖 props / hooks，不直接 import 具体 model |

---

## 14. 国外栈降级 / 升级路径参考

> 国内项目何时考虑切到国外栈（Bulletproof + Zustand + TanStack）？

**适合切换**：

- 全新长期项目、团队有 React 老兵
- 国际化部署、海外用户为主
- 强类型安全要求（TanStack Router 类型化路由优势明显）
- 跳出 Ant Design 视觉风格（C 端品牌定制）

**不要切换**：

- 中后台 + Ant Design 设计稿（切走没收益）
- 团队主力是后端兼前端 / 初学者（Umi 文档中文齐全）
- 项目周期短（< 3 个月）
- 需要 ProTable / ProForm 这种业务级组件（自己拼成本极高）

**渐进升级**：在 Umi 项目里**逐步引入** TanStack Query 替代 dva 中的服务端数据部分，是国内常见的现代化中庸路径。

---

## 15. 大厂前端规约对 React 的态度（概览）

| 厂 | 主推 | 备注 |
|---|---|---|
| 阿里 | **Umi + Ant Design + dva/RTK** | Ant Design 出自蚂蚁，事实标准 |
| 字节 | **Modern.js**（自研全栈框架）+ Semi Design | Arco 维护停滞，内部转 Semi |
| 腾讯 | TDesign + 自由选型 | 各 BG 自治，无统一栈 |
| 京东 | **Taro**（自家开源）+ NutUI | 小程序业务为主 |
| 百度 | 内部自研 + Ant Design Pro | 中后台主流 |
| 美团 | Mtfe（内部）+ Ant Design | 内部框架严格规约 |

**实战结论**：除非进特定大厂用其内部栈，**社招市场最通用的还是 Umi + Ant Design Pro**。

---

## 16. React 19 在国内的现状

- 普及度低，2026 Q1 国内新项目用 React 19 的不到 20%
- 主要阻碍：Ant Design 5 部分组件对 React 19 strict mode 兼容仍在跟进、企业项目对升级保守
- **新 API 实际用得最多的是 `use(promise)`**，其次 `useActionState`
- React Compiler 几乎没人开（生态适配不全）
- 老项目以 React 17 / 18 为主，dva / Umi 3 在维护期

```typescript
// React 19 新 API（国内项目可选）
const value = use(promise)                              // ✅ 用得到
const [error, action, pending] = useActionState(...)   // ⚠️ AntD Form 已覆盖此场景
const [optimistic, addOptimistic] = useOptimistic(...) // ⚠️ 小众
```

如果项目仍是 React 18，不必为了用新 API 而升。

---

## 17. 权威信息源

国内主流：

- [UmiJS 官方](https://umijs.org/) —— 阿里 React 应用框架
- [Ant Design](https://ant.design/) —— 国内中后台 UI 事实标准
- [Ant Design Pro](https://pro.ant.design/) —— 中后台脚手架
- [Pro Components](https://procomponents.ant.design/) —— ProTable / ProForm 等
- [ahooks](https://ahooks.js.org/) —— 阿里 React Hooks 库
- [Taro](https://taro.zone/) —— 京东跨端
- [AntV](https://antv.antgroup.com/) —— 蚂蚁数据可视化
- [Semi Design](https://semi.design/) —— 字节抖音前端组件库

国外参考（升级路径）：

- [Bulletproof-React](https://github.com/alan2207/bulletproof-react) —— 本目录 `bulletproof-react.md` 即是 fork
- [React 官方文档](https://react.dev/)
- [TanStack Router / Query](https://tanstack.com/)
- [Zustand](https://github.com/pmndrs/zustand)

---

## 18. 一句话总结

**国内 React = 中后台 React = Umi + Ant Design Pro + Pro Components + dva/Max model + ahooks**。不熟这套就接不了国内项目。Bulletproof / Zustand / TanStack 是好东西，但**先把国内主流跑通再谈升级**。
