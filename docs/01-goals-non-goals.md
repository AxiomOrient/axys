# 01. Goals and Non-Goals

## 1. Primary Goal

디자인 문서에서 **한 번에 신뢰할 수 있는 하나의 결과**를 만들 수 있는 자동화 시스템을 설계하고 구현한다.

## 2. Success Criteria

다음 조건을 만족해야 한다.

### 2.1 정확성
- 같은 입력은 같은 출력을 만든다.
- 잘못된 ScreenSpec은 생성 전에 차단한다.
- design tokens와 component catalog를 벗어난 출력이 나오지 않는다.

### 2.2 단순성
- 코어 파이프라인은 한 줄로 설명 가능해야 한다.
- source of truth는 최소화해야 한다.
- 신규 팀원이 1일 안에 이해 가능해야 한다.

### 2.3 실용성
- 에이전트가 CLI로 전 과정을 수행할 수 있어야 한다.
- 결과를 사람이 HTML로 바로 볼 수 있어야 한다.
- 네이티브 결과를 host app에 쉽게 통합할 수 있어야 한다.

### 2.4 확장성
- iOS와 Android를 둘 다 지원해야 한다.
- 새로운 screen type / component / token은 contract 확장으로 수용해야 한다.
- Penpot / Pencil 같은 외부 preview adapter를 붙일 수 있어야 한다.

## 3. Explicit Non-Goals

### 3.1 v1에서 하지 않는 것
- runtime server-driven UI
- Flutter / React Native / Compose Multiplatform UI 공유
- visual editor를 authoritative source로 사용하는 것
- design token SaaS 의존
- multi-tenant web service
- production-ready collaborative editor
- animation authoring engine
- AI가 직접 네이티브 화면 코드를 자유 생성하는 것

### 3.2 왜 하지 않는가
이들은 유용하지만, 현재의 핵심 목표인 **단순하고 확실한 결과 생성**에 직접적으로 기여하지 않는다.

## 4. Product Statement

> 이 시스템은 “디자인 문서에서 네이티브 UI를 자동 생성하는 deterministic design compiler”다.
