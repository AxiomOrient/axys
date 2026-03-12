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
