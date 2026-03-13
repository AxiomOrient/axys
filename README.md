# Mobile Design Automation

이 저장소는 Swift 6 + SPM 기반의 design-system control plane이다. 공식 방향은 `contracts/*` 를 기준으로 validate, review, native generation, evidence를 닫는 contract-first 운영이다.

핵심 파이프라인은 아래로 고정한다.

```text
contracts/* + schemas/current
  -> validate
  -> DesignIR
  -> PreviewApp review bundle
  -> SwiftUI / Compose generation
  -> adapter export
  -> HostApps runtime proof
  -> audit evidence
```

작업 기준 문서는 아래만 읽는다.

## 권장 읽기 순서

1. [MASTER_BLUEPRINT.md](MASTER_BLUEPRINT.md)
2. [0001-authoritative-contracts.md](docs/adr/0001-authoritative-contracts.md)
3. [PLAN.md](docs/PLAN.md)
4. [ARCHITECTURE.md](docs/ARCHITECTURE.md)
5. [RUNBOOK.md](docs/RUNBOOK.md)
6. [contracts/README.md](contracts/README.md)
7. [PreviewApp/README.md](PreviewApp/README.md)
8. [HostApps/README.md](HostApps/README.md)

## 현재 저장소 상태

- `contracts/*` 와 `schemas/current/*` 가 유일한 입력 계약 루트다.
- `PreviewApp/*` 는 review/evidence shell 경계다.
- `HostApps/*` 는 native runtime proof 경계다.
- generated HTML, native source, adapter payload, sample build output은 disposable artifact다.

## 빠른 시작

```bash
swift build
swift test

./.build/debug/dsctl validate-app \
  --app contracts/apps/commerce.app.yaml \
  --json

./.build/debug/dsctl render-html \
  --screen contracts/screens/checkout-payment.screen.yaml \
  --json

# opens the Preview shell entrypoint at build/html/payment/index.html

./.build/debug/dsctl build-sample-apps \
  --app contracts/apps/commerce.app.yaml \
  --json
```

## 원칙

- authoritative source는 사람이 수정하는 contract와 policy 문서다.
- generated HTML, SwiftUI, Compose, adapter payload, screenshots, traces, sample build output은 disposable artifact다.
- HTML은 canonical review surface고, PreviewApp은 source of truth가 아니라 review/evidence shell이다.
- native proof는 generated source 자체가 아니라 `HostApps/` 경계에서 검증한다.
- MCP는 thin adapter여야 하며 authority가 되면 안 된다.
