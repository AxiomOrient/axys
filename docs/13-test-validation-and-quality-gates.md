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
