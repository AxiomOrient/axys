# 00. Executive Decision

## 최종 의사결정 요약

이 프로젝트는 **모바일 디자인 자동화 시스템**이다.
목표는 **문서 기반 설계 의도를 구조화된 계약(ScreenSpec)으로 변환하고**, 이 계약에서 **iOS / Android / HTML**을 자동 생성하는 것이다.

## 최종 선택

### 선택
- Swift control plane
- Swift Package Manager
- CLI-first interface
- MCP thin adapter
- ScreenSpec as authoritative contract
- DTCG-style tokens
- Native renderers (SwiftUI / Compose)
- Static HTML preview

### 비선택
- Rust control plane (v1)
- shared runtime UI
- server-driven UI
- design tool file as source of truth
- direct Figma/Penpot/Pencil to production code path

## 결정 기준

의사결정은 아래 기준으로 했다.

1. **단순성**
2. **재현 가능성**
3. **에이전트 자동화 적합성**
4. **네이티브 정확도**
5. **운영 복잡도 최소화**

## 핵심 판단

이 시스템은 **디자인 툴 자동화**가 아니다.
정확히는 **디자인 의도 자동 정규화 + UI 코드 자동 생성** 시스템이다.

즉, 문제의 중심은 canvas가 아니라 **contract**다.

## 도식

```text
screen-doc
  ↓ normalize
screen-spec
  ↓ validate
generator
  ↓
swiftui / compose / html
```
