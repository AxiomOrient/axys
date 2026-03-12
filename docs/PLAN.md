# Plan

기준일: 2026-03-12

이 문서는 현재 저장소의 유일한 A-to-Z 작업 계획이다. generated ledger나 evidence 문서는 개발 입력으로 취급하지 않는다.

## 현재 상태

- 입력 계약 루트는 `contracts/*` 와 `schemas/current/*` 다.
- 리뷰 경계는 `PreviewApp/*` 다.
- 네이티브 proof 경계는 `HostApps/*` 다.
- generated HTML, generated native source, adapter payload, screenshots, traces, build output은 disposable artifact다.

## 완료된 정리

1. legacy authoring 루트와 중복 문서를 제거했다.
2. CLI / MCP / audit surface를 현재 repo shape에 맞췄다.
3. generated docs / evidence 묶음을 개발 입력에서 제거했다.

## 다음 작업 순서

1. `PreviewApp` review shell 완성
2. browser evidence driver 추가
3. `HostApps` runtime proof 강화
4. 필요한 contract 확장

## 완료 조건

아래가 모두 참이면 현재 버전 준비 완료다.

1. 새 작업이 `contracts/*` 에서만 시작된다.
2. 리뷰는 `PreviewApp` 기준으로 닫힌다.
3. 네이티브 proof는 `HostApps/*` 에서 닫힌다.
4. `swift test` 와 `swift run dsctl audit --project-root . --json` 가 통과한다.
