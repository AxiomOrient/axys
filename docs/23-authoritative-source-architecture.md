# 23. Authoritative Source Architecture

## 1. Decision

이 저장소의 authoritative-source 시스템은 **authoring contract roots + runtime root + governance root + planning view source** 의 조합으로 고정한다.
즉, 최종 completion까지 source는 아래 네 층으로 닫는다.

- `schemas/*`, `examples/*`, `docs/03`, `docs/06`, `docs/08`, `docs/17`
- `meta/runtime/contracts.cue`
- `meta/governance/contracts.cue`
- `meta/views/governance.fragments.json`

이 조합의 목적은 **authoring, runtime interface, governance evidence, planning ledger** 를 서로 다른 책임으로 분리하면서도 `ds-doc-sync` 와 `audit` 로 하나의 검증 경로를 유지하는 것이다.

## 2. Problem Statement

완성된 product는 자연어 해석의 우연성에 의존하면 안 된다.
핵심기능이 실제로 돌아가려면 아래 네 층이 각각 명확한 ownership을 가져야 한다.

- authoring contract: 사람이 무엇을 쓰고, `ScreenSpec` 이 무엇을 담아야 하는가
- runtime contract: CLI/MCP/doc-sync/audit 가 어떤 machine-readable surface를 가지는가
- governance contract: 어떤 docs/views/evidence/artifact가 completion claim을 구성하는가
- planning contract: 어떤 phase/task/traceability row가 delivery를 통제하는가

## 3. Current authoritative layers

### 3.1 Authoring contract roots

authoring contract roots는 아래를 가진다.

- `ScreenSpec` schema
- component catalog / config schema
- example screen-doc / screen-spec / token / catalog / config
- source-of-truth / data-model / generation / host-integration docs

이 층은 사람이 작성하거나 검토하는 계약 입력의 semantics를 소유한다.
핵심 규칙은 하나다.

- `screen-doc` 는 intent source다.
- authoritative execution contract는 완성된 `ScreenSpec` 이다.
- `compile-screen-doc` 는 starter spec과 completion report를 만들 수 있지만, unresolved output은 generation 단계로 들어가면 안 된다.

### 3.2 Runtime root

`meta/runtime/contracts.cue` 는 아래를 가진다.

- CLI command 목록
- MCP tool 목록
- doc-sync command 목록
- evidence key
- `doctor` capability / toolchain field set
- exported contract view path
- exit code
- integration / review / report surface name

이 root는 runtime surface의 선언 계약이다.

### 3.3 Governance root

`meta/governance/contracts.cue` 는 아래를 가진다.

- generated docs inventory
- authoritative root inventory
- runtime/governance evidence reference set
- runtime doctor artifact inventory
- planning reread checklist artifact inventory
- integration smoke artifact inventory
- acceptance artifact inventory

이 root는 package-level governance inventory와 audit cross-reference 입력을 가진다.
즉, `generatedDocs`, `authoritativeRoots`, `evidenceRefs` 뿐 아니라
source-owned `runtimeArtifacts`, `planningArtifacts`, `integrationArtifacts`, `acceptanceArtifacts` registry도 여기서 닫는다.

### 3.4 Planning view source

`meta/views/governance.fragments.json` 는 아래를 가진다.

- execution plan critical path
- task matrix row
- decision gate
- traceability row
- ownership boundary table

이 층은 master plan과 workstream annex table을 사람이 읽을 수 있는 generated ledger로 유지한다.
또한 integration / acceptance evidence가 partial 인데 task row가 `Done` 으로 앞서 나가는 식의 planning drift도 audit로 막는다.

## 4. Ownership boundary

<!-- GENERATED:BEGIN ownership-boundary-table -->
| Layer | Owns | Must not own |
|---|---|---|
| authoring contract roots | `ScreenSpec` schema, component catalog/config schema, example inputs, authoring semantics, completion-report rules | exit codes, audit evidence registry, phase/task sequencing |
| runtime root | CLI command, MCP tool, input contract, output path, exit code, evidence key | task priority, decision gate prose, roadmap sequencing |
| governance root | generated-doc inventory, authoritative-source inventory, evidence references, runtime/planning/integration/acceptance artifact registry | renderer behavior, task rows, schema field definitions |
| planning view source | execution-plan rows, task rows, decision gates, traceability rows, annex structure | runtime command truth, schema semantics, generator algorithms |
<!-- GENERATED:END ownership-boundary-table -->

`runtime root` 표기는 audit/doc-sync freshness regression과 operational contract 설명에서 공통으로 쓰는 compact label이다.

## 5. Render and verify pipeline

현재 권장 파이프라인은 아래 순서다.

```text
schemas/*
examples/*
docs/03 + docs/06 + docs/08 + docs/17
meta/runtime/contracts.cue
meta/governance/contracts.cue
meta/views/governance.fragments.json
  -> swift run ds-doc-sync export-contracts
  -> swift run ds-doc-sync export-fragments
  -> swift run ds-doc-sync render
  -> swift run ds-doc-sync verify
  -> swift test
  -> dsctl audit
```

여기서 `ds-doc-sync` 는 source가 아니라 **contract view / fragment / generated doc bridge** 다.

역할:

- contract root를 concrete JSON view로 export 한다
- structured planning source를 markdown fragment로 export 한다
- 지정된 markdown region만 교체한다
- 현재 문서가 stale이면 non-zero로 실패한다

freshness는 generated view와 rendered content comparison으로 판정한다.

## 6. Annex relationship

- `11`, `12`, `20` 은 전체 completion control plane이다.
- `24`, `25` 는 authoritative-source 전용 workstream annex다.
- annex는 subordinate workstream이지만, source ownership/evidence 정렬이 필요한 핵심축이므로 별도 문서로 유지한다.
- annex가 있어도 execution authority는 `11`, `12`, `20` 에 남는다.

## 7. Final rule

authoritative path에서 heuristic convenience와 execution contract를 혼동하면 안 된다.
starter spec은 중간 산출물일 수 있지만, generation과 integration은 항상 **complete `ScreenSpec` + fresh evidence** 위에서만 성립해야 한다.
