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
