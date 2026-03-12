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

### `V2Models.swift`
- `AppSpec v2`
- `FlowSpec v2`
- `ScreenSpec v2`
- `Component Registry v2`
- `MotionSpec`
- `Review Checklist`

### `V2Validator.swift`
- YAML/JSON v2 contract loading
- app -> flow -> screen transitive validation
- registry / motion / review cross-reference checks
- v2 layout binding / prop contract checks

### `V2HTMLRenderer.swift`
- v2 HTML canonical review bundle emission
- preview-state rendering
- registry-backed review shell rendering

### `V2AdapterSyncRenderer.swift`
- v2 Penpot adapter payload emission
- v2 Pencil adapter payload emission
- flow/screen adapter envelope rendering

### `V2NativeRenderer.swift`
- registry-backed SwiftUI source emission
- registry-backed Compose source emission
- native manifest emission

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
- v2 sample app build orchestration
- v2 sample app runtime smoke orchestration
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
- `v2 validate-app` entry path
- `v2 validate-flow` entry path
- `v2 validate-screen` entry path
- `v2 render-html` entry path
- `v2 sync-penpot` entry path
- `v2 sync-pencil` entry path
- `v2 generate-native` entry path
- `v2 build-sample-apps` entry path
- `v2 audit` entry path

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
