---
name: Bulletproof-React Architecture Reference (fork)
source: https://github.com/alan2207/bulletproof-react
note: Content extracted and organized from the official docs/. Companion file: react-patterns.md (hand-written engineering decisions and design patterns).
---
<!-- GENERATED from core/references/bulletproof-react.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# Bulletproof-React Architecture Reference

> Source: https://github.com/alan2207/bulletproof-react
> Compiled: 2026-05-16

---

## 1. Project Overview

Bulletproof-React is a team collaboration and discussion platform demo. Its core value lies in **demonstrating production-grade React architecture**.

**Four core data models**: User / Team / Discussion / Comment

**Permission system**:
- `ADMIN`: can manage discussions, comments, and users; can edit their own profile
- `USER`: can only edit their own comments and profile

**Three supported deployment targets**: React Vite, Next.js App Router, Next.js Pages Router — each app directory has its own README.

---

## 2. Project Structure ★ Core Section

### 2.1 Top-level `src` directory tree

```
src/
├── app/            # Application entry layer: routing, providers, root component, router config
├── assets/         # Static assets (images, fonts)
├── components/     # Shared components used across features
├── config/         # Global configuration and environment variable exports
├── features/       # Feature modules (the primary organizational unit) ★
├── hooks/          # Shared hooks used across the application
├── lib/            # Pre-configured, reusable wrappers around third-party libraries
├── stores/         # Global state management
├── testing/        # Test utilities and mock data
├── types/          # Shared TypeScript types used across the application
└── utils/          # Shared utility functions
```

### 2.2 Internal structure of a single feature

```
src/features/awesome-feature/
├── api/            # API request declarations and react-query hooks for this feature
├── assets/         # Static assets for this feature
├── components/     # Components scoped to this feature
├── hooks/          # Hooks scoped to this feature
├── stores/         # State stores for this feature
├── types/          # TypeScript types for this feature
├── utils/          # Utility functions for this feature
└── index.ts        # Public API entry point ★
```

> Principle: **only create subdirectories you actually need** — don't over-engineer the structure. To remove a feature, simply delete its `features/xxx` directory.

### 2.3 Three core architectural principles

**① Unidirectional Code Flow**

```
shared (components / hooks / utils)
    ↓
features (feature modules)
    ↓
app (routing / provider layer)
```

Reverse dependencies are NEVER allowed. Cross-feature imports at the same level are NEVER allowed.

**② No cross-feature imports**

Features MUST NOT import from one another. When composition is needed, wire things together in the `app` layer.

**③ No barrel files (index re-export patterns)**

Import from the specific file path directly rather than re-exporting everything through `index.ts`. The reason: Vite's tree-shaking has poor support for barrel files, which hurts build performance.

> Exception: each feature's root `index.ts` serves as its public API — it MUST only expose what external consumers need.

### 2.4 ESLint-enforced boundaries

**Option A: `no-restricted-imports` (recommended — simple)**

```javascript
// .eslintrc.js
'no-restricted-imports': [
  'error',
  {
    patterns: ['@/features/*/*'],  // Prevent importing feature internals directly; must go through index.ts
  },
]
```

**Option B: `import/no-restricted-paths` (finer-grained)**

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
      // Enforce unidirectional flow: shared layers MUST NOT import from features or app
      { target: './src/components',           from: ['./src/features', './src/app'] },
      { target: './src/hooks',                from: ['./src/features', './src/app'] },
      { target: './src/lib',                  from: ['./src/features', './src/app'] },
    ],
  },
]
```

---

## 3. Components and Styling

**Core principle**: keep state, components, and styles close to where they are used — don't lift them prematurely.

```typescript
// ❌ Wrong: nested render functions inside a large component
function Component() {
  function Items() { return <ul>...</ul>; }   // ← recreated on every render
  return <div><Items /></div>;
}

// ✅ Correct: extract as a standalone component
function Items() { return <ul>...</ul>; }
function Component() { return <div><Items /></div>; }
```

**Anti-Corruption Layer**: wrap third-party components to isolate yourself from upstream breaking changes:

```typescript
import { Link as RouterLink, LinkProps } from 'react-router-dom';

export const Link = ({ className, children, ...props }: LinkProps) => (
  <RouterLink className={`text-indigo-600 hover:text-indigo-900 ${className}`} {...props}>
    {children}
  </RouterLink>
);
```

**Component library options**:

- Rapid prototyping: Chakra UI / MUI / Mantine (full-featured)
- Custom design systems: Radix UI / Headless UI (headless components)
- Middle ground: ShadCN UI / Park UI (customizable pre-built)

**Tooling**: use Storybook as a component catalog to develop components in isolation and make them easy to discover and reuse.

---

## 4. API Layer

**Single client instance**: maintain one pre-configured API client globally (fetch / axios / apollo-client) — NEVER initialize separate clients in different parts of the app.

**Each API declaration MUST include three elements**:

```typescript
// src/features/discussions/api/get-discussions.ts
import { api } from '@/lib/api-client';
import { useQuery } from '@tanstack/react-query';
import { Discussion } from '../types';

// 1. Types + validation schema
// 2. Request function
export const getDiscussions = (): Promise<Discussion[]> =>
  api.get('/discussions');

// 3. react-query hook
export const useDiscussions = () =>
  useQuery({ queryKey: ['discussions'], queryFn: getDiscussions });
```

Benefits: all endpoints are centralized and easy to find; type inference improves safety; all related logic lives in one place.

---

## 5. State Management

State falls into five categories, each handled by the appropriate tool:

| Category | Tool |
|---|---|
| Component state (simple) | `useState` |
| Component state (complex) | `useReducer` |
| Application-wide global state | Context + Hooks / Zustand / Jotai / Redux Toolkit |
| Server cache | React Query / SWR / Apollo Client / RTK Query |
| Form state | React Hook Form / Formik, paired with Zod/Yup for validation |
| URL state | react-router-dom (route params + query strings) |

**Core principles**:

- Keep state as local as possible; only lift it when necessary
- Server data MUST NOT go into Redux — hand it off to a dedicated caching library
- Create abstract Form and Input components to avoid repetitive configuration

---

## 6. Error Handling

**Three layers of defense**:

1. **API interceptor**: centrally handles 401s (sign out / token refresh) and triggers notifications on network errors
   - Reference implementation: `apps/react-vite/src/lib/api-client.ts`

2. **React Error Boundaries**: place **multiple** boundaries in different regions (not a single global one) for localized fault isolation
   - Reference implementation: `apps/react-vite/src/app/routes/app/discussions/discussion.tsx`

3. **Production monitoring**: integrate Sentry, upload source maps for precise stack traces pointing to original source, and capture platform/browser context

---

## 7. Testing Strategy

**Priority order**: integration tests > end-to-end tests > unit tests

> From the source: "Comprehensive integration and end-to-end test coverage is what gives you real confidence that the application works."

**Toolchain**:

| Tool | Purpose |
|---|---|
| Vitest | Test runner (lighter than Jest, native Vite support) |
| Testing Library | Write tests that simulate real user interactions; remains valid after refactors |
| Playwright | Browser-based E2E automation (supports headless mode) |
| MSW (Mock Service Worker) | Mock APIs at the Service Worker level; design the interface before the backend is ready |

**Practical recommendations**:

- Invest the majority of testing effort in integration tests that verify how modules work together
- Use MSW to prototype API designs rather than hard-coding response fixtures
- Write tests from the perspective of a real user — avoid coupling to implementation details

---

## Summary

Bulletproof-React combines **feature-based modularization**, **unidirectional dependency flow**, and **ESLint-enforced boundaries** to keep large React applications predictably organized. It is currently the most concrete, immediately actionable open-source reference for scalable frontend architecture.

## Sources

- [bulletproof-react GitHub](https://github.com/alan2207/bulletproof-react)
- [project-structure.md](https://github.com/alan2207/bulletproof-react/blob/master/docs/project-structure.md)
- [Other docs/* documentation](https://github.com/alan2207/bulletproof-react/tree/master/docs)
