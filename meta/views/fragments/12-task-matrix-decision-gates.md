| Gate | Trigger tasks | Pass condition | On fail |
|---|---|---|---|
| DG-01 Final contract | MODEL-01, AUTHOR-01 | authoring contract와 `ScreenSpec` model이 core screens를 explicit하게 담는다 | schema/model부터 다시 닫는다 |
| DG-02 Authoring completeness | AUTHOR-02, VALIDATE-01 | starter-spec path가 deterministic하고 unresolved item은 generation 전에 모두 차단된다 | compile/report/validator를 먼저 고친다 |
| DG-03 Generator parity | GENERATE-01, REVIEW-01 | SwiftUI / Compose / HTML이 같은 의미를 유지하고 preview state review가 가능하다 | platform parity를 닫기 전에는 integration으로 넘어가지 않는다 |
| DG-04 Host integration | INTEGRATE-01, INTEGRATE-02 | generated adapter가 host code에 연결되고 generated file hand-edit가 필요 없다 | packaging/adapter contract를 먼저 수정한다 |
| DG-05 Governance convergence | GOV-01, ASOT-01 | runtime/governance/doc-sync/audit와 annex docs가 같은 source/evidence set을 따른다 | source-of-truth와 audit evidence를 다시 맞춘다 |
| DG-06 Final acceptance | E2E-01, E2E-02, VERIFY-01 | 두 canonical slice와 final verification suite가 모두 fresh pass 한다 | completion claim을 보류하고 남은 workstream을 유지한다 |
