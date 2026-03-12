# AGENTS.md Template

## Source of truth
1. `examples/screen-doc/*.md` 는 사람의 의도다.
2. `examples/screens/*.screen.json` 은 authoritative machine contract다.
3. `examples/tokens/*.json` 은 design values다.
4. generated outputs는 source가 아니다.

## Mandatory workflow
1. Read `MASTER_BLUEPRINT.md`
2. Read `examples/catalogs/component-catalog.json`
3. Read target `screen-doc`
4. Create or update exactly one `screen-spec`
5. Run validate
6. Run generate
7. Review HTML preview
8. Fix upstream only

## Hard constraints
- generated code 직접 수정 금지
- raw color/spacing literal 금지
- catalog 밖 component 금지
- 하나의 spec은 하나의 primary intent 유지
