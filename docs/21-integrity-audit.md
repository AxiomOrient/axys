# 21. Integrity Audit

## 목적

문서, schema, examples, prompts, manifest가 서로 어긋나지 않는지 확인한다.

## 감사 범위

- core files 존재 여부
- JSON parse 가능 여부
- schema validation 통과 여부
- markdown relative link 유효성
- generated doc freshness (`ds-doc-sync verify`)
- exported contract view freshness (`ds-doc-sync export-contracts` 기준)
- runtime/governance evidence cross-reference validity
- governance generated-doc inventory와 doc-sync manifest 일치 여부
- governance inventory가 가리키는 source-owned acceptance / integration artifact 존재 여부
- governance inventory가 가리키는 source-owned runtime doctor artifact 존재 여부
- governance inventory가 가리키는 source-owned planning reread checklist artifact 존재 여부
- acceptance / integration evidence artifact의 필수 field shape와 status 규칙
- planning reread checklist artifact의 필수 field shape와 canonical document coverage 규칙
- runtime / integration evidence의 `verification.testCase` 와 `verification.testSource` 가 실제 source-owned `@Test("...")` 선언과 맞는지
- runtime doctor evidence의 `verification.command` 가 `swift run dsctl doctor --json` 이고 integration evidence의 `verification.command` 가 `swift test` 인지
- integration evidence의 `verifiedOn` 이 referenced doctor snapshot 날짜와 맞는지, acceptance evidence의 `verifiedOn` 이 referenced host smoke 날짜와 맞는지
- acceptance artifact가 authoring input, review surface, host smoke evidence를 실제 경로로 참조하는지
- acceptance artifact의 `generatedManifest` 가 authoring spec / review surface / declared platform output과 맞는지
- acceptance artifact의 `hostEvidence` 가 referenced `ScreenSpec.platforms` 의 native coverage와 맞는지
- acceptance artifact의 `blockingHostEvidence` 가 non-pass host smoke evidence와 정확히 맞는지
- acceptance artifact의 `verification[*]` 가 canonical fresh-evidence command set과 같은 screen-specific generate command를 포함하는지
- acceptance artifact의 reviewed preview state와 checklist가 referenced spec / HTML review surface와 일치하는지
- integration artifact의 `requiredCapability` / `doctorEvidence` 가 runtime doctor snapshot과 일치하는지
- runtime doctor artifact가 현재 머신의 `dsctl doctor --json` 결과와 drift 없는지
- planning ledger(`meta/views/governance.fragments.json`) 의 `INTEGRATE-01`, `INTEGRATE-02`, `E2E-01`, `E2E-02`, `VERIFY-01`, `P5`, `P7` status가 source-owned evidence 상태와 일치하는지
- manifest 생성 여부

가장 싼 복구 경로는 보통 `ds-doc-sync sync --project-root . --json` 이다.
이 명령은 contract view export, fragment export, region render, freshness verify 를 한 번에 다시 맞춘다.

## 기대 결과

모든 핵심 파일이 존재하고, examples가 schema를 만족하며, 문서 링크가 깨지지 않고 generated region이 source와 일치해야 한다.
또한 governance evidence ref가 runtime evidence key와 어긋나지 않아야 하고,
governance inventory가 선언한 generated docs / authoritative roots / acceptance artifacts / integration artifacts 가 실제 경로를 가리켜야 한다.

## 자동 감사 산출물

실제 자동 감사 JSON 결과는 다음 파일에 기록한다.

- `audit/integrity-report.json`
- `MANIFEST.json`
- `audit/evidence/integration/ios-host-smoke.json`
- `audit/evidence/integration/android-host-smoke.json`
- `audit/evidence/runtime/doctor.json`
- `audit/evidence/planning/reread-checklist.json`
- `audit/evidence/acceptance/login.json`
- `audit/evidence/acceptance/product-detail.json`

## 수동 확인 체크리스트

1. `README.md` 링크가 실제 문서로 이동하는가
2. execution plan, task matrix, traceability가 같은 canonical 이름과 task id를 사용하는가
3. examples가 docs에서 설명한 구조와 일치하는가
4. schemaVersion이 모두 `1.0`인가
5. screen-spec examples가 `["ios", "android", "html"]`를 포함하는가
6. prompts가 upstream-fix 정책을 따르는가

## 해석 원칙

audit는 문서의 완벽함 자체를 보장하지는 않는다.
그러나 최소한 **구조적 무결성**과 **참조 무결성**을 보장한다.
