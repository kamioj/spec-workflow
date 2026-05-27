---
name: Bulletproof-React 架构参考（fork）
source: https://github.com/alan2207/bulletproof-react
note: 内容从官方 docs/ 抓取整理，companion: react-patterns.md（自写工程化决策与设计模式）
---

# Bulletproof-React 架构参考

> 来源：https://github.com/alan2207/bulletproof-react
> 整理日期：2026-05-16

---

## 一、项目概述

Bulletproof-React 是一个团队协作讨论平台演示，核心价值在于**示范生产级 React 架构**。

**四个核心数据模型**：User / Team / Discussion / Comment

**权限体系**：
- `ADMIN`：可管理讨论、评论和用户，编辑个人资料
- `USER`：仅可编辑自身评论和个人资料

**支持三种部署形态**：React Vite、Next.js App Router、Next.js Pages Router——各应用目录均有独立 README。

---

## 二、项目结构 ★ 核心章节

### 2.1 src 顶层目录树

```
src/
├── app/            # 应用入口层：路由、Provider、主组件、router 配置
├── assets/         # 静态资源（图片、字体）
├── components/     # 跨功能共享组件
├── config/         # 全局配置、环境变量导出
├── features/       # 功能模块（核心组织单元）★
├── hooks/          # 跨应用共享 hooks
├── lib/            # 预配置的可复用第三方库封装
├── stores/         # 全局状态管理
├── testing/        # 测试工具与 mock 数据
├── types/          # 跨应用共享 TypeScript 类型
└── utils/          # 共享工具函数
```

### 2.2 单个 feature 内部结构

```
src/features/awesome-feature/
├── api/            # 该功能的 API 请求声明与 react-query hooks
├── assets/         # 该功能的静态资源
├── components/     # 该功能专属组件
├── hooks/          # 该功能专属 hooks
├── stores/         # 该功能的状态 store
├── types/          # 该功能的 TypeScript 类型
├── utils/          # 该功能的工具函数
└── index.ts        # 公开 API 入口（Public API）★
```

> 原则：**只保留必要的子文件夹**，不要过度设计。废弃一个功能时，只需删除对应的 `features/xxx` 目录。

### 2.3 三大架构原则

**① 单向代码流（Unidirectional Flow）**

```
shared（components/hooks/utils）
    ↓
features（功能模块）
    ↓
app（路由/Provider 层）
```

禁止反向依赖，禁止平级 feature 互相导入。

**② 禁止跨 feature 导入**

feature 之间不得互相 import，需要组合时在 `app` 层完成。

**③ 禁用 Barrel 文件（index 桶式导出）**

直接 import 具体文件路径，而非通过 `index.ts` 统一 re-export。原因是 Vite tree-shaking 对 barrel 文件支持不好，影响构建性能。

> 例外：每个 feature 的根 `index.ts` 作为对外公开 API，仅暴露需要被外部使用的内容。

### 2.4 ESLint 强制边界

**方案 A：`no-restricted-imports`（推荐，简洁）**

```javascript
// .eslintrc.js
'no-restricted-imports': [
  'error',
  {
    patterns: ['@/features/*/*'],  // 禁止直接 import feature 内部文件，必须通过 index.ts
  },
]
```

**方案 B：`import/no-restricted-paths`（更细粒度）**

```javascript
'import/no-restricted-paths': [
  'error',
  {
    zones: [
      { target: './src/features/auth',        from: './src/features', except: ['./auth'] },
      { target: './src/features/comments',    from: './src/features', except: ['./comments'] },
      { target: './src/features/discussions', from: './src/features', except: ['./discussions'] },
      { target: './src/features/teams',       from: './src/features', except: ['./teams'] },
      { target: './src/features/users',       from: './src/features', except: ['./users'] },
      // 强制单向流：shared 不能 import features/app
      { target: './src/components',           from: ['./src/features', './src/app'] },
      { target: './src/hooks',                from: ['./src/features', './src/app'] },
      { target: './src/lib',                  from: ['./src/features', './src/app'] },
    ],
  },
]
```

---

## 三、组件与样式

**核心原则**：状态、组件、样式就近放置，不要过早提升层级。

```typescript
// ❌ 错误：在大组件里写嵌套渲染函数
function Component() {
  function Items() { return <ul>...</ul>; }   // ← 每次渲染重新创建
  return <div><Items /></div>;
}

// ✅ 正确：提取为独立组件
function Items() { return <ul>...</ul>; }
function Component() { return <div><Items /></div>; }
```

**反腐层（Anti-Corruption Layer）**：封装第三方组件，隔离上游 breaking change：

```typescript
import { Link as RouterLink, LinkProps } from 'react-router-dom';

export const Link = ({ className, children, ...props }: LinkProps) => (
  <RouterLink className={`text-indigo-600 hover:text-indigo-900 ${className}`} {...props}>
    {children}
  </RouterLink>
);
```

**组件库选型参考**：

- 快速原型：Chakra UI / MUI / Mantine（全功能型）
- 自定义设计系统：Radix UI / Headless UI（无头组件）
- 折中方案：ShadCN UI / Park UI（可定制预构建）

**开发工具**：用 Storybook 作组件目录，隔离开发，便于发现和复用。

---

## 四、API 层

**单一客户端实例**：全局维护一个预配置的 API client（fetch / axios / apollo-client），不在各处各自初始化。

**每个 API 声明包含三要素**：

```typescript
// src/features/discussions/api/get-discussions.ts
import { api } from '@/lib/api-client';
import { useQuery } from '@tanstack/react-query';
import { Discussion } from '../types';

// 1. 类型 + 验证 schema
// 2. 请求函数
export const getDiscussions = (): Promise<Discussion[]> =>
  api.get('/discussions');

// 3. react-query hook
export const useDiscussions = () =>
  useQuery({ queryKey: ['discussions'], queryFn: getDiscussions });
```

优势：端点集中可查，类型推断增强安全性，逻辑全部在一处。

---

## 五、状态管理

状态分五类，各自用合适工具：

| 类别 | 工具 |
|---|---|
| 组件状态（简单） | `useState` |
| 组件状态（复杂） | `useReducer` |
| 应用全局状态 | Context + Hooks / Zustand / Jotai / Redux Toolkit |
| 服务器缓存 | React Query / SWR / Apollo Client / RTK Query |
| 表单状态 | React Hook Form / Formik，配合 Zod/Yup 验证 |
| URL 状态 | react-router-dom（路由参数 + query string） |

**核心原则**：

- 状态尽量本地化，必要时才提升
- 服务器数据**不要**放进 Redux，交给专用缓存库
- 创建抽象的 Form 组件和 Input 组件，避免重复配置

---

## 六、错误处理

**三层防线**：

1. **API 拦截器**：统一处理 401（登出/刷新 token）、网络错误触发通知
   - 参考实现：`apps/react-vite/src/lib/api-client.ts`

2. **React 错误边界**：在不同区域放置**多个**边界（非单一全局），实现局部隔离
   - 参考实现：`apps/react-vite/src/app/routes/app/discussions/discussion.tsx`

3. **生产监控**：接入 Sentry，上传 source map，精确定位源码位置，获取平台/浏览器等上下文

---

## 七、测试策略

**优先级**：集成测试 > 端到端测试 > 单元测试

> 原文：「集成测试和端到端测试的全面覆盖，才能提供真正的应用功能信心」

**工具栈**：

| 工具 | 用途 |
|---|---|
| Vitest | 测试框架（比 Jest 更轻量，Vite 原生支持） |
| Testing Library | 模拟真实用户行为编写测试，重构后仍有效 |
| Playwright | 浏览器 E2E 自动化（支持 headless 模式） |
| MSW（Mock Service Worker） | 在 Service Worker 层 mock API，可先设计接口再等后端 |

**实践建议**：

- 大部分精力投入集成测试，验证模块间协作
- 用 MSW mock 原型化 API 设计，而非硬编码响应数据
- 测试按真实用户使用方式编写，不依赖实现细节

---

## 总评

Bulletproof-React 用**功能模块化 + 单向依赖 + ESLint 强制边界**三板斧，将大型 React 项目的混乱度控制在可预测范围内，是目前开源社区对"可扩展前端架构"描述最具体、最可直接落地的参考实现。

## 信息源

- [bulletproof-react GitHub](https://github.com/alan2207/bulletproof-react)
- [project-structure.md](https://github.com/alan2207/bulletproof-react/blob/master/docs/project-structure.md)
- [其余 docs/* 文档](https://github.com/alan2207/bulletproof-react/tree/master/docs)
