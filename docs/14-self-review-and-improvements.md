# 14. Self Review and Improvements

이 문서는 설계 과정에서 스스로 발견한 문제와 그에 따른 개선을 기록한다.

## Iteration 1 — iOS 편향 문제

### 문제
초기 구조는 iOS 중심으로 보였고, Android가 부차적인 타깃처럼 보였다.

### 영향
계약과 generator가 SwiftUI 사고방식에 잠식될 위험이 있었다.

### 개선
- Android를 first-class target으로 명시
- 모든 핵심 도식에 iOS + Android + HTML을 동시에 표기
- Compose generator를 architecture 중심축에 포함

### 결과
문서와 구현 계획이 두 플랫폼을 동등하게 다루게 되었다.

## Iteration 2 — toolchain 과다 문제

### 문제
Node/TypeScript/Style Dictionary/별도 token compiler 등 선택지가 너무 많았다.

### 영향
실행보다 조합 논의가 더 커질 위험이 있었다.

### 개선
- v1 core path를 Swift-only로 축소
- external adapter를 core path 밖으로 이동
- HTML preview를 기본 review path로 고정

### 결과
설계가 훨씬 짧고 이해하기 쉬워졌다.

## Iteration 3 — source of truth 과다 문제

### 문제
screen-doc / intent spec / screen spec / preview spec / native spec 등 너무 많은 canonical 문서를 둘 위험이 있었다.

### 영향
에이전트가 어느 파일을 수정해야 하는지 모호해진다.

### 개선
canonical machine contract를 ScreenSpec 하나로 고정했다.

### 결과
수정 경로가 단순해졌다.

## Iteration 4 — MCP 과대평가 문제

### 문제
MCP가 시스템의 본체처럼 여겨질 수 있었다.

### 영향
CLI와 MCP에 중복 로직이 생긴다.

### 개선
CLI canonical, MCP thin adapter 원칙을 명시했다.

### 결과
interface layer가 단순해졌다.

## Iteration 5 — preview ambiguity 문제

### 문제
Penpot / Pencil / HTML이 모두 동등한 preview 후보처럼 보였다.

### 영향
review path가 흔들린다.

### 개선
HTML만 canonical review path로 남기고 나머지는 optional adapter로 강등했다.

### 결과
사람과 에이전트의 review workflow가 명확해졌다.

## Final self-assessment

### 무엇이 좋아졌는가
- source of truth 축소
- iOS/Android 대칭성 강화
- toolchain 축소
- review path 명확화
- CLI/MCP 역할 분리

### 아직 남은 제한
- advanced component catalog 미포함
- animation / navigation graph 미포함
- host integration sample code 미포함
- multi-screen orchestration 미포함

이 제한은 의도적이다.
현재 문서의 목표는 breadth가 아니라 **완결성과 무결성**이다.
