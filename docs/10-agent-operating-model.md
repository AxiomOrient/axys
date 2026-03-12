# 10. Agent Operating Model

## 1. Primary agent rule

에이전트는 직접 SwiftUI/Compose 화면 코드를 “창작”하지 않는다.
에이전트의 주 작업 대상은 **ScreenSpec**이다.

## 2. Agent workflow

```text
1. screen-doc 읽기
2. component catalog 읽기
3. tokens 정책 읽기
4. ScreenSpec 생성 또는 수정
5. validate 실행
6. generate 실행
7. HTML review
8. 실패 시 ScreenSpec / tokens 수정
```

## 3. Agent constraints

- generated files 직접 수정 금지
- catalog에 없는 component 추가 금지
- raw spacing / color literal 사용 금지
- platform-specific block을 ScreenSpec에 넣지 않음
- 하나의 spec은 하나의 primary intent를 유지

## 4. AGENTS.md guidance

repo root에 `AGENTS.md`를 두고 아래 내용을 명시한다.
- source of truth
- mandatory command sequence
- validation before generation
- generated output immutability
- allowed component vocabulary

## 5. Prompt templates

### 5.1 `prompts/spec-generation.md`
- 입력: screen-doc
- 출력: ScreenSpec JSON only

### 5.2 `prompts/review-and-fix.md`
- 입력: screen-doc + ScreenSpec + validation report + HTML preview
- 출력: upstream fix proposal only

## 6. Multi-agent split (optional)

### Agent A — Normalizer
screen-doc → ScreenSpec

### Agent B — Validator fixer
validation errors → corrected ScreenSpec

### Agent C — Reviewer
HTML/native diff → upstream improvement proposal

## 7. Human override points

사람은 아래에서만 개입한다.
- intent ambiguity 정리
- design token 의미 결정
- catalog 확장 승인
- final review approval
