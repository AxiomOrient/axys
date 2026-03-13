# Preview Evidence

이 디렉토리는 `PreviewApp` review shell 위에서 browser evidence를 수집하기 위한 경계다.

## 구조

- `drivers/agent-browser-driver.sh`: 실제 browser 자동화 드라이버
- `scripts/run-preview-evidence.sh`: driver orchestration entrypoint
- `scripts/run-shell-smoke.sh`: rendered preview bundle을 로컬 서버로 띄우고 evidence를 수집하는 smoke 경로
- `baselines/`: 비교 기준이 되는 수동/승인 baseline 위치
- `output/`: 실행 때마다 덮어쓰거나 보관하는 disposable output 위치

## 규칙

1. renderer는 HTML bundle 생성까지만 책임진다.
2. evidence driver는 URL open, snapshot, screenshot 수집만 책임진다.
3. `baselines/` 는 승인된 비교 기준만 둔다.
4. `output/` 은 disposable evidence output 이다.
