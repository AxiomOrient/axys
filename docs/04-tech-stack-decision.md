# 04. Tech Stack Decision

## 1. Decision

v1 control plane은 **Swift 6 + Swift Package Manager**로 구현한다.

## 2. Compared options

| 항목 | Swift | Rust |
|---|---:|---:|
| macOS 적합성 | 매우 높음 | 높음 |
| iOS 인접성 | 매우 높음 | 낮음 |
| Android 코드 생성 가능성 | 충분함 | 충분함 |
| 단일 언어 단순성 | 높음 | 중간 |
| 팀 onboarding 비용 | 낮음 | 중간~높음 |
| MCP 공식 SDK | 있음 | 있음 |
| v1 복잡도 | 낮음 | 더 높음 |

## 3. Final stack

### 3.1 Core
- Swift 6
- Swift Package Manager
- Foundation
- Codable / JSONSerialization
- XCTest

### 3.2 Recommended production dependencies
- `apple/swift-argument-parser`
- `modelcontextprotocol/swift-sdk`

### 3.3 Targets
- iOS output: SwiftUI
- Android output: Jetpack Compose
- Review output: Static HTML + CSS

### 3.4 Not in core path
- Node.js
- TypeScript
- Style Dictionary
- Penpot runtime integration
- Pencil runtime integration

## 4. Why Swift wins

### 4.1 Language adjacency
control plane이 iOS와 같은 언어권에 있으면 팀의 사고 비용이 낮아진다.

### 4.2 macOS-first default
이 시스템의 기본 운영 환경은 macOS다.

### 4.3 enough for Android generation
Android target은 Kotlin으로 직접 작성하는 것이 아니라 **생성**하는 것이다.
따라서 generator 언어가 Kotlin일 필요는 없다.

### 4.4 official MCP path exists
Swift용 공식 MCP SDK가 있으므로 production path를 정리하기 쉽다.

## 5. Why Rust loses for v1

Rust는 훌륭하지만 이번 문제에서는 다음이 더 중요하다.

- 팀 적합성
- iOS adjacency
- 도입 속도
- 사고 모델 단순성

즉, 이번 문제의 최적화 대상은 **throughput of engineering decisions**다.

## 6. Android target choice

Android는 Jetpack Compose를 target으로 삼는다.

이유:
- modern native Android UI
- declarative structure
- token-driven theme mapping과 잘 맞음
- generated code review가 쉽다

## 7. Review / adapter choices

### Core
- HTML preview

### Optional adapters
- Penpot: self-hosted/open-source review adapter
- Pencil: optional local preview adapter

단, 둘 다 core path는 아니다.
