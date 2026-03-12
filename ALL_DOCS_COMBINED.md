# README.md

# Mobile Design Automation

이 저장소는 **모바일 네이티브 디자인 자동화 시스템**의 실제 Swift 구현과 문서 계약을 함께 가진 기준 저장소다. `docs/`, `schemas/`, `examples/`, `prompts/`는 source package로 유지하고, 실행 코드는 `Sources/DSCore`, `Sources/DSCLI`, `Sources/DSMCP`, `Sources/DSMCPKit`에 둔다.

핵심 파이프라인은 하나로 고정한다.

```text
screen-doc -> ScreenSpec -> validate -> generate -> SwiftUI / Compose / HTML preview
```

## 포함 범위

- 최종 아키텍처와 기술 선택
- source of truth / contract / schema 정의
- target repo 구조와 module map
- CLI / MCP / generator / review 정책
- 실행 계획과 task matrix
- 품질 게이트, traceability, integrity audit
- screen-doc, ScreenSpec, token, catalog, config examples
- agent prompt와 repo-local `AGENTS.md`

## 권장 읽기 순서

1. [MASTER_BLUEPRINT.md](MASTER_BLUEPRINT.md)
2. [00-executive-decision.md](docs/00-executive-decision.md)
3. [01-goals-non-goals.md](docs/01-goals-non-goals.md)
4. [02-architecture.md](docs/02-architecture.md)
5. [03-source-of-truth-and-contracts.md](docs/03-source-of-truth-and-contracts.md)
6. [04-tech-stack-decision.md](docs/04-tech-stack-decision.md)
7. [07-cli-and-mcp-spec.md](docs/07-cli-and-mcp-spec.md)
8. [11-execution-plan.md](docs/11-execution-plan.md)
9. [12-task-matrix.md](docs/12-task-matrix.md)
10. [20-traceability-matrix.md](docs/20-traceability-matrix.md)
11. [21-integrity-audit.md](docs/21-integrity-audit.md)

## 현재 패키지와 목표 상태

- 실행 코드는 SwiftPM package로 동작한다.
- 실제 모듈 책임은 [05-repo-structure-and-naming.md](docs/05-repo-structure-and-naming.md), [19-code-module-map.md](docs/19-code-module-map.md)에 정리한다.
- 구현과 검증은 [11-execution-plan.md](docs/11-execution-plan.md)의 critical path와 [12-task-matrix.md](docs/12-task-matrix.md)의 stable task ID를 기준으로 진행한다.

## 빠른 시작

```bash
swift build
swift test

./.build/debug/dsctl validate \
  --config examples/configs/dsctl.config.json \
  --screen-id login \
  --json

./.build/debug/dsctl validate \
  --config examples/configs/dsctl.config.json \
  --screen-doc examples/screen-doc/login.md \
  --json

./.build/debug/dsctl compile-screen-doc \
  --config examples/configs/dsctl.config.json \
  --screen-id login \
  --json

./.build/debug/dsctl generate \
  --config examples/configs/dsctl.config.json \
  --screen-id login \
  --json

./.build/debug/dsctl generate \
  --config examples/configs/dsctl.config.json \
  --screen-doc examples/screen-doc/login.md \
  --out build/from-screen-doc/login \
  --json

./.build/debug/dsctl generate-bundle \
  --config examples/configs/dsctl.config.json \
  --screen-doc-dir examples/screen-doc \
  --out build/from-screen-doc/bundle \
  --json

./.build/debug/ds-doc-sync export-contracts \
  --project-root . \
  --json

./.build/debug/ds-doc-sync sync \
  --project-root . \
  --json
```

`ds-doc-sync sync` 는 `export-contracts -> export-fragments -> render -> verify` 를 순서대로 수행하는 full doc-sync entrypoint 다.

## 한 줄 정의

이 시스템은 문서를 직접 UI 코드로 번역하는 것이 아니라, 문서를 구조화된 계약(ScreenSpec)으로 정규화한 뒤 결정론적으로 네이티브 UI 코드를 생성하는 시스템이다.


# MASTER_BLUEPRINT.md

# Master Blueprint

기준일: 2026-03-11

## 1. 최종 결정

이 프로젝트의 핵심 파이프라인은 아래로 고정한다.

```text
screen-doc (markdown)
    -> starter screen-spec
    -> complete screen-spec
    -> validate
    -> generate
    -> review
    -> integrate
    -> ios/swiftui
    -> android/compose
    -> html/preview
```

## 2. 최종 완성 목표

이 저장소는 “가능한 기능을 모두 넣는 시스템”이 아니라,
**핵심기능이 실제로 정확하게 돌아가는 완성형 delivery system** 을 목표로 한다.

완성 기준의 핵심기능은 아래 여섯 가지다.

1. `screen-doc` 에서 starter spec을 만들고 authoritative `ScreenSpec` 으로 완성시키는 authoring path
2. 상태, 액션, 네비게이션, asset, preview state를 명시적으로 담는 `ScreenSpec`
3. unresolved/ambiguous semantics를 generation 전에 차단하는 semantic validation
4. SwiftUI / Compose / HTML이 같은 의미를 유지하는 deterministic generation
5. declared preview state 전체를 보여주는 HTML review path
6. generated adapter만으로 host app에 연결되는 integration path

## 3. 최종 기술 선택

```text
Control plane language : Swift 6
Build tool             : Swift Package Manager
CLI                    : dsctl
Doc sync binary        : ds-doc-sync
MCP server             : ds-mcp
iOS target             : SwiftUI source generation
Android target         : Jetpack Compose source generation
Preview target         : Static HTML
Tests                  : XCTest
Contract format        : JSON + Markdown + contract roots
Token format           : DTCG-style JSON
```

## 4. 왜 이렇게 결정했는가

### 4.1 Swift를 고른 이유
- macOS 기본 환경과 가장 잘 맞는다.
- iOS 출력과 문맥 거리가 짧다.
- control plane과 iOS renderer 설계를 한 언어로 통일할 수 있다.
- MCP 공식 Swift SDK가 존재한다.
- CLI 구현에 Swift Package Manager + ArgumentParser 조합이 자연스럽다.

### 4.2 Rust를 고르지 않은 이유
- 현재 프로젝트의 최대 병목은 실행 속도보다 계약 정밀도와 흐름 단순화다.
- iOS 중심 팀에 추가 toolchain 부담이 생긴다.
- Kotlin/Swift 코드를 모두 문자열 또는 구조화된 emission으로 생성해야 하므로 Rust가 본질적인 단순화를 보장하지 않는다.

### 4.3 HTML preview를 기본 review path로 둔 이유
- Xcode / Android Studio 없이 바로 확인 가능하다.
- static artifact로 남길 수 있다.
- CLI/MCP에서 생성·서빙하기 쉽다.
- review와 host integration 사이의 의미 parity를 가장 빨리 검증할 수 있다.

## 5. source of truth

제품 계약과 운영 계약은 아래 입력 집합으로 닫는다.

```text
1. docs/                  - 정책, 아키텍처, execution contract
2. examples/screen-doc    - 사람의 의도
3. examples/screens       - authoritative ScreenSpec contract
4. examples/tokens        - 시각 값(tokens)
5. examples/catalogs      - 허용 vocabulary
6. examples/configs       - project path / default platform 설정
7. meta/runtime           - CLI/MCP/doc-sync runtime contract
8. meta/governance        - governance / evidence contract
9. meta/views             - planning / traceability / generated-doc source
```

생성물은 모두 disposable이다.

```text
generated code / preview / snapshots / manifests / reports / exported views
```

## 6. 현재 베이스라인

- 저장소는 이미 `dsctl`, `ds-doc-sync`, `ds-mcp` executable target을 가진 SwiftPM package로 동작한다.
- `login`, `product-detail` 예시는 compile / validate / generate / audit baseline을 제공한다.
- `11`, `12`, `20` 의 structured section은 `meta/views/*` source와 doc-sync 경로로 동기화된다.
- 활성 completion ledger는 `docs/11-execution-plan.md`, `docs/12-task-matrix.md`, `docs/20-traceability-matrix.md` 에서 관리하고, `24`, `25` 는 authoritative-source annex로 사용한다.

## 7. 에이전트 운용 원칙

- 에이전트는 ScreenSpec과 upstream contract를 생성하거나 수정한다.
- 생성된 SwiftUI / Compose / HTML 파일을 사람이 직접 수정하지 않는다.
- 수정은 반드시 upstream에서 일어난다.
- `validate -> generate -> review -> integrate` 순서를 강제한다.
- starter spec을 final authoritative spec으로 착각하지 않는다.

## 8. 이 문서 패키지의 사용 목적

이 문서 패키지는 다른 에이전트나 다른 개발자가 아래를 끝까지 수행할 수 있게 만드는 것이 목적이다.

1. 프로젝트 방향과 핵심기능 계약 이해
2. compile / validate / generate / review 흐름 완성
3. CLI / MCP / doc-sync / audit 운영 계약 정렬
4. iOS / Android host integration path 설계
5. traceability와 acceptance evidence 관리


# AGENTS.md

# AGENTS.md

## Source of truth
1. `examples/screen-doc/*.md` are the human-authored intent documents.
2. `examples/screens/*.screen.json` are the authoritative machine contracts.
3. `examples/tokens/*.json` hold the design values.
4. Generated outputs are disposable artifacts, not editable sources.

## Mandatory workflow
1. Read `MASTER_BLUEPRINT.md`.
2. Read `examples/catalogs/component-catalog.json`.
3. Read the target `screen-doc`.
4. Create or update exactly one `screen-spec`.
5. Run validation before generation.
6. Generate HTML, SwiftUI, and Compose artifacts.
7. Review the HTML preview first.
8. Fix upstream inputs only.

## Hard constraints
- Do not edit generated SwiftUI, Compose, or HTML files by hand.
- Do not use raw color or spacing literals inside `ScreenSpec`.
- Do not introduce components outside the catalog.
- Keep one `ScreenSpec` focused on one primary intent.


# docs/00-executive-decision.md

# 00. Executive Decision

## 최종 의사결정 요약

이 프로젝트는 **모바일 디자인 자동화 시스템**이다.
목표는 **문서 기반 설계 의도를 구조화된 계약(ScreenSpec)으로 변환하고**, 이 계약에서 **iOS / Android / HTML**을 자동 생성하는 것이다.

## 최종 선택

### 선택
- Swift control plane
- Swift Package Manager
- CLI-first interface
- MCP thin adapter
- ScreenSpec as authoritative contract
- DTCG-style tokens
- Native renderers (SwiftUI / Compose)
- Static HTML preview

### 비선택
- Rust control plane (v1)
- shared runtime UI
- server-driven UI
- design tool file as source of truth
- direct Figma/Penpot/Pencil to production code path

## 결정 기준

의사결정은 아래 기준으로 했다.

1. **단순성**
2. **재현 가능성**
3. **에이전트 자동화 적합성**
4. **네이티브 정확도**
5. **운영 복잡도 최소화**

## 핵심 판단

이 시스템은 **디자인 툴 자동화**가 아니다.
정확히는 **디자인 의도 자동 정규화 + UI 코드 자동 생성** 시스템이다.

즉, 문제의 중심은 canvas가 아니라 **contract**다.

## 도식

```text
screen-doc
  ↓ normalize
screen-spec
  ↓ validate
generator
  ↓
swiftui / compose / html
```


# docs/01-goals-non-goals.md

# 01. Goals and Non-Goals

## 1. Primary Goal

디자인 문서에서 **한 번에 신뢰할 수 있는 하나의 결과**를 만들 수 있는 자동화 시스템을 설계하고 구현한다.

## 2. Success Criteria

다음 조건을 만족해야 한다.

### 2.1 정확성
- 같은 입력은 같은 출력을 만든다.
- 잘못된 ScreenSpec은 생성 전에 차단한다.
- design tokens와 component catalog를 벗어난 출력이 나오지 않는다.

### 2.2 단순성
- 코어 파이프라인은 한 줄로 설명 가능해야 한다.
- source of truth는 최소화해야 한다.
- 신규 팀원이 1일 안에 이해 가능해야 한다.

### 2.3 실용성
- 에이전트가 CLI로 전 과정을 수행할 수 있어야 한다.
- 결과를 사람이 HTML로 바로 볼 수 있어야 한다.
- 네이티브 결과를 host app에 쉽게 통합할 수 있어야 한다.

### 2.4 확장성
- iOS와 Android를 둘 다 지원해야 한다.
- 새로운 screen type / component / token은 contract 확장으로 수용해야 한다.
- Penpot / Pencil 같은 외부 preview adapter를 붙일 수 있어야 한다.

## 3. Explicit Non-Goals

### 3.1 v1에서 하지 않는 것
- runtime server-driven UI
- Flutter / React Native / Compose Multiplatform UI 공유
- visual editor를 authoritative source로 사용하는 것
- design token SaaS 의존
- multi-tenant web service
- production-ready collaborative editor
- animation authoring engine
- AI가 직접 네이티브 화면 코드를 자유 생성하는 것

### 3.2 왜 하지 않는가
이들은 유용하지만, 현재의 핵심 목표인 **단순하고 확실한 결과 생성**에 직접적으로 기여하지 않는다.

## 4. Product Statement

> 이 시스템은 “디자인 문서에서 네이티브 UI를 자동 생성하는 deterministic design compiler”다.


# docs/02-architecture.md

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


# docs/03-source-of-truth-and-contracts.md

# 03. Source of Truth and Contracts

## 1. Human-authored artifacts

### 1.1 screen-doc
사람이 작성하는 문서다.
의도, 제약, 상태, 핵심 구성요소만 가진다.

예:
```md
---
screenId: login
intent: quiet single-column login
platforms: [ios, android, html]
---
Use one title, two fields, one primary action.
```

### 1.2 token set
semantic design values다.
raw values를 모아두고 alias를 통해 재사용한다.

예:
```json
{
  "color": {
    "surface": {
      "primary": { "$type": "color", "$value": "#FFFFFF" }
    }
  }
}
```

### 1.3 component catalog
허용되는 component vocabulary와 role / variant / inputType 제한을 정의한다.

### 1.4 dsctl config
project root, input path, 기본 platform 같은 실행 경로 설정을 가진다.

## 2. Machine-authored authoritative artifact

### 2.1 ScreenSpec
ScreenSpec은 build input의 중심이다.

반드시 포함해야 하는 것:
- schemaVersion
- screenId
- title
- platforms
- surface
- root

`platforms` 는 단순 메타데이터가 아니라 실제 artifact emission 범위를 결정한다.

현재 interaction contract slice에서 `ScreenSpec` 은 아래를 명시적으로 가질 수 있다.
- `stateFields`: host와 generator가 공유하는 상태 필드 선언
- `actions`: host와 generator가 공유하는 action surface 선언
- `navigation`: host와 generator가 공유하는 destination registry
- `assets`: media node가 참조할 수 있는 declared asset registry
- `previewStates`: review surface가 재현해야 하는 declared state snapshot
- `root.*.binding`: input node가 어떤 상태 필드에 연결되는지 나타내는 explicit binding
- `root.*.navigation`: button node가 어떤 destination으로 이동하는지 나타내는 explicit navigation reference

## 3. Reference policy

### 3.1 ScreenDoc → ScreenSpec
- 문서는 자유 형식일 수 있다.
- ScreenSpec은 자유 형식이 아니다.
- 문서는 해석 대상이고, ScreenSpec은 실행 대상이다.
- compiler는 front matter와 body structure를 함께 읽어 route, sections, states, constraints, actions, accessibility, data/asset intent를 ScreenSpec에 정규화한다.
- `route` 가 front matter에 있으면 compiled ScreenSpec의 `route` 로 그대로 보존한다.
- `platforms` 가 screen-doc 에 없으면 `dsctl.config.json` 의 `defaultPlatforms` 를 사용한다.
- complete authoring이 필요할 때 body에 아래 structured section을 둘 수 있다.
  - `## State Fields`
  - `## Actions`
  - `## Assets`
  - `## Preview States`
  - `## Navigation`
  - `## Component Details`
- `State Fields` item은 `field-id | type=string|boolean|integer|number | default=<json-scalar>` 형식을 사용한다.
- `Actions` item은 action id만 가진다.
- `Assets` item은 `asset-name | kind=image|icon` 형식을 사용한다.
- `Preview States` item은 `state-id | values=<json-object> | note=<text>` 형식을 사용한다.
- `Navigation` item은 `destination-id | route=/path` 형식을 사용한다.
- `Component Details` item은 `component-token | key=value | ...` 형식을 사용하고, `text`, `label`, `body`, `caption`, `title`, `action`, `navigation`, `binding`, `id`, `inputType`, `assetName` 같은 속성을 명시한다.
- core acceptance set에서는 compiler가 손실 없는 ScreenSpec을 만들거나, validator가 generate 전에 명시적으로 실패해야 한다.
- `states`, `constraints`, `stateFields`, `actions`, `navigation`, `assets`, `previewStates`, input `binding`, button `navigation` 은 실행 가능한 계약 데이터로 보존되어야 한다.
- `route` 와 `navigation[*].route` 는 `/path` 형식을 따라야 하고 공백을 포함하면 안 된다.
- `compile-screen-doc` 는 starter spec 파일과 sidecar completion report를 함께 남기고, unresolved authoring gap을 구조화해서 보고해야 한다.
- `validate --screen-doc` 는 compile 결과에 unresolved item이 남아 있으면 그것을 validation error로 승격해야 한다.
- `generate --screen-doc` 와 `generate-bundle --screen-doc-dir` 는 complete compile 결과만 downstream artifact로 보낼 수 있다.

### 3.2 Token alias usage
ScreenSpec 안에서 spacing, surface background, text style 등은 raw literal을 쓰지 않는다.
항상 token alias를 쓴다.

허용:
```json
{ "padding": "{space.6}" }
```

금지:
```json
{ "padding": "24" }
```

## 4. Canonical rules

1. authoritative contract는 ScreenSpec이다.
2. `screen-doc`, `tokens`, `catalog`, `config`는 사람이 유지하는 upstream input이다.
3. generated code는 canonical source가 아니다.
4. preview HTML은 review surface일 뿐 source가 아니다.
5. Penpot / Pencil / any editor file은 source가 아니다.
6. catalog 밖의 component는 생성할 수 없다.

## 5. Versioning

### 5.1 schemaVersion
- ScreenSpec은 schemaVersion 필드를 가진다.
- v1은 `"1.0"`으로 고정한다.

### 5.2 breaking changes
다음은 breaking change다.
- component kind 변경
- required field 변경
- token reference policy 변경
- generator output path policy 변경

## 6. Contract expansion rule

새 component를 추가하려면 아래를 같이 바꿔야 한다.

1. component-catalog schema
2. example catalog
3. validator
4. iOS generator
5. Android generator
6. HTML generator
7. tests
8. docs


# docs/04-tech-stack-decision.md

# 04. Tech Stack Decision

## 1. Decision

v1 control plane은 **Swift 6 + Swift Package Manager**로 구현한다.

## 2. Compared options

| 항목 | Swift | Rust |
|---|---:|---:|
| macOS 적합성 | 매우 높음 | 높음 |
| iOS 인접성 | 매우 높음 | 낮음 |
| Android 코드 생성 가능성 | 충분함 | 충분함 |
| 단일 언어 단순성 | 높음 | 중간 |
| 팀 onboarding 비용 | 낮음 | 중간~높음 |
| MCP 공식 SDK | 있음 | 있음 |
| v1 복잡도 | 낮음 | 더 높음 |

## 3. Final stack

### 3.1 Core
- Swift 6
- Swift Package Manager
- Foundation
- Codable / JSONSerialization
- XCTest

### 3.2 Recommended production dependencies
- `apple/swift-argument-parser`
- `modelcontextprotocol/swift-sdk`

### 3.3 Targets
- iOS output: SwiftUI
- Android output: Jetpack Compose
- Review output: Static HTML + CSS

### 3.4 Not in core path
- Node.js
- TypeScript
- Style Dictionary
- Penpot runtime integration
- Pencil runtime integration

## 4. Why Swift wins

### 4.1 Language adjacency
control plane이 iOS와 같은 언어권에 있으면 팀의 사고 비용이 낮아진다.

### 4.2 macOS-first default
이 시스템의 기본 운영 환경은 macOS다.

### 4.3 enough for Android generation
Android target은 Kotlin으로 직접 작성하는 것이 아니라 **생성**하는 것이다.
따라서 generator 언어가 Kotlin일 필요는 없다.

### 4.4 official MCP path exists
Swift용 공식 MCP SDK가 있으므로 production path를 정리하기 쉽다.

## 5. Why Rust loses for v1

Rust는 훌륭하지만 이번 문제에서는 다음이 더 중요하다.

- 팀 적합성
- iOS adjacency
- 도입 속도
- 사고 모델 단순성

즉, 이번 문제의 최적화 대상은 **throughput of engineering decisions**다.

## 6. Android target choice

Android는 Jetpack Compose를 target으로 삼는다.

이유:
- modern native Android UI
- declarative structure
- token-driven theme mapping과 잘 맞음
- generated code review가 쉽다

## 7. Review / adapter choices

### Core
- HTML preview

### Optional adapters
- Penpot: self-hosted/open-source review adapter
- Pencil: optional local preview adapter

단, 둘 다 core path는 아니다.


# docs/05-repo-structure-and-naming.md

# 05. Repo Structure and Naming

## 1. Current package vs target repo

이 저장소는 문서 bootstrap이 아니라 **실제 SwiftPM 구현 저장소**다.
docs / schemas / examples / prompts를 source package로 유지하면서, 실행 코드와 doc-sync bridge를 같은 저장소 안에서 운영한다.

### 1.1 Current implementation package

```text
axys/
  Package.swift
  Package.resolved
  README.md
  MASTER_BLUEPRINT.md
  AGENTS.md
  AGENTS_TEMPLATE.md
  ALL_DOCS_COMBINED.md
  MANIFEST.json

  Sources/
    DSCore/
    DSCLI/
    DSDocSync/
    DSDocSyncKit/
    DSMCP/
    DSMCPKit/

  Tests/
    DSCLITests/
    DSCoreTests/
    DSDocSyncKitTests/
    DSMCPKitTests/

  docs/
  meta/
    cue.mod/
    runtime/
    governance/
    views/
      runtime.contracts.json
      governance.contracts.json
      governance.fragments.json
      docsync.manifest.json
      fragments/
  schemas/
  examples/
  prompts/
  integration/
  build/
  audit/
```

### 1.2 Stable repository shape

권장 이름은 아래 중 하나다.

- `mobile-design-automation`
- 팀 규칙에 맞는 동등한 kebab-case 이름

## 2. Top-level tree

```text
mobile-design-automation/
  Package.swift
  Package.resolved
  README.md
  MASTER_BLUEPRINT.md
  AGENTS.md
  ALL_DOCS_COMBINED.md
  MANIFEST.json

  Sources/
    DSCore/
    DSCLI/
    DSDocSync/
    DSDocSyncKit/
    DSMCP/
    DSMCPKit/

  Tests/
    DSCLITests/
    DSCoreTests/
    DSDocSyncKitTests/
    DSMCPKitTests/

  docs/
  meta/
    cue.mod/
    runtime/
    governance/
    views/
      runtime.contracts.json
      governance.contracts.json
      governance.fragments.json
      docsync.manifest.json
      fragments/
  schemas/
  examples/
    screen-doc/
    screens/
    tokens/
    catalogs/
    configs/
  prompts/
  integration/
    ios/
    android/
    preview/
  build/
    generated only
  audit/
    evidence/
      acceptance/
      integration/
      runtime/
```

## 3. Module names

- `DSCore`
- `DSDocSyncKit`
- `DSMCPKit`
- `DSCLI`
- `DSDocSync`
- `DSMCP`

## 4. Binary names

- `dsctl`
- `ds-doc-sync`
- `ds-mcp`

## 5. File naming rules

### 5.1 docs
- kebab-case
- numbered prefixes for reading order

### 5.2 examples
- `login.screen.json`
- `product-detail.screen.json`

### 5.3 schemas
- `screen-spec.schema.json`
- `component-catalog.schema.json`
- `dsctl.config.schema.json`

### 5.4 generated outputs
- `LoginScreen.swift`
- `ProductDetailScreen.kt`
- `tokens.css`

## 6. Path ownership rules

### 사람이 수정하는 곳
- `AGENTS.md`
- `MASTER_BLUEPRINT.md`
- `docs/`
- `meta/runtime/`
- `meta/governance/`
- `meta/views/governance.fragments.json`
- `examples/screen-doc/`
- `examples/screens/`
- `examples/tokens/`
- `examples/catalogs/`
- `examples/configs/`
- `schemas/`
- `prompts/`
- `integration/`
- `audit/evidence/`
- `audit/evidence/runtime/doctor.json`

### generator나 검증 명령이 갱신하는 곳
- `build/`
- `meta/views/runtime.contracts.json`
- `meta/views/governance.contracts.json`
- `meta/views/fragments/`
- `ALL_DOCS_COMBINED.md`
- `MANIFEST.json`
- `audit/integrity-report.json`

## 7. Host app split recommendation

### iOS
```text
apps/ios/
  App/
  DesignSystem/
  GeneratedUI/
  SnapshotTests/
  UITests/
```

### Android
```text
apps/android/
  app/
  designsystem/
  generatedui/
  screenshot-tests/
  ui-tests/
```


# docs/06-data-models-and-schemas.md

# 06. Data Models and Schemas

## 1. ScreenSpec model

```text
ScreenSpec
  schemaVersion: String
  screenId: String
  title: String
  route: String?
  intent: String?
  constraints: [String]
  states: [String]
  stateFields:
    - id: String
      type: string|boolean|integer|number
      defaultValue: JSONValue?
  actions:
    - id: String
  navigation:
    - id: String
      route: /path
  assets:
    - name: String
      kind: image|icon
  previewStates:
    - id: String
      values: { [stateFieldId]: JSONValue }
      note: String?
  platforms: [ios|android|html]
  surface:
    backgroundColor: TokenAlias
    padding: TokenAlias
  root: ScreenNode
```

## 2. ScreenNode model

허용 kinds:
- vstack
- hstack
- card
- text
- textField
- secureField
- button
- divider
- spacer
- image
- icon

## 3. Field semantics

### text
- required: `text`
- optional: `role`

### textField
- required: `label`
- optional: `id`, `binding`, `inputType`
- `binding` 이 있으면 declared `stateFields[*].id` 중 하나를 참조해야 한다
- `inputType`
  - `text`: 기본 text input
  - `email`: email keyboard / autocorrect off / email field hint
  - `number`: numeric keyboard

### secureField
- required: `label`
- optional: `id`, `binding`
- password semantic을 가진 secure input으로 생성한다
- `binding` 이 있으면 declared `stateFields[*].id` 중 하나를 참조해야 한다

### button
- required: `title`
- optional: `variant`, `action`, `navigation`
- button은 `action` 또는 `navigation` 중 정확히 하나만 가져야 한다
- `actions` 가 선언된 spec에서는 `action` 이 declared action id를 참조해야 한다
- `navigation` 이 있으면 declared `navigation[*].id` 중 하나를 참조해야 한다

### vstack / hstack / card
- required: `children`
- optional: `spacing`

### image / icon
- required: `assetName`
- `assetName` 은 declared `assets[*].name` 중 하나를 참조해야 한다
- `image` 는 큰 visual asset
- `icon` 은 compact symbolic asset

## 4. interaction semantics

- `stateFields` 는 host integration과 generator가 공유하는 state surface다.
- `actions` 는 generated adapter와 host logic이 공유하는 action surface다.
- `navigation` 은 generated adapter와 host router가 공유하는 destination surface다.
- `assets` 는 media node가 참조할 수 있는 explicit asset registry다.
- `previewStates` 는 HTML / SwiftUI / Compose preview가 재현해야 하는 declared review snapshot이다.
- `previewStates[*].id` 는 declared `states[*]` 중 하나를 참조해야 한다.
- `previewStates[*].values.*` 는 declared `stateFields[*].id` 와 type을 따라야 한다.
- input node의 `binding` 은 UI tree 추론 대신 어떤 state field를 읽고 쓰는지 명시한다.
- button node의 `navigation` 은 UI tree 추론 대신 어떤 destination을 호출하는지 명시한다.
- explicit interaction contract가 있으면 generator와 validator는 그것을 우선 사용한다.

## 5. surface semantics

`surface.backgroundColor` 와 `surface.padding`은 token alias만 허용한다.

## 6. route semantics

- `route` 와 `navigation[*].route` 는 `/` 로 시작해야 한다.
- `route` 와 `navigation[*].route` 는 공백을 포함할 수 없다.

## 7. ComponentCatalog

catalog는 허용 vocabulary를 정의한다.
role / variant / inputType도 catalog에서 제한한다.

## 8. dsctl config

추천 config:

```json
{
  "schemaVersion": "1.0",
  "projectRoot": ".",
  "screenDocDir": "examples/screen-doc",
  "screenSpecDir": "examples/screens",
  "tokenDir": "examples/tokens",
  "catalogPath": "examples/catalogs/component-catalog.json",
  "buildDir": "build",
  "defaultPlatforms": ["ios", "android", "html"]
}
```

`defaultPlatforms` 는 screen-doc compiler가 front matter에 `platforms` 가 없을 때 fallback으로 사용한다.

## 9. Token policy

### allowed
- color
- dimension
- number
- string (optional metadata text)

### disallowed in v1
- runtime math expressions in ScreenSpec
- arbitrary inline style objects
- platform-specific style blocks inside ScreenSpec

## 10. Schema ownership

schema가 바뀌면 아래를 동시에 바꿔야 한다.
- docs
- examples
- validator
- generators
- tests

## 11. Governance evidence models

governance evidence는 자유형 메모가 아니라 machine-checked JSON artifact다.

### planning reread evidence
- `artifactId`
- `artifactType=reread_checklist`
- `verifiedOn=YYYY-MM-DD`
- `documents=[path]`
- `notes`

규칙:
- `documents` 는 비어 있으면 안 되고 canonical planning reread set을 모두 포함해야 한다.
- 현재 canonical set은 아래 경로다.
  - `MASTER_BLUEPRINT.md`
  - `docs/11-execution-plan.md`
  - `docs/12-task-matrix.md`
  - `docs/18-a-to-z-onboarding.md`
  - `docs/20-traceability-matrix.md`
  - `docs/23-authoritative-source-architecture.md`
  - `docs/24-authoritative-source-execution-plan.md`
  - `docs/25-authoritative-source-task-matrix.md`
- `documents[*]` 는 실제 source-owned 문서를 가리켜야 한다.
- `notes` 는 비어 있으면 안 된다.

### runtime doctor evidence
- `artifactId`
- `artifactType=doctor_report`
- `verifiedOn=YYYY-MM-DD`
- `verification.command`
- `verification.testCase`
- `verification.testSource`
- `report.ok`
- `report.capabilities.*`
- `report.toolchains.*`

규칙:
- `report.ok` 는 `true` 여야 한다.
- `verification.command == swift run dsctl doctor --json`
- `report.capabilities.html_preview == report.toolchains.python3`
- `report.capabilities.ios_host_smoke == report.toolchains.swiftc`
- `report.capabilities.android_host_smoke == report.toolchains.java_runtime && (report.toolchains.kotlinc || report.toolchains.gradle)`
- verifying machine에서 `report` 는 현재 `dsctl doctor --json` 결과와 같아야 한다.
- `verification.testCase` 는 `verification.testSource` 에 있는 실제 `@Test("...")` 선언과 같아야 한다.
- `verification.testSource` 가 `path:line` 형식이면 그 line은 declared `@Test("...")` 를 직접 가리켜야 한다.

### integration smoke evidence
- `artifactId`
- `artifactType=integration_smoke`
- `platform=ios|android`
- `status=pass|partial|blocked`
- `verifiedOn=YYYY-MM-DD`
- `requiredCapability`
- `doctorEvidence`
- `wrapperSources=[path]`
- `verification.command`
- `verification.testCase`
- `verification.testSource`
- `knownGap?`
- `notes`

규칙:
- `status=pass` 이면 `knownGap` 이 비어 있어야 한다.
- `status=partial|blocked` 이면 `knownGap` 이 있어야 한다.
- `verification.command == swift test`
- `requiredCapability` 는 runtime root의 `doctorCapabilities` 중 하나여야 한다.
- `doctorEvidence` 는 source-owned runtime doctor artifact를 가리켜야 한다.
- `verifiedOn` 은 referenced `doctorEvidence.verifiedOn` 과 같아야 한다.
- `wrapperSources[*]` 와 `verification.testSource` 는 실제 source-owned 파일을 가리켜야 한다.
- `verification.testCase` 는 `verification.testSource` 에 있는 실제 `@Test("...")` 선언과 같아야 한다.
- `verification.testSource` 가 `path:line` 형식이면 그 line은 declared `@Test("...")` 를 직접 가리켜야 한다.

### acceptance evidence
- `artifactId`
- `artifactType=acceptance_report`
- `screenId`
- `status=pass|partial|blocked`
- `verifiedOn=YYYY-MM-DD`
- `authoringInputs.screenDoc`
- `authoringInputs.screenSpec`
- `verification=[command]`
- `review.reviewedPreviewStates=[preview state id]`
- `review.checklist[].id`
- `review.checklist[].note`
- `reviewSurface`
- `generatedManifest`
- `hostEvidence=[integration artifact path]`
- `blockingHostEvidence=[non-pass integration artifact path]`
- `residualGaps`

규칙:
- `status=pass` 이면 `residualGaps` 가 비어 있어야 한다.
- `status=partial|blocked` 이면 `residualGaps` 가 있어야 한다.
- `status=pass` 이면 `blockingHostEvidence` 가 비어 있어야 하고 referenced `hostEvidence[*]` 도 모두 `status=pass` 여야 한다.
- `status=partial|blocked` 이면 non-pass `hostEvidence[*]` 를 `blockingHostEvidence[*]` 에 모두 적어야 한다.
- `authoringInputs.*`, `reviewSurface`, `generatedManifest`, `hostEvidence[*]` 는 실제 경로를 가리켜야 한다.
- `generatedManifest.inputSpecPath` 는 referenced `authoringInputs.screenSpec` 와 같아야 한다.
- `generatedManifest.generatedFiles` 는 `reviewSurface`, `report.validation.json`, 그리고 referenced `ScreenSpec.platforms[*]` 전체의 generated output을 포함해야 한다.
- `hostEvidence[*]` 는 referenced `ScreenSpec.platforms` 중 native platform(`ios`, `android`) 전부를 덮어야 한다.
- `blockingHostEvidence[*]` 는 `hostEvidence[*]` 의 subset 이어야 하고 pass host smoke를 가리키면 안 된다.
- `verifiedOn` 은 referenced `hostEvidence[*].verifiedOn` 과 같아야 한다.
- `verification[*]` 는 최소한 아래 canonical fresh-evidence 명령을 포함해야 한다.
  - `swift test`
  - `swift run ds-doc-sync sync --project-root . --json`
  - `swift run dsctl audit --project-root . --json`
  - `swift run dsctl generate --config examples/configs/dsctl.config.json --screen-id <screenId> --json`
- `review.reviewedPreviewStates` 는 referenced `ScreenSpec.previewStates[*].id` 와 정확히 같아야 한다.
- `review.checklist` 는 비어 있으면 안 되고 아래 최소 id를 포함해야 한다.
  - `structure.primary_intent`
  - `semantics.preview_coverage`
  - `tokens.alias_usage`
  - `native.adapter_viability`


# docs/07-cli-and-mcp-spec.md

# 07. CLI and MCP Specification

## 1. CLI is canonical

`dsctl`은 시스템의 표준 인터페이스다.
MCP는 같은 기능을 외부 에이전트에 노출하는 thin adapter다.

## 2. CLI commands

### 2.1 doctor
환경과 capability를 출력한다.

```bash
dsctl doctor --json
```

출력 예:
```json
{
  "ok": true,
  "swift_version": "Apple Swift version ...",
  "capabilities": {
    "cli": true,
    "mcp": true,
    "ios_renderer": true,
    "android_renderer": true,
    "html_preview": true,
    "ios_host_smoke": true,
    "android_host_smoke": true
  },
  "toolchains": {
    "swiftc": true,
    "python3": true,
    "java_runtime": true,
    "kotlin": true,
    "kotlinc": true,
    "gradle": false
  }
}
```

규칙:
- `ios_renderer`, `android_renderer` 는 generator가 source artifact를 만들 수 있는지를 뜻한다.
- `ios_host_smoke`, `android_host_smoke` 는 이 머신이 compile-backed host smoke evidence를 만들 준비가 됐는지를 뜻한다.
- `android_renderer=true` 이더라도 `java_runtime`, `kotlinc`, `gradle` 중 필요한 toolchain이 없으면 `android_host_smoke=false` 일 수 있다.
- source-owned runtime snapshot은 `audit/evidence/runtime/doctor.json` 에 기록할 수 있고, integration evidence는 이 artifact를 참조해 compile-backed readiness 근거를 남긴다.

### 2.2 compile-screen-doc
하나의 screen-doc markdown을 starter `ScreenSpec` JSON으로 정규화하고 sidecar completion report를 남긴다.

```bash
dsctl compile-screen-doc \
  --config examples/configs/dsctl.config.json \
  --screen-id login \
  --json
```

기본 출력 경로:
- `build/compiled/<screen-id>.screen.json`

sidecar report 경로:
- `build/compiled/<screen-id>.compile-report.json`

report 핵심 필드:
- `completion_status`: `complete` 또는 `starter`
- `unresolved_items`: completion 전까지 남아 있는 authoring gap
- `warnings`: 비차단성 보조 신호
- `screen-doc` 의 `State Fields`, `Actions`, `Component Details` section이 충분하면 `completion_status` 는 `complete` 가 된다.

### 2.3 validate
하나의 ScreenSpec 또는 screen-doc를 검증한다.

```bash
dsctl validate   --spec examples/screens/login.screen.json   --tokens examples/tokens   --catalog examples/catalogs/component-catalog.json   --json
```

config 기반 권장 호출:

```bash
dsctl validate --config examples/configs/dsctl.config.json --screen-id login --json
```

screen-doc 직접 검증:

```bash
dsctl validate --config examples/configs/dsctl.config.json --screen-doc examples/screen-doc/login.md --json
```

- compile 결과에 `unresolved_items` 가 남아 있으면 `validate` 는 exit code `2` 와 `ValidationReport` 를 반환한다.

### 2.4 generate
iOS / Android / HTML artifacts를 생성한다.

```bash
dsctl generate   --spec examples/screens/login.screen.json   --tokens examples/tokens   --catalog examples/catalogs/component-catalog.json   --out build/login   --json
```

config 기반 권장 호출:

```bash
dsctl generate --config examples/configs/dsctl.config.json --screen-id login --json
```

screen-doc 직접 생성:

```bash
dsctl generate --config examples/configs/dsctl.config.json --screen-doc examples/screen-doc/login.md --out build/from-screen-doc/login --json
```

이 경로는 출력 디렉터리 안에 `compiled.screen.json` 을 남기고, manifest의 `inputSpecPath` 는 그 파일을 가리킨다.
- 단, compile 결과가 `starter` 이면 generation은 시작되지 않고 exit code `2` 의 `ValidationReport` 를 반환한다.
- 이 경우 `compiled.screen.json`, manifest, platform artifact는 쓰지 않는다.

### 2.5 generate-bundle
여러 ScreenSpec 또는 screen-doc를 한 번에 생성한다.

```bash
dsctl generate-bundle   --spec-dir examples/screens   --tokens examples/tokens   --catalog examples/catalogs/component-catalog.json   --out build/bundle   --json
```

config 기반 권장 호출:

```bash
dsctl generate-bundle --config examples/configs/dsctl.config.json --json
```

screen-doc bundle 생성:

```bash
dsctl generate-bundle --config examples/configs/dsctl.config.json --screen-doc-dir examples/screen-doc --out build/from-screen-doc/bundle --json
```

이 경로는 각 스크린 출력 디렉터리 아래에 `compiled.screen.json` 을 남긴다.
- `starter` screen-doc 가 하나라도 있으면 해당 항목은 failure에 기록되고 bundle exit code는 `4` 가 된다.

### 2.6 preview-serve
HTML preview directory를 로컬로 서빙한다.

```bash
dsctl preview-serve --dir build/login/html --port 4173
```

- `port` 는 `1...65535` 범위의 정수여야 한다.

### 2.7 audit
문서/파일/예시/스키마 정합성을 검사한다.

```bash
dsctl audit --project-root . --json
```

config 기반 권장 호출:

```bash
dsctl audit --config examples/configs/dsctl.config.json --json
```

## 3. CLI policy

- 기본 출력은 machine-readable JSON
- interactive prompt는 기본적으로 금지
- non-zero exit code를 사용
- stderr에는 human-readable 요약 가능
- stdout에는 JSON payload 우선
- `--config`가 있으면 token/catalog/build/project root 기본값은 config에서 해석한다
- `validate` 와 `generate` 는 입력 소스로 `--screen-id`, `--spec`, `--screen-doc` 중 하나만 받는다
- `generate-bundle` 은 입력 소스로 `--spec-dir` 또는 `--screen-doc-dir` 중 하나만 받는다
- MCP의 `validate_spec` / `generate_screen` 도 같은 validation failure를 `ValidationReport` 로 surface 한다

## 4. Exit code policy

- `0`: success
- `1`: operational error
- `2`: validation failed
- `4`: generation or bundle generation failed
- `5`: audit failed

config mismatch, missing required option, invalid path 같은 operational 입력 오류는 현재 v1에서 `1` 로 surface 한다.
`3` 은 현재 v1 runtime contract에 포함되지 않는다.

## 5. MCP tool surface

### initialize
MCP handshake

### tools/list
최소 제공 도구:
- `doctor`
- `compile_screen_doc`
- `validate_spec`
- `generate_screen`
- `generate_bundle`
- `preview_serve`
- `audit_project`

### tools/call
각 도구는 CLI equivalent와 동일한 upstream input을 받는다.
예를 들어 `validate_spec` 는 `spec` 또는 `screenDoc` 중 하나와 `tokens`, `catalog` 를 받는다.
`generate_screen` 은 `spec` 또는 `screenDoc` 중 하나와 `tokens`, `catalog`, `out` 을 받는다.
`compile_screen_doc` 는 `screenDoc + out` 또는 `config + screenId (+ optional out)` 을 받는다.

## 6. MCP response policy

- tool result는 structured JSON text로 반환
- operational error도 plain text 대신 structured JSON error report로 반환
- `preview_serve.port` 는 생략 시 `4173`, 제공 시 정수 문자열이어야 한다
- business logic은 DSCore에만 존재
- MCP layer는 변환과 transport만 담당

## 7. Stability rules

다음은 stable interface로 간주한다.
- binary names
- top-level commands
- JSON result shape의 주요 필드
- tool names


# docs/08-generation-architecture.md

# 08. Generation Architecture

## 1. Overall generator design

```text
ScreenSpec
  + TokenStore
  + ComponentCatalog
      ↓
ValidationReport
      ↓
ArtifactGenerator
      ↓
SwiftUI / Compose / HTML / Manifests
```

## 2. Generator responsibilities

### 2.1 iOS generator
- SwiftUI file 생성
- platform-typed `DesignTokens.swift` 생성 또는 연결
- explicit `stateFields` 기반 hoisted state struct 생성
- explicit `actions` 기반 action closure contract 생성
- explicit `navigation` 기반 navigation closure contract 생성
- declared `previewStates` 기반 multi-preview block 생성
- root/card surface를 native `Color`/`CGFloat` token으로 적용

### 2.2 Android generator
- Compose screen file 생성
- platform-typed `DesignTokens.kt` 생성 또는 연결
- explicit `stateFields` 기반 hoisted state data class 생성
- explicit `actions` 기반 action lambda contract 생성
- explicit `navigation` 기반 navigation lambda contract 생성
- declared `previewStates` 기반 `@Preview` 함수 생성
- root/card surface를 native `Color`/`Dp` token으로 적용

### 2.3 HTML generator
- screen html 생성
- preview index 생성
- declared `previewStates` review surface 생성
- navigation button이면 route anchor를 생성
- tokens.css 생성

## 3. Rendering philosophy

generator는 “자유롭게 UI를 창작”하지 않는다.
generator는 contract를 **platform-appropriate primitive tree**로 사상(mapping)한다.

## 4. Mapping policy

generator는 `ScreenSpec.platforms` 에 포함된 플랫폼에 대해서만 artifact를 생성한다.

### 4.1 vstack
- iOS: `VStack`
- Android: `Column`
- HTML: `display:flex; flex-direction:column`

### 4.2 hstack
- iOS: `HStack`
- Android: `Row`
- HTML: `display:flex; flex-direction:row`

### 4.3 text role mapping
- iOS: `.title`, `.body`, `.caption`, caption-weighted label style
- Android: `titleLarge`, `bodyLarge`, `bodySmall`, `labelMedium`
- HTML: role class name 유지

### 4.4 button variants
- iOS: `.borderedProminent`, `.bordered`
- Android: `Button`, `OutlinedButton`
- HTML: `button-primary`, `button-secondary`

### 4.5 fields
- `textField`
  - iOS: `TextField` + `keyboardType` / `textContentType` / autocorrection policy
  - Android: `OutlinedTextField` + `KeyboardOptions`
  - HTML: `<input type="text|email|number">`
- `secureField`
  - iOS: `SecureField` + password content type + no autocorrect
  - Android: `OutlinedTextField` + `PasswordVisualTransformation` + password keyboard
  - HTML: `<input type="password" autocomplete="current-password">`

### 4.6 interaction contract
- iOS: generated `State` + `Actions` + `Navigation` injection
- Android: generated `State` + `Actions` + `Navigation` lambda injection
- generator는 `ScreenSpec.stateFields`, `ScreenSpec.actions`, `ScreenSpec.navigation`, input node `binding`, button node `navigation` 을 먼저 읽는다
- explicit interaction contract가 없을 때만 baseline tree inference를 fallback으로 사용한다

- button이 `action` 을 가지면 generated callback/lambda를 호출한다
- button이 `navigation` 을 가지면 generated navigation adapter를 호출하고, HTML에서는 destination route anchor로 렌더링한다

### 4.7 preview-state review contract
- HTML: declared `previewStates` 를 순서대로 모두 렌더링하고 state id / note를 review surface에 노출한다
- iOS: declared `previewStates` 를 named `#Preview` block으로 노출한다
- Android: declared `previewStates` 를 named `@Preview` function으로 노출한다
- preview state가 field 값을 가지면 generator는 declared `stateFields` default 위에 override해서 preview snapshot을 만든다

### 4.8 surfaces and token typing
- iOS: color token은 `Color(.sRGB, ...)`, dimension token은 `CGFloat`
- Android: color token은 `Color(0xAARRGGBB)`, dimension token은 `Dp`
- HTML: token CSS variable 유지
- root surface는 screen background + outer padding으로 적용
- `card` 는 platform-native container background/shape/padding으로 적용

### 4.9 media primitives
- `image`
  - iOS: `Image("asset")`
  - Android: `Image(painterResource(...))`
  - HTML: `<img class="image" ...>`
- `icon`
  - iOS: `Image(systemName: ...)`
  - Android: `Icon(painterResource(...))`
  - HTML: `<img class="icon" ...>`
- generator와 validator는 media node를 렌더링하기 전에 `ScreenSpec.assets` 에 declared asset이 있는지 먼저 확인한다.

## 5. Token resolution policy

generator는 raw token JSON을 직접 다루지 않고, resolver가 만든 `ResolvedTokenStore`를 사용한다.

필수 기능:
- alias resolution
- cycle detection
- type carry-through
- deterministic ordering

## 6. Artifact layout

```text
build/login/
  manifest.json
  report.validation.json
  ios/              # present only when ios is enabled
    LoginScreen.swift
    DesignTokens.swift
  android/          # present only when android is enabled
    LoginScreen.kt
    DesignTokens.kt
  html/             # present only when html is enabled
    login.html
    index.html
    tokens.css
```

## 7. Manifest content

manifest는 다음을 포함한다.
- input spec path
- input token paths
- generated files
- validation summary
- generator version
- schemaVersion

## 8. Determinism requirements

- input path order 정규화
- token merge order 정규화
- output file sort order 정규화
- manifest key order 정규화
- timestamp는 v1에서는 manifest에서 제외한다


# docs/09-preview-review-and-adapters.md

# 09. Preview, Review, and Optional Adapters

## 1. Canonical review path

canonical review path는 **HTML preview**다.

## 2. Why HTML

- 가장 가볍다.
- CI artifact로 남기기 쉽다.
- local file로 열 수 있다.
- 다른 앱을 켜지 않아도 된다.
- design editor lock-in이 없다.

## 3. Review workflow

```text
generate
  → open html
  → check declared preview states
  → confirm structure/hierarchy/action emphasis
  → approve
  → integrate native
```

## 4. Review checklist

### 4.1 Structure
- hierarchy가 명확한가
- 스크린이 하나의 primary intent를 갖는가

### 4.2 Semantics
- declared preview state가 모두 보이는가
- state note와 field snapshot이 review 의도와 맞는가
- title / body / caption / label이 적절한가
- button variant가 맞는가

### 4.3 Tokens
- spacing이 tokens에서 왔는가
- color가 tokens에서 왔는가

### 4.4 Native viability
- 이 구조를 SwiftUI/Compose로 무리 없이 옮길 수 있는가

source-owned acceptance evidence는 이 체크를 자유형 메모로 남기지 않는다.
canonical acceptance artifact의 `review` section은 아래 최소 checklist id를 가진다.

- `structure.primary_intent`
- `semantics.preview_coverage`
- `tokens.alias_usage`
- `native.adapter_viability`

또한 `review.reviewedPreviewStates` 는 referenced `ScreenSpec.previewStates[*].id`
전체를 담아야 하고, HTML review surface 안에서도 같은 state id가 보여야 한다.
acceptance artifact는 여기서 끝나지 않고 `generatedManifest` 로 같은 review surface와
declared platform output이 실제 generated bundle 안에 있는지도 함께 고정한다.

## 5. Penpot policy

Penpot은 다음 역할만 가진다.
- optional review adapter
- optional self-hosted collaboration surface
- optional token / inspect alignment aid

Penpot file은 authoritative source가 아니다.

## 6. Pencil policy

Pencil은 다음 역할만 가진다.
- optional local preview / operator tool
- optional AI-assisted visual exploration

Pencil file은 authoritative source가 아니다.

## 7. Adapter boundary

어떤 adapter도 아래를 건드리면 안 된다.
- ScreenSpec schema
- token policy
- generation pipeline

즉, adapter는 **core path 외부**에 있다.


# docs/10-agent-operating-model.md

# 10. Agent Operating Model

## 1. Primary agent rule

에이전트는 직접 SwiftUI/Compose 화면 코드를 “창작”하지 않는다.
에이전트의 주 작업 대상은 **ScreenSpec**이다.

## 2. Agent workflow

```text
1. screen-doc 읽기
2. component catalog 읽기
3. tokens 정책 읽기
4. ScreenSpec 생성 또는 수정
5. validate 실행
6. generate 실행
7. HTML review
8. 실패 시 ScreenSpec / tokens 수정
```

## 3. Agent constraints

- generated files 직접 수정 금지
- catalog에 없는 component 추가 금지
- raw spacing / color literal 사용 금지
- platform-specific block을 ScreenSpec에 넣지 않음
- 하나의 spec은 하나의 primary intent를 유지

## 4. AGENTS.md guidance

repo root에 `AGENTS.md`를 두고 아래 내용을 명시한다.
- source of truth
- mandatory command sequence
- validation before generation
- generated output immutability
- allowed component vocabulary

## 5. Prompt templates

### 5.1 `prompts/spec-generation.md`
- 입력: screen-doc
- 출력: ScreenSpec JSON only

### 5.2 `prompts/review-and-fix.md`
- 입력: screen-doc + ScreenSpec + validation report + HTML preview
- 출력: upstream fix proposal only

## 6. Multi-agent split (optional)

### Agent A — Normalizer
screen-doc → ScreenSpec

### Agent B — Validator fixer
validation errors → corrected ScreenSpec

### Agent C — Reviewer
HTML/native diff → upstream improvement proposal

## 7. Human override points

사람은 아래에서만 개입한다.
- intent ambiguity 정리
- design token 의미 결정
- catalog 확장 승인
- final review approval


# docs/11-execution-plan.md

# 11. Execution Plan

## 1. Delivery target

이번 delivery target은 **지원할 핵심기능에 대해 `screen-doc -> ScreenSpec -> validate -> generate -> review -> integrate` 를 최종 완성 수준으로 닫는 것** 이다.

여기서 핵심기능은 아래 여섯 축으로 정의한다.

1. `screen-doc` 에서 starter spec과 completion report를 만드는 authoring path
2. 상태, 액션, 네비게이션, asset, preview state를 담는 explicit `ScreenSpec`
3. unresolved/ambiguous semantics를 generation 전에 차단하는 semantic validation
4. SwiftUI / Compose / HTML이 같은 contract 의미를 유지하는 deterministic generation
5. declared preview state 전체를 보여주는 HTML review path
6. generated adapter만으로 host app에 연결 가능한 integration path

가장 중요한 acceptance path는 아래 여섯 항목이다.

```text
login screen-doc -> starter spec -> completed ScreenSpec -> validate -> generate -> review -> integrate
product-detail screen-doc -> starter spec -> completed ScreenSpec -> validate -> generate -> review -> integrate
swift test
swift run ds-doc-sync sync --project-root . --json
swift run dsctl audit --project-root . --json
swift run dsctl generate --config examples/configs/dsctl.config.json --screen-id login --json
```

## 2. Baseline and implementation delta

- SwiftPM package, CLI, MCP, doc-sync, validator, generator baseline은 이미 존재한다.
- `login`, `product-detail` 는 현재 baseline slice를 보여주지만, final completion contract를 닫기에는 authoring semantics가 아직 충분히 explicit하지 않다.
- 현재 baseline은 compile/validate/generate/audit path를 증명했다.
- 다음 단계는 그 baseline 위에 **starter-spec authoring, complete-spec validation, multi-state review, host integration evidence** 를 올리는 것이다.
- 전체 master plan은 `11`, `12`, `20` 이 담당하고, authoritative-source 전용 workstream은 `24`, `25` annex로 관리한다.

## 3. Core completion contract

이번 cycle에서 completion으로 인정하는 결과는 아래와 같다.

- `screen-doc` 는 사람의 intent를 담고, `compile-screen-doc` 는 deterministic starter spec과 completion report를 낸다.
- authoritative `ScreenSpec` 은 core interactive screen에 필요한 상태, 액션, 네비게이션, asset, preview state를 explicit하게 담는다.
- validator는 unresolved node, broken binding, invalid route, missing asset, invalid token alias를 generation 전에 막는다.
- generator는 complete `ScreenSpec` 에 대해서만 SwiftUI / Compose / HTML artifact를 만든다.
- HTML review bundle은 declared preview state 전부를 사람이 확인할 수 있게 보여준다.
- iOS / Android host는 generated adapter를 통해 state/actions/navigation을 연결하고 generated file을 직접 수정하지 않는다.

## 4. Observable done condition

아래 조건이 모두 참이어야 이번 plan을 완료로 본다.

1. `ScreenSpec` schema/model/docs/examples가 `login` 과 `product-detail` 의 핵심 흐름을 heuristic placeholder 없이 표현한다.
2. `compile-screen-doc` 는 starter spec과 completion report를 내고, unresolved authoring gap은 validator/generator 단계로 흘러가지 않는다.
3. `validate` 는 state/action/binding/route/asset/token/catalog completeness를 강제한다.
4. `generate` 는 enriched `ScreenSpec` 에서 SwiftUI / Compose / HTML preview를 deterministic하게 생성한다.
5. HTML review bundle이 declared preview state를 모두 노출하고 review 신호를 남긴다.
6. iOS / Android host integration smoke path가 generated adapter만으로 연결된다.
7. runtime/governance/doc-sync/audit 문서와 source가 확장된 contract/evidence set을 모두 반영한다.
8. `login`, `product-detail` 두 vertical slice가 fresh evidence와 함께 end-to-end acceptance를 통과한다.

## 5. Critical path

<!-- GENERATED:BEGIN execution-plan-critical-path -->
| Phase | Status | Objective | Depends On | Exit evidence |
|---|---|---|---|---|
| P0 | Done | baseline runtime, generator, doc-sync, and audit path is re-verified | none | `swift test`, `ds-doc-sync sync`, `dsctl audit`, and `dsctl generate --config ... --screen-id login` succeed on the checked-in baseline |
| P1 | Done | final-completion planning package and authoritative-source annexes are defined | P0 | `11`, `12`, `20`, `23`, `24`, and `25` describe the final core delivery target, not only the baseline |
| P2 | Done | authoring contract and ScreenSpec model are expanded for core interactive screens | P1 | schema, models, docs, and examples express state, action, navigation, asset, and preview semantics explicitly |
| P3 | Done | screen-doc compiler and validator close the starter-spec to complete-spec path | P2 | `compile-screen-doc` emits completion-guided output and incomplete specs fail before generation |
| P4 | Done | generators and HTML review support enriched contract semantics end-to-end | P2, P3 | SwiftUI, Compose, and HTML artifacts preserve the same meaning across preview states and interactions |
| P5 | Done | iOS and Android host integration adapters compile against generated outputs | P4 | generated adapters wire to host smoke projects without hand-editing generated files |
| P6 | Done | runtime/governance/doc-sync/audit cover the expanded contract and evidence set | P2, P3, P4, P5 | contract views, fragments, manifests, audit checks, and annex docs all reflect the final core workflow |
| P7 | Done | login and product-detail pass the full delivery contract | P3, P4, P5, P6 | both slices pass compile, validate, generate, review, integrate, and verification evidence gates |
<!-- GENERATED:END execution-plan-critical-path -->

## 6. Decision gates

<!-- GENERATED:BEGIN execution-plan-decision-gates -->
| Gate | Check | Pass condition | On fail |
|---|---|---|---|
| G1 Final contract gate | target schema/model covers the supported core screens without heuristic placeholders | docs, schema, and examples can express `login` and `product-detail` states/actions/navigation/assets explicitly | stop generator expansion and finish the contract model first |
| G2 Authoring gate | `screen-doc` to starter-spec path is deterministic and completion rules are explicit | `compile-screen-doc` emits starter spec + completion report and unresolved items cannot reach generation | keep compile/report work in front of validator/generator until authoring gaps are sealed |
| G3 Semantic validation gate | validator blocks unresolved or ambiguous semantics before code generation | incomplete specs fail with actionable errors and complete specs validate cleanly | extend validation before adding more renderer behavior |
| G4 Generator and review gate | enriched contract renders consistently across SwiftUI / Compose / HTML | preview states, actions, navigation labels, and media primitives are preserved across all outputs | hold host integration until platform parity is proven |
| G5 Integration gate | generated state/action/navigation adapters connect to host code without editing generated files | iOS / Android smoke integration compiles using generated adapters only | fix integration packaging before claiming completion |
| G6 Governance gate | runtime/governance/docs/audit all reflect the expanded contract and evidence set | `ds-doc-sync`, `audit`, and authoritative-source annex docs stay fresh with new evidence keys and inventories | freeze release until source-of-truth and evidence converge |
| G7 Acceptance gate | two canonical slices prove the product is complete for core scope | `login` and `product-detail` pass compile, validate, generate, review, integrate, and verification evidence gates | keep remaining tasks open and do not claim final completion |
<!-- GENERATED:END execution-plan-decision-gates -->

## 7. Verification map

<!-- GENERATED:BEGIN execution-plan-verification-map -->
| Workstream | Verification | Expected signal |
|---|---|---|
| Planning/docs alignment | reread `MASTER_BLUEPRINT`, `11`, `12`, `18`, `20`, `23`, `24`, and `25` together | one overall plan and one authoritative-source annex structure are visible without conflicting authority |
| Authoring contract | schema/example updates, `compile-screen-doc` report tests, and source-of-truth reread | starter-spec path is explicit and no silent heuristic output is treated as final |
| Semantic validation | positive/negative validation tests for state/action/binding/route/asset/token/catalog rules | incomplete specs fail early and complete specs pass cleanly |
| Multi-platform generation | SwiftUI / Compose / HTML golden tests and manifest/report diff checks | all three outputs preserve the same contract semantics deterministically |
| HTML review | generated preview bundle inspection across declared preview states | every declared preview state is visible and reviewable in HTML |
| Host integration | iOS/Android smoke integration, compile-backed host smoke tests, and adapter compile checks | generated adapters link to host code without hand edits to generated files |
| Governance and audit | `ds-doc-sync sync`, contract export checks, and `dsctl audit` | contract views, fragments, generated docs, and evidence refs remain fresh and aligned |
| Vertical slice acceptance | end-to-end runs for `login` and `product-detail` | both slices satisfy compile, validate, generate, review, integrate, and audit gates |
<!-- GENERATED:END execution-plan-verification-map -->

## 8. Plan package structure

- `11`: 전체 execution contract와 critical path
- `12`: stable task/status ledger
- `20`: requirement-to-task-to-evidence traceability
- `24`: authoritative-source 전용 completion annex
- `25`: authoritative-source 전용 workstream task matrix

## 9. Document sync rules

아래 변화가 생기면 문서도 함께 업데이트한다.

- authoring contract 변경: `03`, `06`, `08`, `11`, `12`, `20`, `23`, `24`, `25`, `schemas/*`, `examples/*`
- CLI / MCP / exit code / contract path 변경: `07`, `11`, `20`, `23`, `24`, `25`, `meta/runtime/contracts.cue`
- governance source / evidence / fragment 변경: `11`, `12`, `20`, `23`, `24`, `25`, `meta/governance/contracts.cue`, `meta/views/governance.fragments.json`, `meta/views/fragments/*`
- host integration contract 변경: `17`, `18`, `11`, `12`, `20`, `24`, `25`
- acceptance baseline 변경: `18`, `21`, `22`, `ALL_DOCS_COMBINED.md`, `audit/integrity-report.json`


# docs/12-task-matrix.md

# 12. Task Matrix

현재 저장소는 baseline 구현을 이미 가진다.
이 matrix는 **이미 확보한 baseline evidence** 와 **최종 핵심기능 completion work** 를 한 ledger로 유지해 stable task ID를 잃지 않도록 만든다.
structured row는 hand-edit 대상이 아니라 `meta/views/governance.fragments.json` source를 렌더링한 generated view다.

Status 의미는 아래 세 가지로 닫는다.

- `Done`: checked-in repo와 fresh evidence로 이미 확인된 작업
- `In Progress`: 현재 critical path에서 바로 닫고 있는 작업
- `Planned`: dependency가 남아 있어 아직 닫지 않은 작업

## 1. Task rows

<!-- GENERATED:BEGIN task-matrix-task-rows -->
| Task ID | Status | Priority | Action | Depends On | Done when | Evidence required |
|---|---|---|---|---|---|---|
| BASE-01 | Done | P0 | runtime, generator, CLI, MCP, doc-sync, audit baseline을 fresh evidence로 다시 고정한다 | none | 현재 baseline path가 명령과 테스트로 다시 확인된다 | `swift test`, `ds-doc-sync sync`, `dsctl audit`, `dsctl generate` output |
| PLAN-01 | Done | P0 | active planning package를 final core completion 기준으로 재작성한다 | BASE-01 | `11`, `12`, `20`, `23`, `24`, `25`, `18`, `MASTER_BLUEPRINT` 가 final target과 baseline을 함께 설명한다 | updated docs, fragment export, reread checklist |
| MODEL-01 | Done | P0 | `ScreenSpec` schema/model을 core interactive screen에 맞게 확장한다 | PLAN-01 | 상태, 액션, 네비게이션, asset, preview state, binding contract가 explicit field로 정의된다 | schema diff, model tests, updated examples |
| DOC-01 | Done | P1 | `03`, `06`, `08`, `17` 과 example specs/docs를 final contract 기준으로 승격한다 | MODEL-01 | source-of-truth, data model, generation, integration docs가 확장된 contract와 충돌하지 않는다 | updated docs, example diff, link scan |
| AUTHOR-01 | Done | P0 | `compile-screen-doc` 를 starter spec + completion report path로 재정의한다 | MODEL-01 | authoring output이 deterministic하고 unresolved item이 명시적으로 보고된다 | compile tests, starter-spec snapshots, report schema |
| AUTHOR-02 | Done | P1 | `login`, `product-detail` screen-doc에 필요한 structured section과 deterministic mapping을 닫는다 | AUTHOR-01 | 두 example 모두 completion report 기준으로 authoritative spec 완성이 가능하다 | example docs, compile snapshots, acceptance checklist |
| VALIDATE-01 | Done | P0 | validator가 unresolved, state/action/binding/route/asset/token/catalog completeness를 강제한다 | MODEL-01, AUTHOR-01 | incomplete spec은 fail하고 complete spec은 clean pass 한다 | validator tests, negative fixtures, JSON reports |
| GENERATE-01 | Done | P0 | SwiftUI / Compose / HTML generator를 explicit state/action/navigation/media semantics로 확장한다 | MODEL-01, VALIDATE-01 | 세 플랫폼 출력이 같은 contract 의미를 유지한다 | golden tests, generated artifacts, manifest diff |
| REVIEW-01 | Done | P1 | HTML review bundle에 preview state coverage와 review signal을 추가한다 | GENERATE-01 | declared preview state 전체가 HTML에서 review 가능하다 | generated preview bundle, review checklist |
| INTEGRATE-01 | Done | P1 | iOS host integration pack과 smoke path를 만든다 | GENERATE-01 | generated state/action/navigation adapter가 host app에서 compile-backed smoke로 검증된다 | host compile log, compile-backed smoke tests, integration guide update |
| INTEGRATE-02 | Done | P1 | Android host integration pack과 smoke path를 만든다 | GENERATE-01 | generated state/action/navigation adapter가 host app에서 compile-backed smoke로 검증된다 | host compile log, compile-backed smoke tests, integration guide update |
| GOV-01 | Done | P0 | runtime/governance contracts, doc-sync manifest, audit evidence를 final core workflow 기준으로 확장한다 | MODEL-01, AUTHOR-01, VALIDATE-01, GENERATE-01 | expanded contract/evidence set이 source-owned view와 audit check에 반영된다 | contract view export, audit JSON, manifest diff |
| ASOT-01 | Done | P1 | authoritative-source annex(`24`, `25`)와 master ledger 사이의 workstream sync를 닫는다 | GOV-01 | annex task와 master task가 같은 source/evidence 경로를 가리킨다 | annex docs, traceability rows, reread checklist |
| E2E-01 | Done | P0 | `login` 최종 acceptance path를 닫는다 | AUTHOR-02, VALIDATE-01, GENERATE-01, REVIEW-01, INTEGRATE-01, INTEGRATE-02 | default/loading/error, field binding, submit action, review/integration evidence가 모두 통과한다 | login acceptance report, generated artifacts, host smoke |
| E2E-02 | Done | P0 | `product-detail` 최종 acceptance path를 닫는다 | AUTHOR-02, VALIDATE-01, GENERATE-01, REVIEW-01, INTEGRATE-01, INTEGRATE-02 | media/card/content/CTA/navigation or purchase flow가 review/integration evidence와 함께 통과한다 | product-detail acceptance report, generated artifacts, host smoke |
| VERIFY-01 | Done | P0 | 최종 completion evidence suite를 다시 통과시킨다 | DOC-01, GOV-01, ASOT-01, E2E-01, E2E-02 | tests, doc-sync, audit, generation, host smoke, docs evidence가 모두 fresh 하다 | fresh command outputs, integration smoke logs, audit JSON |
<!-- GENERATED:END task-matrix-task-rows -->

## 2. Decision gates

<!-- GENERATED:BEGIN task-matrix-decision-gates -->
| Gate | Trigger tasks | Pass condition | On fail |
|---|---|---|---|
| DG-01 Final contract | MODEL-01, AUTHOR-01 | authoring contract와 `ScreenSpec` model이 core screens를 explicit하게 담는다 | schema/model부터 다시 닫는다 |
| DG-02 Authoring completeness | AUTHOR-02, VALIDATE-01 | starter-spec path가 deterministic하고 unresolved item은 generation 전에 모두 차단된다 | compile/report/validator를 먼저 고친다 |
| DG-03 Generator parity | GENERATE-01, REVIEW-01 | SwiftUI / Compose / HTML이 같은 의미를 유지하고 preview state review가 가능하다 | platform parity를 닫기 전에는 integration으로 넘어가지 않는다 |
| DG-04 Host integration | INTEGRATE-01, INTEGRATE-02 | generated adapter가 host code에 연결되고 generated file hand-edit가 필요 없다 | packaging/adapter contract를 먼저 수정한다 |
| DG-05 Governance convergence | GOV-01, ASOT-01 | runtime/governance/doc-sync/audit와 annex docs가 같은 source/evidence set을 따른다 | source-of-truth와 audit evidence를 다시 맞춘다 |
| DG-06 Final acceptance | E2E-01, E2E-02, VERIFY-01 | 두 canonical slice와 final verification suite가 모두 fresh pass 한다 | completion claim을 보류하고 남은 workstream을 유지한다 |
<!-- GENERATED:END task-matrix-decision-gates -->

## 3. Task maintenance rules

1. Task ID는 이번 completion program 동안 바꾸지 않는다.
2. status 변경은 task를 renumber 하지 않고 source row에서만 갱신한다.
3. 새 태스크는 markdown 표를 직접 수정하지 말고 `meta/views/governance.fragments.json` source row를 갱신한 뒤 `ds-doc-sync export-fragments` 와 `ds-doc-sync render` 로 반영한다.
4. `MODEL-01`, `AUTHOR-01`, `VALIDATE-01`, `GENERATE-01`, `GOV-01` 은 각각 schema/model, compile/report, validator, generator, governance evidence를 반드시 함께 가리켜야 한다.
5. `E2E-01`, `E2E-02`, `VERIFY-01` 완료 전에는 어떤 row도 “final completion achieved” 의미의 `Done` 으로 간주하지 않는다.


# docs/13-test-validation-and-quality-gates.md

# 13. Test, Validation, and Quality Gates

## 1. Quality model

이 프로젝트의 품질은 아래 5층으로 나눈다.

1. **schema correctness**
2. **validator correctness**
3. **generator determinism**
4. **artifact usability**
5. **host integration confidence**

## 2. Mandatory gates

### Gate A — Schema parse
- 모든 schema JSON이 parse 가능해야 한다.
- 모든 examples JSON이 parse 가능해야 한다.

### Gate B — Example validation
- `login.screen.json` must pass
- `product-detail.screen.json` must pass

### Gate C — Deterministic generation
같은 입력을 두 번 generate 했을 때 artifact hash가 같아야 한다.
(타임스탬프가 포함되면 manifest에서 분리한다.)

### Gate D — Review artifact generation
각 screen은 HTML preview를 가져야 한다.

### Gate E — Native artifact generation
각 screen은 SwiftUI / Compose 파일을 가져야 한다.

### Gate F — CLI contract
문서에 나온 명령은 실제로 실행 가능해야 한다.

### Gate G — MCP contract
tools/list와 tools/call이 최소한 `doctor`, `compile_screen_doc`, `validate_spec`, `generate_screen`, `generate_bundle`, `preview_serve`, `audit_project`를 노출해야 한다.

### Gate H — Documentation sync
- execution plan, task matrix, traceability, integrity audit가 같은 canonical 이름과 task id를 사용해야 한다.

## 3. Test categories

### Unit tests
- token flatten
- token alias resolution
- cycle detection
- validation rule tests
- symbol name normalization

### Golden tests
- HTML output
- SwiftUI output
- Compose output

### Integration tests
- CLI doctor
- CLI doctor toolchain / host-smoke readiness invariants
- CLI compile-screen-doc
- CLI validate
- CLI generate
- CLI generate-bundle
- CLI preview-serve
- CLI audit
- CLI primary-input exclusivity failures
- CLI structured operational errors
- CLI preview path validation
- CLI preview occupied-port validation
- CLI preview port-range validation
- Doc-sync fragment export
- Doc-sync contract export
- Doc-sync sync (`export-contracts -> export-fragments -> render -> verify`)
- Doc-sync render/verify
- runtime root CLI/MCP/doc-sync parity
- runtime/governance evidence cross-reference audit
- MCP smoke
- MCP compile-screen-doc config-path parity
- MCP structured invalid-input errors
- MCP structured unknown-tool errors
- MCP preview path validation
- MCP preview occupied-port validation
- MCP preview port parsing/range validation

### Audit tests
- doc link existence
- schema/example mismatch
- missing referenced files
- stale generated-doc region
- stale generated fragment source export
- stale exported contract view
- runtime/governance evidence ref mismatch
- command presence
- CLI exit code policy

## 4. Recommended host-app tests

### iOS
- SnapshotTesting for generated screens
- XCUITest for critical flows

### Android
- screenshot tests
- instrumentation tests for critical flows

## 5. Definition of done

### Screen-level done

하나의 screen에 대해 아래가 모두 만족되면 done이다.

- screen-doc 존재
- screen-spec 존재
- validation pass
- html preview 생성
- swiftui artifact 생성
- compose artifact 생성
- manifest 생성
- docs와 examples 정합성 유지

### Package-level done

- `login`이 end-to-end vertical slice로 통과
- `product-detail`이 같은 validate / generate 경로를 재사용
- CLI / MCP smoke tests 통과
- execution plan, task matrix, traceability, audit 문서가 최신 상태


# docs/14-self-review-and-improvements.md

# 14. Self Review and Improvements

이 문서는 설계 과정에서 스스로 발견한 문제와 그에 따른 개선을 기록한다.

## Iteration 1 — iOS 편향 문제

### 문제
초기 구조는 iOS 중심으로 보였고, Android가 부차적인 타깃처럼 보였다.

### 영향
계약과 generator가 SwiftUI 사고방식에 잠식될 위험이 있었다.

### 개선
- Android를 first-class target으로 명시
- 모든 핵심 도식에 iOS + Android + HTML을 동시에 표기
- Compose generator를 architecture 중심축에 포함

### 결과
문서와 구현 계획이 두 플랫폼을 동등하게 다루게 되었다.

## Iteration 2 — toolchain 과다 문제

### 문제
Node/TypeScript/Style Dictionary/별도 token compiler 등 선택지가 너무 많았다.

### 영향
실행보다 조합 논의가 더 커질 위험이 있었다.

### 개선
- v1 core path를 Swift-only로 축소
- external adapter를 core path 밖으로 이동
- HTML preview를 기본 review path로 고정

### 결과
설계가 훨씬 짧고 이해하기 쉬워졌다.

## Iteration 3 — source of truth 과다 문제

### 문제
screen-doc / intent spec / screen spec / preview spec / native spec 등 너무 많은 canonical 문서를 둘 위험이 있었다.

### 영향
에이전트가 어느 파일을 수정해야 하는지 모호해진다.

### 개선
canonical machine contract를 ScreenSpec 하나로 고정했다.

### 결과
수정 경로가 단순해졌다.

## Iteration 4 — MCP 과대평가 문제

### 문제
MCP가 시스템의 본체처럼 여겨질 수 있었다.

### 영향
CLI와 MCP에 중복 로직이 생긴다.

### 개선
CLI canonical, MCP thin adapter 원칙을 명시했다.

### 결과
interface layer가 단순해졌다.

## Iteration 5 — preview ambiguity 문제

### 문제
Penpot / Pencil / HTML이 모두 동등한 preview 후보처럼 보였다.

### 영향
review path가 흔들린다.

### 개선
HTML만 canonical review path로 남기고 나머지는 optional adapter로 강등했다.

### 결과
사람과 에이전트의 review workflow가 명확해졌다.

## Final self-assessment

### 무엇이 좋아졌는가
- source of truth 축소
- iOS/Android 대칭성 강화
- toolchain 축소
- review path 명확화
- CLI/MCP 역할 분리

### 아직 남은 제한
- advanced component catalog 미포함
- animation / navigation graph 미포함
- host integration sample code 미포함
- multi-screen orchestration 미포함

이 제한은 의도적이다.
현재 문서의 목표는 breadth가 아니라 **완결성과 무결성**이다.


# docs/15-risks-and-mitigations.md

# 15. Risks and Mitigations

## 1. ScreenSpec complexity creep

### Risk
component 종류가 늘어나며 ScreenSpec이 사실상 또 다른 UI DSL이 될 수 있다.

### Mitigation
- catalog gate 도입
- breaking change review 필요
- 새 component는 3개 renderer + validator + tests + docs 동시 업데이트 강제

## 2. Generator drift between platforms

### Risk
SwiftUI와 Compose 출력이 점점 다른 의미를 갖게 된다.

### Mitigation
- shared mapping table 유지
- cross-platform golden review
- HTML preview를 semantic baseline으로 사용

## 3. Token misuse

### Risk
raw literals가 ScreenSpec에 들어온다.

### Mitigation
- validator에서 차단
- examples에서 금지 사례 명시
- agent prompt에서 token alias 강제

## 4. Overuse of adapters

### Risk
Penpot/Pencil이 core path를 침범한다.

### Mitigation
- adapter boundary 문서화
- source of truth hierarchy 명시
- CI path에서 adapter 비필수화

## 5. CLI instability

### Risk
명령어나 JSON output shape가 자주 바뀌면 에이전트 호환성이 무너진다.

### Mitigation
- command stability policy
- versioned output schema
- contract tests

## 6. Documentation rot

### Risk
문서와 examples, schemas가 서로 어긋난다.

### Mitigation
- `audit` command
- integrity checklist
- CI에서 docs/example/schema 정합성 검사


# docs/16-references.md

# 16. References

아래는 기술 선택과 에이전트 인터페이스 결정을 뒷받침하는 주요 공식 자료다.

1. OpenAI Codex MCP  
   https://developers.openai.com/codex/mcp/

2. OpenAI Codex AGENTS.md guide  
   https://developers.openai.com/codex/guides/agents-md/

3. Anthropic Claude Code MCP  
   https://docs.anthropic.com/en/docs/claude-code/mcp

4. Anthropic Claude Code overview / headless  
   https://docs.anthropic.com/en/docs/claude-code/overview  
   https://docs.anthropic.com/en/docs/claude-code/headless

5. Gemini CLI docs  
   https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli

6. MCP Swift SDK  
   https://github.com/modelcontextprotocol/swift-sdk

7. MCP Rust SDK  
   https://github.com/modelcontextprotocol/rust-sdk

8. Swift ArgumentParser  
   https://github.com/apple/swift-argument-parser

9. SwiftUI docs  
   https://developer.apple.com/documentation/swiftui

10. Jetpack Compose docs  
    https://developer.android.com/develop/ui/compose/documentation

11. Compose Material 3 docs  
    https://developer.android.com/develop/ui/compose/designsystems/material3

12. DTCG Format Module draft  
    https://www.designtokens.org/tr/drafts/format/

13. Penpot Design Tokens  
    https://help.penpot.app/user-guide/design-systems/design-tokens/

14. Penpot Self-hosting guide  
    https://help.penpot.app/technical-guide/getting-started/

15. Pencil AI Integration  
    https://docs.pencil.dev/getting-started/ai-integration

16. Pencil CLI  
    https://docs.pencil.dev/for-developers/pencil-cli


# docs/17-host-integration-guides.md

# 17. Host Integration Guides

## 1. iOS host app integration

### 권장 구조
```text
apps/ios/
  App/
  DesignSystem/
  GeneratedUI/
  SnapshotTests/
  UITests/
```

### 통합 규칙
- `GeneratedUI`는 generated source만 가진다.
- `DesignSystem`은 사람이 유지한다.
- generator는 `DesignSystem` symbol을 소비하도록 설계한다.
- generated UI는 app logic을 몰라야 한다.
- generated `State` / `Actions` / `Navigation` surface는 `ScreenSpec.stateFields` / `ScreenSpec.actions` / `ScreenSpec.navigation` 에서 결정된다.
- action과 navigation은 callback / coordinator / view model injection으로 연결한다.

### 최소 연결 방식
1. generated `LoginScreen.swift` 추가
2. generated `LoginScreenState`를 app state에 연결
3. `DesignTokens.swift` 를 host target에 포함하고 native `Color` / `CGFloat` token으로 사용
4. `LoginScreenActions`를 app action에 연결
5. 필요한 screen이면 generated `...Navigation` surface를 router/coordinator에 연결
6. compile-backed host smoke를 추가

이 저장소의 최소 smoke pack은 `integration/ios/LoginHostScreen.swift`,
`integration/ios/ProductDetailHostScreen.swift` 에 있다.
source-owned evidence snapshot은 `audit/evidence/integration/ios-host-smoke.json` 에 기록한다.
테스트는 fresh generated SwiftUI에서 host-facing adapter surface를 추린 뒤
이 wrapper와 함께 `swiftc -typecheck` 해서 generated adapter가 host-owned
code에서 바로 소비되는지 확인한다.
이 evidence 파일은 최소한 `artifactId`, `artifactType`, `platform`, `status`,
`requiredCapability`, `doctorEvidence`, `wrapperSources`, `verification`, `notes` 를 가져야 한다.
preflight로 `dsctl doctor --json` 의 `ios_host_smoke` 가 `true` 인지 먼저 본다.

## 2. Android host app integration

### 권장 구조
```text
apps/android/
  app/
  designsystem/
  generatedui/
  host-smoke/
  ui-tests/
```

### 통합 규칙
- generatedui는 generated compose만 가진다.
- designsystem은 사람이 유지한다.
- action과 navigation binding은 lambda / interface / viewmodel injection으로 처리한다.
- generated `State`는 viewmodel 또는 screen state holder와 연결한다.
- generated `State` / `Actions` / `Navigation` surface는 `ScreenSpec.stateFields` / `ScreenSpec.actions` / `ScreenSpec.navigation` 에서 결정된다.
- generated `DesignTokens.kt` 는 native `Color` / `Dp` token을 제공하므로 host theme bridge에서 직접 소비할 수 있다.
- generated files는 app module에 직접 섞지 않는다.

이 저장소의 최소 smoke pack은 `integration/android/LoginHostScreen.kt`,
`integration/android/ProductDetailHostScreen.kt` 에 있다.
현재 repository test는 fresh generated Compose 화면을 host-facing surface로 distill한 뒤
wrapper와 함께 `kotlinc` 로 compile-backed smoke를 수행한다.
즉 `State` / `Actions` / `Navigation` surface가 host-owned code에서 실제로 compile되는지를 source-owned evidence로 남긴다.
source-owned evidence snapshot은 `audit/evidence/integration/android-host-smoke.json` 에 기록한다.
preflight로 `dsctl doctor --json` 의 `android_host_smoke` 와 `toolchains` 를 본다.
`android_renderer=true` 는 Compose source generation 가능 여부일 뿐이고,
compile-backed smoke readiness는 `android_host_smoke` 로 따로 판단한다.
integration evidence는 `doctorEvidence` 로 `audit/evidence/runtime/doctor.json` snapshot을 참조한다.

## 3. Preview integration

preview는 human review artifact다.
배포 앱의 runtime과 동일할 필요는 없지만 semantic 구조는 같아야 한다.

## 4. Optional Visual Regression Strategy

### iOS
- 대표 screen 1: login
- 대표 screen 2: product-detail
- light / dark
- dynamic type optional

### Android
- 대표 screen 1: login
- 대표 screen 2: product-detail
- phone width baseline
- tablet width optional


# docs/18-a-to-z-onboarding.md

# 18. A-to-Z Onboarding

이 문서는 새로운 개발자나 새로운 에이전트가 현재 저장소를 **핵심기능 완성 프로그램** 으로 이해하고, 같은 기준으로 구현과 검증을 시작할 수 있게 만든 실전 순서 문서다.

## 1. 목표 이해

- 이 시스템의 목표는 ScreenSpec 중심의 deterministic native UI generation이다.
- 완성 기준은 문서 정합성만이 아니라 **핵심기능 acceptance set이 lossless contract와 platform parity로 동작하는 것** 이다.

## 2. 먼저 읽을 문서

1. `README.md`
2. `MASTER_BLUEPRINT.md`
3. `docs/11-execution-plan.md`
4. `docs/12-task-matrix.md`
5. `docs/20-traceability-matrix.md`
6. `docs/23-authoritative-source-architecture.md`
7. `docs/24-authoritative-source-execution-plan.md`
8. `docs/25-authoritative-source-task-matrix.md`
9. `docs/07-cli-and-mcp-spec.md`
10. `docs/19-code-module-map.md`
11. `docs/21-integrity-audit.md`

canonical planning reread evidence는 `audit/evidence/planning/reread-checklist.json` 에 남긴다.

## 3. baseline 명령 확인

아래 네 명령이 현재 출발점을 가장 빠르게 보여준다.

```bash
swift run dsctl doctor --json
swift test
swift run ds-doc-sync sync --project-root . --json
swift run dsctl audit --project-root . --json
swift run dsctl generate --config examples/configs/dsctl.config.json --screen-id login --json
```

이 다섯 명령은 출발점 증명이다. `doctor` 는 generator capability와 host-smoke readiness를 분리해서 보여주므로,
특히 Android compile-backed smoke를 기대할 때 `android_host_smoke` 와 `toolchains` 를 먼저 확인한다.
완성 검증에서는 여기에 acceptance fixture 전부에 대한 `generate-bundle` 과 parity/integration 검사가 추가된다.
acceptance artifact를 읽을 때는 `verification` 이 canonical command quartet를 모두 포함하는지,
`reviewSurface`, `generatedManifest`, `hostEvidence`, `blockingHostEvidence` 가 같은 slice를 가리키는지 같이 본다.

## 4. examples 확인

현재 기준 examples:

- `examples/screen-doc/login.md`
- `examples/screens/login.screen.json`
- `examples/screen-doc/product-detail.md`
- `examples/screens/product-detail.screen.json`
- `examples/tokens/core.tokens.json`
- `examples/catalogs/component-catalog.json`
- `examples/configs/dsctl.config.json`

completion target examples:

- `login`
- `product-detail`
- `checkout`

## 5. 스스로 답해야 하는 질문

- authoritative source는 무엇인가?
- generated code를 수정해도 되는가?
- core acceptance set의 상태와 상호작용은 어디에서 정의되는가?
- HTML preview의 역할은 무엇인가?
- iOS와 Android는 무엇을 공유하고 무엇을 공유하지 않는가?
- compile 결과가 lossless contract가 아니면 어디서 실패해야 하는가?
- starter spec과 completion report는 어디에 남고 무엇을 의미하는가?
- complete `screen-doc` 를 만들려면 `State Fields`, `Actions`, `Assets`, `Preview States`, `Navigation`, `Component Details` section에 무엇을 적어야 하는가?

## 6. 현재 변경 시작 순서

1. `docs/12-task-matrix.md` 의 우선순위와 status를 먼저 본다.
2. `docs/20-traceability-matrix.md` 에서 어떤 requirement를 닫는 변경인지 고정한다.
3. compiler/contract 작업이면 `docs/03`, `docs/11`, `docs/23`, `meta/runtime/contracts.cue`, schema/examples를 같이 본다.
4. review/integration 작업이면 `docs/09`, `docs/17`, `docs/24`, `docs/25`, bundle output과 smoke tests를 같이 본다.
   현재 iOS smoke wrapper source는 `integration/ios/` 에 있다.
   현재 Android smoke wrapper source는 `integration/android/` 에 있다.
5. generated section drift면 `meta/views/governance.fragments.json` 을 수정하고 `ds-doc-sync sync` 를 실행한다.
6. 마지막에 baseline 네 명령과 acceptance suite를 다시 실행한다.

## 7. 첫 번째 완성 목표

현재 첫 목표는 **세 개 acceptance fixture가 같은 계약 철학으로 닫히는지** 확인하는 것이다.

```text
login
  → form semantics / keyboard hints / route / validation
product-detail
  → media / card / CTA / navigation / rich content
checkout
  → multi-section form / summary / loading / error / disabled / success states
```

## 8. 첫 번째 실패 패턴

- raw literal 사용
- catalog 밖 component 사용
- generated code 수동 수정
- HTML preview를 건너뛰는 것
- acceptance fixture를 늘리기만 하고 capability contract를 먼저 고정하지 않는 것

## 9. 끝

이 저장소는 이미 동작하는 baseline을 가진다.
다음 단계는 baseline 유지가 아니라, 핵심기능 completion line까지 compiler, validator, generator, review, integration을 같은 계약으로 닫는 것이다.


# docs/19-code-module-map.md

# 19. Code Module Map

이 문서는 현재 구현 기준으로 어떤 파일과 타입이 어떤 책임을 가지는지 매핑한다.

## 1. DSCore

### `Models.swift`
- `Platform`
- `ScreenSpec`
- `ScreenSurface`
- `ScreenNode`
- `ComponentCatalog`
- `DSConfig`
- `ValidationIssue`
- `ValidationReport`
- `GenerateReport`
- `GenerateBundleReport`
- `Manifest`
- `AuditReport`

### `ConfigResolver.swift`
- `ResolvedDSConfig`
- config path resolution
- screen-doc / screen-spec / build output path derivation

### `ScreenDocCompiler.swift`
- front matter parsing
- screen-doc narrative normalization
- placeholder node emission
- compile warning production
- route/default platform handling

### `RuntimeContracts.swift`
- authoritative runtime root model
- limited CUE-like contract parsing
- CLI / MCP / doc-sync / exit-code default path contract loading
- contract view output path loading

### `GovernanceContracts.swift`
- authoritative governance root model
- generated docs inventory loading
- runtime/governance evidence cross-reference input for audit

### `ContractViewExportService.swift`
- authoritative runtime/governance root export to concrete JSON views
- exported contract view freshness verify
- `meta/views/runtime.contracts.json`, `meta/views/governance.contracts.json` emission

### `TokenCompiler.swift`
- token flatten
- alias resolution
- cycle detection
- deterministic ordering

### `Validator.swift`
- contract validations
- catalog restriction checks
- issue path formatting

### `Generator.swift`
- HTML render tree
- `tokens.css` emission
- preview index emission
- SwiftUI emission
- Compose emission
- manifest emission

### `ProjectService.swift`
- config loading
- compile / validate / generate / generate-bundle orchestration
- audit
- runtime-root aware doc-sync manifest resolution
- exported contract view freshness gate
- runtime/governance evidence cross-reference gate
- doc-sync freshness gate
- preview serve
- JSON encoding

### `JSONValue.swift`
- nested token JSON decoding helper

## 2. DSCLI

### `main.swift`
- root command
- subcommand registration
- shared JSON formatter
- `--config` aware path resolution

## 3. DSMCP / DSMCPKit

### `DSMCP/main.swift`
- stdio bootstrap only

### `DSMCPKit/ServerFactory.swift`
- tool metadata
- input schema exposure
- tool call to DSCore mapping

## 4. DSDocSync / DSDocSyncKit

### `DSDocSyncKit/FragmentExportService.swift`
- structured governance fragment export models
- markdown table fragment rendering
- deterministic fragment file emission

### `DSDocSyncKit/DocSyncService.swift`
- doc-sync manifest models
- inline or fragment-backed region content resolution
- generated markdown region render
- generated markdown freshness verify
- fragment export -> render -> verify sync orchestration
- JSON encoding for render/verify reports

### `DSDocSync/main.swift`
- `sync`
- `export-contracts`
- `export-fragments`
- `render`
- `verify`
- thin CLI wrapper for authoritative contract export + generated-region sync

## 5. Tests

### `ProjectServiceTests.swift`
- example validation
- deterministic generation
- audit baseline
- config resolution
- runtime/governance drift detection

### `DSCLISmokeTests.swift`
- CLI command surface
- exit code behavior
- compile / validate / generate / audit smoke

### `DSMCPServerTests.swift`
- `tools/list` smoke
- `tools/call` smoke

### `DocSyncServiceTests.swift`
- generated region render
- stale region detect
- checked-in manifest verify

### `FragmentExportServiceTests.swift`
- fragment spec render
- checked-in fragment export parity

### `DSDocSyncSmokeTests.swift`
- `sync`
- `export-contracts`
- `export-fragments`
- `render`
- `verify`

## 6. Recommended read / change order

1. Models
2. Config resolution
3. ScreenDocCompiler
4. TokenCompiler
5. Validator
6. Generator
7. ProjectService
8. CLI / DocSync / MCP adapters
9. Tests


# docs/20-traceability-matrix.md

# 20. Traceability Matrix

이 표는 요구사항이 어느 계약 문서, 예시, 실행 태스크, 검증 증거에 연결되는지 보여준다.
Task ID는 [12-task-matrix.md](12-task-matrix.md)를 기준으로 유지한다.
overall execution authority는 `11/12/20` 이고, `24/25` 는 authoritative-source workstream annex로 참조된다.
structured row source는 `meta/views/governance.fragments.json` 이고, 이 문서는 generated traceability view다.

<!-- GENERATED:BEGIN traceability-matrix-rows -->
| Requirement ID | Contract | Docs | Schema / Example | Primary Tasks | Verification Evidence |
|---|---|---|---|---|---|
| `REQ-01` | `ScreenSpec` 는 supported core screen을 explicit하게 표현하는 authoritative contract여야 한다. | `03`, `06`, `11`, `23` | `schemas/screen-spec.schema.json`, `examples/screens/*.screen.json` | `MODEL-01`, `DOC-01`, `VALIDATE-01` | schema diff, model tests, validation reports |
| `REQ-02` | `screen-doc` 는 사람의 intent source이고 `compile-screen-doc` 는 starter spec + completion report를 생성해야 한다. | `03`, `11`, `18` | `examples/screen-doc/*.md`, compile report shape | `AUTHOR-01`, `AUTHOR-02`, `E2E-01`, `E2E-02` | compile tests, starter-spec snapshots, completion reports |
| `REQ-03` | generation 전에 unresolved/ambiguous semantics를 반드시 차단해야 한다. | `11`, `13`, `20` | validation fixtures, enriched spec examples | `VALIDATE-01`, `VERIFY-01` | negative fixtures, validation JSON, smoke checks |
| `REQ-04` | SwiftUI / Compose / HTML은 상태, 액션, 네비게이션, media semantics를 같은 의미로 유지해야 한다. | `08`, `11`, `17` | enriched ScreenSpec examples | `GENERATE-01`, `REVIEW-01`, `INTEGRATE-01`, `INTEGRATE-02` | golden tests, generated artifacts, parity review |
| `REQ-05` | HTML preview는 declared preview state 전체의 canonical review surface여야 한다. | `09`, `11`, `18` | preview-enabled example specs | `REVIEW-01`, `E2E-01`, `E2E-02` | preview bundle, review checklist, acceptance report |
| `REQ-06` | generated file은 disposable이고 host logic은 generated adapter를 통해 연결되어야 한다. | `10`, `17`, `23` | generated adapter contract, host package layout | `INTEGRATE-01`, `INTEGRATE-02`, `VERIFY-01` | host compile logs, compile-backed smoke tests, guide reread |
| `REQ-07` | runtime/governance/doc-sync/audit는 확장된 contract와 evidence set의 authoritative source여야 한다. | `11`, `21`, `23`, `24`, `25` | `meta/runtime/contracts.cue`, `meta/governance/contracts.cue`, `meta/views/*.json` | `GOV-01`, `ASOT-01`, `VERIFY-01` | contract export verify, audit JSON, fragment freshness |
| `REQ-08` | `login` slice는 최종 form-flow completion을 증명해야 한다. | `11`, `18`, `22` | `examples/screen-doc/login.md`, `examples/screens/login.screen.json` | `E2E-01`, `VERIFY-01` | login acceptance report, generated artifacts, host smoke |
| `REQ-09` | `product-detail` slice는 최종 content/action completion을 증명해야 한다. | `11`, `18`, `22` | `examples/screen-doc/product-detail.md`, `examples/screens/product-detail.screen.json` | `E2E-02`, `VERIFY-01` | product-detail acceptance report, generated artifacts, host smoke |
| `REQ-10` | docs / schema / examples / prompts / audit artifact는 contract 변화와 함께 움직여야 한다. | `11`, `12`, `20`, `21`, `22`, `24`, `25` | 전체 문서 패키지, schemas, examples | `DOC-01`, `GOV-01`, `VERIFY-01` | integrity audit, doc-sync verify, updated artifacts, link scan |
| `REQ-11` | canonical execution plan은 하나여야 하며 workstream annex는 그 계획에 종속되어야 한다. | `11`, `12`, `18`, `20`, `24`, `25` | `meta/views/governance.fragments.json`, annex docs | `PLAN-01`, `ASOT-01` | rendered docs, reread checklist, link scan |
| `REQ-12` | final completion은 fresh end-to-end evidence로만 주장할 수 있어야 한다. | `11`, `12`, `21`, `22` | acceptance specs, audit artifacts | `VERIFY-01`, `E2E-01`, `E2E-02` | tests, audit JSON, doc-sync sync, host smoke logs |
<!-- GENERATED:END traceability-matrix-rows -->

## 사용법

contract나 completion plan이 바뀌면 아래를 반드시 업데이트한다.

1. `meta/views/governance.fragments.json` 의 relevant source row
2. 관련 task source row와 status
3. 관련 docs, schemas, examples, annex docs, verification evidence
4. `ds-doc-sync sync` 결과
5. `ALL_DOCS_COMBINED.md` 와 `audit/integrity-report.json` 갱신 여부


# docs/21-integrity-audit.md

# 21. Integrity Audit

## 목적

문서, schema, examples, prompts, manifest가 서로 어긋나지 않는지 확인한다.

## 감사 범위

- core files 존재 여부
- JSON parse 가능 여부
- schema validation 통과 여부
- markdown relative link 유효성
- generated doc freshness (`ds-doc-sync verify`)
- exported contract view freshness (`ds-doc-sync export-contracts` 기준)
- runtime/governance evidence cross-reference validity
- governance generated-doc inventory와 doc-sync manifest 일치 여부
- governance inventory가 가리키는 source-owned acceptance / integration artifact 존재 여부
- governance inventory가 가리키는 source-owned runtime doctor artifact 존재 여부
- governance inventory가 가리키는 source-owned planning reread checklist artifact 존재 여부
- acceptance / integration evidence artifact의 필수 field shape와 status 규칙
- planning reread checklist artifact의 필수 field shape와 canonical document coverage 규칙
- runtime / integration evidence의 `verification.testCase` 와 `verification.testSource` 가 실제 source-owned `@Test("...")` 선언과 맞는지
- runtime doctor evidence의 `verification.command` 가 `swift run dsctl doctor --json` 이고 integration evidence의 `verification.command` 가 `swift test` 인지
- integration evidence의 `verifiedOn` 이 referenced doctor snapshot 날짜와 맞는지, acceptance evidence의 `verifiedOn` 이 referenced host smoke 날짜와 맞는지
- acceptance artifact가 authoring input, review surface, host smoke evidence를 실제 경로로 참조하는지
- acceptance artifact의 `generatedManifest` 가 authoring spec / review surface / declared platform output과 맞는지
- acceptance artifact의 `hostEvidence` 가 referenced `ScreenSpec.platforms` 의 native coverage와 맞는지
- acceptance artifact의 `blockingHostEvidence` 가 non-pass host smoke evidence와 정확히 맞는지
- acceptance artifact의 `verification[*]` 가 canonical fresh-evidence command set과 같은 screen-specific generate command를 포함하는지
- acceptance artifact의 reviewed preview state와 checklist가 referenced spec / HTML review surface와 일치하는지
- integration artifact의 `requiredCapability` / `doctorEvidence` 가 runtime doctor snapshot과 일치하는지
- runtime doctor artifact가 현재 머신의 `dsctl doctor --json` 결과와 drift 없는지
- planning ledger(`meta/views/governance.fragments.json`) 의 `INTEGRATE-01`, `INTEGRATE-02`, `E2E-01`, `E2E-02`, `VERIFY-01`, `P5`, `P7` status가 source-owned evidence 상태와 일치하는지
- manifest 생성 여부

가장 싼 복구 경로는 보통 `ds-doc-sync sync --project-root . --json` 이다.
이 명령은 contract view export, fragment export, region render, freshness verify 를 한 번에 다시 맞춘다.

## 기대 결과

모든 핵심 파일이 존재하고, examples가 schema를 만족하며, 문서 링크가 깨지지 않고 generated region이 source와 일치해야 한다.
또한 governance evidence ref가 runtime evidence key와 어긋나지 않아야 하고,
governance inventory가 선언한 generated docs / authoritative roots / acceptance artifacts / integration artifacts 가 실제 경로를 가리켜야 한다.

## 자동 감사 산출물

실제 자동 감사 JSON 결과는 다음 파일에 기록한다.

- `audit/integrity-report.json`
- `MANIFEST.json`
- `audit/evidence/integration/ios-host-smoke.json`
- `audit/evidence/integration/android-host-smoke.json`
- `audit/evidence/runtime/doctor.json`
- `audit/evidence/planning/reread-checklist.json`
- `audit/evidence/acceptance/login.json`
- `audit/evidence/acceptance/product-detail.json`

## 수동 확인 체크리스트

1. `README.md` 링크가 실제 문서로 이동하는가
2. execution plan, task matrix, traceability가 같은 canonical 이름과 task id를 사용하는가
3. examples가 docs에서 설명한 구조와 일치하는가
4. schemaVersion이 모두 `1.0`인가
5. screen-spec examples가 `["ios", "android", "html"]`를 포함하는가
6. prompts가 upstream-fix 정책을 따르는가

## 해석 원칙

audit는 문서의 완벽함 자체를 보장하지는 않는다.
그러나 최소한 **구조적 무결성**과 **참조 무결성**을 보장한다.


# docs/22-validation-report.md

# 22. Validation Report

## 목적

이 문서 패키지가 실제 구현 출발점으로 사용될 수 있는지 판단하기 위한 검증 기준을 정의한다.

## 검증 항목

### 1. 문서 검증
- 주요 의사결정 문서 존재
- README 진입점 존재
- onboarding 문서 존재
- execution plan 존재
- task matrix 존재
- traceability 문서 존재
- self-review 문서 존재

### 2. 계약 검증
- ScreenSpec schema 존재
- ComponentCatalog schema 존재
- Config schema 존재

### 3. 예시 검증
- login screen-doc 존재
- product-detail screen-doc 존재
- login ScreenSpec 존재
- product-detail ScreenSpec 존재
- token examples 존재
- catalog example 존재
- config example 존재

### 4. 실행 준비도 검증
문서만 보고 아래를 구현 가능해야 한다.
- repo skeleton
- models
- token resolver
- validator
- generators
- CLI
- MCP
- tests
- host integration

### 5. 증거 검증
- governance root가 acceptance artifact inventory를 가진다
- governance root가 integration smoke artifact inventory를 가진다
- governance root가 runtime doctor artifact inventory를 가진다
- governance root가 planning reread checklist artifact inventory를 가진다
- acceptance report가 canonical screen별로 source-owned path에 존재한다
- host smoke evidence가 iOS / Android 각각 source-owned path에 존재한다
- runtime doctor evidence가 source-owned path에 존재한다
- planning reread checklist evidence가 source-owned path에 존재한다
- evidence artifact의 `status`, `knownGap`, `residualGaps` 규칙이 맞다
- planning reread checklist artifact가 canonical planning doc set을 모두 포함한다
- runtime / integration evidence의 `verification.testCase` 와 `verification.testSource` 가 실제 `@Test("...")` 선언과 line anchor를 가리킨다
- runtime doctor evidence의 `verification.command` 가 `swift run dsctl doctor --json` 이고 integration evidence의 `verification.command` 가 `swift test` 다
- integration evidence의 `verifiedOn` 이 doctor snapshot 날짜와 맞고 acceptance evidence의 `verifiedOn` 이 referenced host smoke 날짜와 맞다
- acceptance report의 `generatedManifest` 가 authoring spec / review surface / declared platform output과 맞다
- acceptance report의 `hostEvidence` 가 referenced `ScreenSpec.platforms` 의 native coverage를 덮는다
- acceptance report의 `blockingHostEvidence` 가 non-pass host smoke artifact와 맞다
- acceptance report의 `verification[*]` 가 `swift test`, `ds-doc-sync sync`, `dsctl audit`, 그리고 같은 `screenId` 의 `dsctl generate` 명령을 포함한다
- acceptance report의 `review.reviewedPreviewStates` 와 `review.checklist` 가 spec / HTML review surface와 맞다
- integration evidence의 `requiredCapability` 와 `doctorEvidence` 가 runtime doctor snapshot과 맞다
- runtime doctor evidence가 현재 머신의 `dsctl doctor --json` 결과와 맞다
- planning ledger의 `INTEGRATE-*`, `E2E-*`, `VERIFY-01`, `P5`, `P7` status가 referenced evidence status와 맞다

## 기준

### Pass
- 문서, schema, example, prompts, audit artifacts가 모두 존재
- example JSON이 schema를 만족
- 문서 링크가 깨지지 않음
- governance inventory가 doc-sync manifest와 source-owned evidence 파일을 모두 추적함
- evidence artifact가 typed contract로 parse되고 cross-reference가 유효함
- planning reread checklist artifact가 canonical planning package를 빠뜨리지 않음
- runtime / integration evidence가 실제 source-owned test declaration까지 역참조 가능함
- runtime / integration evidence가 canonical verification command를 유지함
- integration / acceptance evidence가 referenced supporting artifact와 같은 verification date를 유지함
- acceptance artifact가 generated manifest와 generated platform coverage를 빠뜨리지 않음
- acceptance artifact가 referenced native platform coverage를 빠뜨리지 않음
- acceptance artifact status가 referenced host smoke status와 충돌하지 않음
- acceptance artifact가 canonical fresh-evidence command set을 빠뜨리지 않음
- acceptance review evidence가 declared preview states와 required review checklist domains를 모두 덮음
- runtime doctor snapshot이 host smoke readiness와 toolchain invariants를 유지함
- runtime doctor snapshot이 stale local capability snapshot이 아님
- planning/task status가 source-owned evidence보다 앞서 나가지 않음

### Fail
- schema/example mismatch
- broken doc links
- missing canonical files

## 실제 자동 결과

실제 자동 결과는 `audit/integrity-report.json`을 참조한다.
canonical acceptance artifact는 `audit/evidence/acceptance/*.json`,
host smoke artifact는 `audit/evidence/integration/*.json`,
runtime doctor artifact는 `audit/evidence/runtime/doctor.json`,
planning reread artifact는 `audit/evidence/planning/reread-checklist.json` 을 참조한다.


# docs/23-authoritative-source-architecture.md

# 23. Authoritative Source Architecture

## 1. Decision

이 저장소의 authoritative-source 시스템은 **authoring contract roots + runtime root + governance root + planning view source** 의 조합으로 고정한다.
즉, 최종 completion까지 source는 아래 네 층으로 닫는다.

- `schemas/*`, `examples/*`, `docs/03`, `docs/06`, `docs/08`, `docs/17`
- `meta/runtime/contracts.cue`
- `meta/governance/contracts.cue`
- `meta/views/governance.fragments.json`

이 조합의 목적은 **authoring, runtime interface, governance evidence, planning ledger** 를 서로 다른 책임으로 분리하면서도 `ds-doc-sync` 와 `audit` 로 하나의 검증 경로를 유지하는 것이다.

## 2. Problem Statement

완성된 product는 자연어 해석의 우연성에 의존하면 안 된다.
핵심기능이 실제로 돌아가려면 아래 네 층이 각각 명확한 ownership을 가져야 한다.

- authoring contract: 사람이 무엇을 쓰고, `ScreenSpec` 이 무엇을 담아야 하는가
- runtime contract: CLI/MCP/doc-sync/audit 가 어떤 machine-readable surface를 가지는가
- governance contract: 어떤 docs/views/evidence/artifact가 completion claim을 구성하는가
- planning contract: 어떤 phase/task/traceability row가 delivery를 통제하는가

## 3. Current authoritative layers

### 3.1 Authoring contract roots

authoring contract roots는 아래를 가진다.

- `ScreenSpec` schema
- component catalog / config schema
- example screen-doc / screen-spec / token / catalog / config
- source-of-truth / data-model / generation / host-integration docs

이 층은 사람이 작성하거나 검토하는 계약 입력의 semantics를 소유한다.
핵심 규칙은 하나다.

- `screen-doc` 는 intent source다.
- authoritative execution contract는 완성된 `ScreenSpec` 이다.
- `compile-screen-doc` 는 starter spec과 completion report를 만들 수 있지만, unresolved output은 generation 단계로 들어가면 안 된다.

### 3.2 Runtime root

`meta/runtime/contracts.cue` 는 아래를 가진다.

- CLI command 목록
- MCP tool 목록
- doc-sync command 목록
- evidence key
- `doctor` capability / toolchain field set
- exported contract view path
- exit code
- integration / review / report surface name

이 root는 runtime surface의 선언 계약이다.

### 3.3 Governance root

`meta/governance/contracts.cue` 는 아래를 가진다.

- generated docs inventory
- authoritative root inventory
- runtime/governance evidence reference set
- runtime doctor artifact inventory
- planning reread checklist artifact inventory
- integration smoke artifact inventory
- acceptance artifact inventory

이 root는 package-level governance inventory와 audit cross-reference 입력을 가진다.
즉, `generatedDocs`, `authoritativeRoots`, `evidenceRefs` 뿐 아니라
source-owned `runtimeArtifacts`, `planningArtifacts`, `integrationArtifacts`, `acceptanceArtifacts` registry도 여기서 닫는다.

### 3.4 Planning view source

`meta/views/governance.fragments.json` 는 아래를 가진다.

- execution plan critical path
- task matrix row
- decision gate
- traceability row
- ownership boundary table

이 층은 master plan과 workstream annex table을 사람이 읽을 수 있는 generated ledger로 유지한다.
또한 integration / acceptance evidence가 partial 인데 task row가 `Done` 으로 앞서 나가는 식의 planning drift도 audit로 막는다.

## 4. Ownership boundary

<!-- GENERATED:BEGIN ownership-boundary-table -->
| Layer | Owns | Must not own |
|---|---|---|
| authoring contract roots | `ScreenSpec` schema, component catalog/config schema, example inputs, authoring semantics, completion-report rules | exit codes, audit evidence registry, phase/task sequencing |
| runtime root | CLI command, MCP tool, input contract, output path, exit code, evidence key | task priority, decision gate prose, roadmap sequencing |
| governance root | generated-doc inventory, authoritative-source inventory, evidence references, runtime/planning/integration/acceptance artifact registry | renderer behavior, task rows, schema field definitions |
| planning view source | execution-plan rows, task rows, decision gates, traceability rows, annex structure | runtime command truth, schema semantics, generator algorithms |
<!-- GENERATED:END ownership-boundary-table -->

`runtime root` 표기는 audit/doc-sync freshness regression과 operational contract 설명에서 공통으로 쓰는 compact label이다.

## 5. Render and verify pipeline

현재 권장 파이프라인은 아래 순서다.

```text
schemas/*
examples/*
docs/03 + docs/06 + docs/08 + docs/17
meta/runtime/contracts.cue
meta/governance/contracts.cue
meta/views/governance.fragments.json
  -> swift run ds-doc-sync export-contracts
  -> swift run ds-doc-sync export-fragments
  -> swift run ds-doc-sync render
  -> swift run ds-doc-sync verify
  -> swift test
  -> dsctl audit
```

여기서 `ds-doc-sync` 는 source가 아니라 **contract view / fragment / generated doc bridge** 다.

역할:

- contract root를 concrete JSON view로 export 한다
- structured planning source를 markdown fragment로 export 한다
- 지정된 markdown region만 교체한다
- 현재 문서가 stale이면 non-zero로 실패한다

freshness는 generated view와 rendered content comparison으로 판정한다.

## 6. Annex relationship

- `11`, `12`, `20` 은 전체 completion control plane이다.
- `24`, `25` 는 authoritative-source 전용 workstream annex다.
- annex는 subordinate workstream이지만, source ownership/evidence 정렬이 필요한 핵심축이므로 별도 문서로 유지한다.
- annex가 있어도 execution authority는 `11`, `12`, `20` 에 남는다.

## 7. Final rule

authoritative path에서 heuristic convenience와 execution contract를 혼동하면 안 된다.
starter spec은 중간 산출물일 수 있지만, generation과 integration은 항상 **complete `ScreenSpec` + fresh evidence** 위에서만 성립해야 한다.


# docs/24-authoritative-source-execution-plan.md

# 24. Authoritative Source Completion Plan

## 1. Status

이 문서는 `11-execution-plan.md` 에 종속된 active workstream annex다.
전체 우선순위와 completion gate는 `11/12/20` 이 소유하고, 이 문서는 authoritative-source 축의 세부 실행 경로를 정의한다.

## 2. Workstream objective

목표는 간단하다.
최종 핵심기능에서 필요한 모든 계약과 증거가 **source-owned artifact** 로 존재하게 만드는 것이다.

즉, 아래 네 가지를 prose가 아니라 source로 닫는다.

1. authoring contract
2. runtime command/evidence contract
3. governance inventory/evidence contract
4. planning/task/traceability ledger

## 3. Observable done condition

1. authoring contract roots가 상태, 액션, 네비게이션, asset, preview state semantics를 명시적으로 가진다.
2. runtime root가 final core workflow에 필요한 command/evidence/output contract를 모두 가진다.
3. governance root가 generated docs, annex docs, acceptance artifacts, evidence refs를 모두 가진다.
4. `11`, `12`, `20`, `23` 의 generated section과 annex docs가 같은 source/evidence set을 본다.
5. audit와 doc-sync가 새 contract/evidence set을 자동으로 검증한다.
6. `login`, `product-detail` acceptance evidence가 governance path에서 추적 가능하다.

## 4. Phases

<!-- GENERATED:BEGIN authoritative-source-execution-plan-phases -->
| Phase | Status | Objective | Depends On | Exit evidence |
|---|---|---|---|---|
| A0 | Done | baseline authoritative roots와 final target 간 gap을 동결한다 | none | source inventory와 gap list가 `11/12/20/23/24/25`에 반영된다 |
| A1 | Done | authoring contract roots를 final core semantics에 맞게 확장한다 | A0 | schema/docs/examples가 state/action/navigation/asset/preview contract를 명시한다 |
| A2 | Done | runtime/governance roots를 expanded evidence/output contract로 확장한다 | A1 | exported contract views와 audit checks가 새 fields/evidence key를 가진다 |
| A3 | Done | planning fragments, generated docs, annex docs를 같은 source 체계로 정렬한다 | A2 | `11`, `12`, `20`, `23`, `24`, `25` 가 같은 terms/task/evidence를 사용한다 |
| A4 | Done | host integration evidence를 source-owned artifact로 편입한다 | A2 | iOS/Android integration smoke evidence가 governance inventory에 등록되고 compile-backed smoke로 검증된다 |
| A5 | Done | canonical slice acceptance evidence를 freeze 한다 | A3, A4 | `login`, `product-detail` acceptance artifact가 traceability와 audit에 연결되고 pass 상태로 유지된다 |
<!-- GENERATED:END authoritative-source-execution-plan-phases -->

## 5. Coordination rules

- schema/model 작업은 `MODEL-01` 과 동기화한다.
- compile/report 작업은 `AUTHOR-01`, `AUTHOR-02` 와 동기화한다.
- audit/doc-sync/evidence 작업은 `GOV-01` 과 동기화한다.
- annex task는 `12` 의 master task를 복제하지 않고, source/evidence 전용 세부 단위만 가진다.

## 6. Current residual

- planning package reread evidence는 `audit/evidence/planning/reread-checklist.json` 에 source-owned artifact로 남긴다.
- 현재 checked-in baseline은 `audit/evidence/runtime/doctor.json` 기준 `android_host_smoke=true` 를 만족하고, Android compile-backed host smoke evidence도 `pass` 상태로 고정돼 있다.
- host integration evidence와 canonical acceptance evidence는 모두 source-owned artifact로 등록되어 있고 현재 `pass` 상태다.

## 7. Final rule

authoritative-source workstream은 문서를 더 예쁘게 만드는 작업이 아니다.
최종 completion claim이 source와 evidence로 재현 가능하도록 만드는 작업이다.


# docs/25-authoritative-source-task-matrix.md

# 25. Authoritative Source Task Matrix

이 문서는 `24` 와 짝을 이루는 active workstream task matrix다.
전체 status authority는 `12-task-matrix.md` 에 있고, 여기서는 authoritative-source 전용 세부 task만 관리한다.

<!-- GENERATED:BEGIN authoritative-source-task-matrix-rows -->
| Task ID | Status | Priority | Action | Depends On | Done when | Evidence |
|---|---|---|---|---|---|---|
| ASOT-00 | Done | P0 | baseline runtime/governance roots와 doc-sync export/render/verify path를 유지한다 | none | checked-in roots와 generated views가 fresh 하다 | `ds-doc-sync sync`, exported views, audit JSON |
| ASOT-01 | Done | P0 | authoring contract roots가 state/action/navigation/asset/preview semantics를 명시하도록 확장한다 | ASOT-00 | schema/docs/examples가 final core semantics를 source-owned field로 가진다 | schema diff, updated docs, example specs |
| ASOT-02 | Done | P0 | runtime root에 expanded command/evidence/output contract를 반영한다 | ASOT-01 | exported runtime view가 final core workflow surface를 포함한다 | `meta/runtime/contracts.cue`, exported runtime view, smoke tests |
| ASOT-03 | Done | P0 | governance root에 acceptance artifact inventory와 evidence ref를 추가한다 | ASOT-01 | exported governance view가 docs, annexes, acceptance artifacts를 추적한다 | `meta/governance/contracts.cue`, exported governance view |
| ASOT-04 | Done | P1 | planning fragments가 final completion gates/traceability/ownership boundary를 유지하도록 확장한다 | ASOT-02, ASOT-03 | `11`, `12`, `20`, `23`, `24`, `25` generated section이 같은 terms/evidence를 사용한다 | fragment source, rendered docs, doc-sync manifest |
| ASOT-05 | Done | P0 | audit와 doc-sync verify가 새 contract/evidence set을 자동으로 검증하도록 확장한다 | ASOT-02, ASOT-03, ASOT-04 | stale contract/doc/evidence drift가 자동으로 감지된다 | audit checks, doc-sync verify, failing fixtures |
| ASOT-06 | Done | P1 | iOS/Android host integration evidence를 governance inventory에 편입한다 | ASOT-03 | integration smoke output이 source-owned artifact로 추적된다 | host smoke logs, inventory update |
| ASOT-07 | Done | P0 | `login`, `product-detail` acceptance evidence를 traceable artifact로 등록한다 | ASOT-05, ASOT-06 | 두 canonical slice의 acceptance artifact가 traceability와 validation docs에 연결된다 | acceptance reports, traceability rows |
| ASOT-08 | Done | P0 | final completion 직전 authoritative-source freeze를 수행한다 | ASOT-07 | contract views, fragments, docs, annexes, audit artifacts가 모두 fresh 하다 | `ds-doc-sync sync`, `dsctl audit`, reread checklist |
<!-- GENERATED:END authoritative-source-task-matrix-rows -->

## Coordination rule

- `ASOT-*` 는 `12` 의 master task를 대체하지 않는다.
- master task가 “무엇을 완성할지”를 말하면, `ASOT-*` 는 “그 completion claim을 어떤 source/evidence로 고정할지”를 말한다.
- planning package reread evidence는 `audit/evidence/planning/reread-checklist.json` 에서 관리한다.
- 현재 freeze gate는 compile-backed iOS/Android host smoke, fresh doc-sync/audit, reread checklist로 닫혀 있다.


# prompts/review-and-fix.md

# Review and Fix Prompt

입력:
- screen-doc
- screen-spec
- validation report
- html preview screenshot 또는 html path

출력:
- upstream fix proposal only

규칙:
- generated swiftui/compose/html 파일을 직접 수정하라고 제안하지 않는다.
- 수정은 screen-spec / tokens / catalog에서만 제안한다.


# prompts/spec-generation.md

# Spec Generation Prompt

목표: screen-doc를 읽고 ScreenSpec JSON만 출력한다.

규칙:
- JSON 외의 텍스트를 출력하지 않는다.
- component kind는 catalog에 있는 것만 사용한다.
- spacing / surface style은 raw literal이 아니라 token alias를 사용한다.
- 하나의 primary action만 유지한다.
- 장식적 요소를 invent하지 않는다.
- platform-specific field를 넣지 않는다.
