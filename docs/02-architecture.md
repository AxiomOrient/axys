# 02. Architecture

## 1. 전체 구조

```text
┌─────────────────────────────────────────┐
│ screen-doc (*.md)                       │
│ - 인간이 쓴 의도 / 제약 / 상태 / 구성요소 │
└─────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│ screen-spec (*.screen.json)             │
│ - authoritative machine contract        │
└─────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│ validator                               │
│ - catalog check                         │
│ - token alias check                     │
│ - structure check                       │
└─────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│ generators                              │
│ - SwiftUI                               │
│ - Jetpack Compose                       │
│ - HTML preview                          │
└─────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│ outputs                                 │
│ - build/<screen>/ios                    │
│ - build/<screen>/android                │
│ - build/<screen>/html                   │
│ - build/<screen>/manifest + reports     │
└─────────────────────────────────────────┘
```

## 2. 주요 서브시스템

### 2.1 Contract Layer
- ScreenSpec
- ComponentCatalog
- dsctl config
- token set

### 2.2 Core Layer
- doc loader
- spec loader
- token resolver
- validator
- artifact generators

### 2.3 Interface Layer
- CLI (`dsctl`)
- MCP (`ds-mcp`)

### 2.4 Output Layer
- `build/<screen>/ios/*`
- `build/<screen>/android/*`
- `build/<screen>/html/*`
- manifest / validation reports

## 3. Source-of-Truth Hierarchy

우선순위는 아래다.

```text
ScreenDoc      → 사람의 의도
ScreenSpec     → 기계 계약 (최고 우선)
TokenSet       → 디자인 값
Catalog        → 허용 vocabulary
GeneratedCode  → 파생 산출물
```

## 4. Shared vs Native

### 공유되는 것
- intent
- contract
- token values
- validation policy

### 공유하지 않는 것
- runtime widget tree
- navigation runtime
- platform-specific state objects
- platform-specific styling APIs

## 5. Why not shared runtime UI

shared runtime UI는 겉으로는 단순해 보이지만, 다음 비용이 생긴다.

- native fidelity 저하
- platform-specific behavior abstraction 비용
- 디버깅 책임 증가
- design system drift

이 프로젝트는 공유 런타임 대신 **공유 계약**을 택한다.
