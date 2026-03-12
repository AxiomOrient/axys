# 22. Validation Report

## 목적

이 문서 패키지가 실제 구현 출발점으로 사용될 수 있는지 판단하기 위한 검증 기준을 정의한다.

## 검증 항목

### 1. 문서 검증
- 주요 의사결정 문서 존재
- README 진입점 존재
- onboarding 문서 존재
- execution plan 존재
- task matrix 존재
- traceability 문서 존재
- self-review 문서 존재

### 2. 계약 검증
- ScreenSpec schema 존재
- ComponentCatalog schema 존재
- Config schema 존재

### 3. 예시 검증
- login screen-doc 존재
- product-detail screen-doc 존재
- login ScreenSpec 존재
- product-detail ScreenSpec 존재
- token examples 존재
- catalog example 존재
- config example 존재

### 4. 실행 준비도 검증
문서만 보고 아래를 구현 가능해야 한다.
- repo skeleton
- models
- token resolver
- validator
- generators
- CLI
- MCP
- tests
- host integration

### 5. 증거 검증
- governance root가 acceptance artifact inventory를 가진다
- governance root가 integration smoke artifact inventory를 가진다
- governance root가 runtime doctor artifact inventory를 가진다
- governance root가 planning reread checklist artifact inventory를 가진다
- acceptance report가 canonical screen별로 source-owned path에 존재한다
- host smoke evidence가 iOS / Android 각각 source-owned path에 존재한다
- runtime doctor evidence가 source-owned path에 존재한다
- planning reread checklist evidence가 source-owned path에 존재한다
- evidence artifact의 `status`, `knownGap`, `residualGaps` 규칙이 맞다
- planning reread checklist artifact가 canonical planning doc set을 모두 포함한다
- runtime / integration evidence의 `verification.testCase` 와 `verification.testSource` 가 실제 `@Test("...")` 선언과 line anchor를 가리킨다
- runtime doctor evidence의 `verification.command` 가 `swift run dsctl doctor --json` 이고 integration evidence의 `verification.command` 가 `swift test` 다
- integration evidence의 `verifiedOn` 이 doctor snapshot 날짜와 맞고 acceptance evidence의 `verifiedOn` 이 referenced host smoke 날짜와 맞다
- acceptance report의 `generatedManifest` 가 authoring spec / review surface / declared platform output과 맞다
- acceptance report의 `hostEvidence` 가 referenced `ScreenSpec.platforms` 의 native coverage를 덮는다
- acceptance report의 `blockingHostEvidence` 가 non-pass host smoke artifact와 맞다
- acceptance report의 `verification[*]` 가 `swift test`, `ds-doc-sync sync`, `dsctl audit`, 그리고 같은 `screenId` 의 `dsctl generate` 명령을 포함한다
- acceptance report의 `review.reviewedPreviewStates` 와 `review.checklist` 가 spec / HTML review surface와 맞다
- integration evidence의 `requiredCapability` 와 `doctorEvidence` 가 runtime doctor snapshot과 맞다
- runtime doctor evidence가 현재 머신의 `dsctl doctor --json` 결과와 맞다
- planning ledger의 `INTEGRATE-*`, `E2E-*`, `VERIFY-01`, `P5`, `P7` status가 referenced evidence status와 맞다

## 기준

### Pass
- 문서, schema, example, prompts, audit artifacts가 모두 존재
- example JSON이 schema를 만족
- 문서 링크가 깨지지 않음
- governance inventory가 doc-sync manifest와 source-owned evidence 파일을 모두 추적함
- evidence artifact가 typed contract로 parse되고 cross-reference가 유효함
- planning reread checklist artifact가 canonical planning package를 빠뜨리지 않음
- runtime / integration evidence가 실제 source-owned test declaration까지 역참조 가능함
- runtime / integration evidence가 canonical verification command를 유지함
- integration / acceptance evidence가 referenced supporting artifact와 같은 verification date를 유지함
- acceptance artifact가 generated manifest와 generated platform coverage를 빠뜨리지 않음
- acceptance artifact가 referenced native platform coverage를 빠뜨리지 않음
- acceptance artifact status가 referenced host smoke status와 충돌하지 않음
- acceptance artifact가 canonical fresh-evidence command set을 빠뜨리지 않음
- acceptance review evidence가 declared preview states와 required review checklist domains를 모두 덮음
- runtime doctor snapshot이 host smoke readiness와 toolchain invariants를 유지함
- runtime doctor snapshot이 stale local capability snapshot이 아님
- planning/task status가 source-owned evidence보다 앞서 나가지 않음

### Fail
- schema/example mismatch
- broken doc links
- missing canonical files

## 실제 자동 결과

실제 자동 결과는 `audit/integrity-report.json`을 참조한다.
canonical acceptance artifact는 `audit/evidence/acceptance/*.json`,
host smoke artifact는 `audit/evidence/integration/*.json`,
runtime doctor artifact는 `audit/evidence/runtime/doctor.json`,
planning reread artifact는 `audit/evidence/planning/reread-checklist.json` 을 참조한다.
