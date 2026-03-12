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
