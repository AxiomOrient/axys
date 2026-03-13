# PreviewApp

PreviewApp은 axys contracts를 기반으로 생성되는 review/evidence shell이다. source of truth가 아니라 canonical HTML review를 수행하기 위한 shell이며, generated bundle은 disposable artifact다.

## 포함해야 하는 기능

1. flow navigation replay
2. state switcher
3. token inspector
4. accessibility inventory/panel
5. review checklist panel
6. screenshot baseline anchor
7. reduced-motion toggle

## 포함하지 않아야 하는 기능

- authoring 기능
- WYSIWYG 편집
- 디자인 소스 편집
- Penpot round-trip authoring
- native generation 로직

## 권장 구조

```text
PreviewApp/
  README.md
  shell/
    layout.html
    review.css
    review.js
  templates/
  evidence/
    scripts/
    baselines/
    output/
```

## evidence automation

PreviewApp evidence는 `agent-browser`를 우선 사용하되, renderer와 evidence driver를 혼동하지 않는다.

- default CI path: daemon mode
- `--native`: canary only
- `BrowserEvidenceDriver` 뒤에 `AgentBrowserDriver`를 둔다.

## 현재 상태

현재 저장소는 `dsctl render-html` 결과의 루트 `index.html` 을 Preview shell entrypoint로 사용한다. source-owned shell 자산은 `PreviewApp/shell/*` 에 있고, generated bundle은 이 자산을 복사해 review layer로 사용한다.

## 실행 경로

1. `dsctl render-html --screen ... --out <bundle>`
2. `<bundle>/index.html` 을 연다
3. 필요하면 `PreviewApp/evidence/scripts/run-shell-smoke.sh <bundle>` 으로 shell evidence를 남긴다
