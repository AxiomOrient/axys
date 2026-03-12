| Task ID | Status | Priority | Action | Depends On | Done when | Evidence |
|---|---|---|---|---|---|---|
| ASOT-00 | Done | P0 | baseline runtime/governance roots와 doc-sync export/render/verify path를 유지한다 | none | checked-in roots와 generated views가 fresh 하다 | `ds-doc-sync sync`, exported views, audit JSON |
| ASOT-01 | Done | P0 | authoring contract roots가 state/action/navigation/asset/preview semantics를 명시하도록 확장한다 | ASOT-00 | schema/docs/examples가 final core semantics를 source-owned field로 가진다 | schema diff, updated docs, example specs |
| ASOT-02 | Done | P0 | runtime root에 expanded command/evidence/output contract를 반영한다 | ASOT-01 | exported runtime view가 final core workflow surface를 포함한다 | `meta/runtime/contracts.cue`, exported runtime view, smoke tests |
| ASOT-03 | Done | P0 | governance root에 acceptance artifact inventory와 evidence ref를 추가한다 | ASOT-01 | exported governance view가 docs, annexes, acceptance artifacts를 추적한다 | `meta/governance/contracts.cue`, exported governance view |
| ASOT-04 | Done | P1 | planning fragments가 final completion gates/traceability/ownership boundary를 유지하도록 확장한다 | ASOT-02, ASOT-03 | `11`, `12`, `20`, `23`, `24`, `25` generated section이 같은 terms/evidence를 사용한다 | fragment source, rendered docs, doc-sync manifest |
| ASOT-05 | Done | P0 | audit와 doc-sync verify가 새 contract/evidence set을 자동으로 검증하도록 확장한다 | ASOT-02, ASOT-03, ASOT-04 | stale contract/doc/evidence drift가 자동으로 감지된다 | audit checks, doc-sync verify, failing fixtures |
| ASOT-06 | Done | P1 | iOS/Android host integration evidence를 governance inventory에 편입한다 | ASOT-03 | integration smoke output이 source-owned artifact로 추적된다 | host smoke logs, inventory update |
| ASOT-07 | Done | P0 | `login`, `product-detail` acceptance evidence를 traceable artifact로 등록한다 | ASOT-05, ASOT-06 | 두 canonical slice의 acceptance artifact가 traceability와 validation docs에 연결된다 | acceptance reports, traceability rows |
| ASOT-08 | Done | P0 | final completion 직전 authoritative-source freeze를 수행한다 | ASOT-07 | contract views, fragments, docs, annexes, audit artifacts가 모두 fresh 하다 | `ds-doc-sync sync`, `dsctl audit`, reread checklist |
