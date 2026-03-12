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
