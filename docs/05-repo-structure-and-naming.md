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
