# 15. Risks and Mitigations

## 1. ScreenSpec complexity creep

### Risk
component 종류가 늘어나며 ScreenSpec이 사실상 또 다른 UI DSL이 될 수 있다.

### Mitigation
- catalog gate 도입
- breaking change review 필요
- 새 component는 3개 renderer + validator + tests + docs 동시 업데이트 강제

## 2. Generator drift between platforms

### Risk
SwiftUI와 Compose 출력이 점점 다른 의미를 갖게 된다.

### Mitigation
- shared mapping table 유지
- cross-platform golden review
- HTML preview를 semantic baseline으로 사용

## 3. Token misuse

### Risk
raw literals가 ScreenSpec에 들어온다.

### Mitigation
- validator에서 차단
- examples에서 금지 사례 명시
- agent prompt에서 token alias 강제

## 4. Overuse of adapters

### Risk
Penpot/Pencil이 core path를 침범한다.

### Mitigation
- adapter boundary 문서화
- source of truth hierarchy 명시
- CI path에서 adapter 비필수화

## 5. CLI instability

### Risk
명령어나 JSON output shape가 자주 바뀌면 에이전트 호환성이 무너진다.

### Mitigation
- command stability policy
- versioned output schema
- contract tests

## 6. Documentation rot

### Risk
문서와 examples, schemas가 서로 어긋난다.

### Mitigation
- `audit` command
- integrity checklist
- CI에서 docs/example/schema 정합성 검사
