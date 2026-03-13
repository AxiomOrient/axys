# Runbook

## 기본 루프

1. `contracts/*` 에서 app / flow / screen / motion / review 계약을 수정한다.
2. validation을 실행한다.
3. HTML review bundle 루트 `index.html` 을 Preview shell 기준으로 확인한다.
4. 필요하면 `PreviewApp/evidence/scripts/run-shell-smoke.sh <bundle>` 로 browser evidence를 남긴다.
5. 필요하면 adapter export와 native generation을 실행한다.
6. `build-sample-apps` 또는 `HostApps/*/scripts/run-host-proof.sh <sample-root>` 로 runtime proof를 확인한다.

## 명령 표면

```text
dsctl doctor
dsctl validate-app
dsctl validate-flow
dsctl validate-screen
dsctl render-html
dsctl generate-native --platform ios
dsctl generate-native --platform android
dsctl sync-penpot
dsctl sync-pencil
dsctl build-sample-apps
dsctl preview-serve
dsctl audit --project-root .
```

## 규칙

- generated HTML, native source, adapter payload는 hand edit 하지 않는다.
- review는 Preview shell 또는 HTML bundle에서 먼저 한다.
- proof는 HostApps 경계에서 본다.
- generated docs와 old evidence는 개발 입력으로 읽지 않는다.
