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
