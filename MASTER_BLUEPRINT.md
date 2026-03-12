# Master Blueprint

기준일: 2026-03-12

## 1. 최종 결정

이 저장소의 공식 경로는 `contracts/*` 중심 contract-first 운영이다. 저장소의 주 작업은 계약, review shell, runtime/governance 경계를 한 방향으로 유지하는 것이다.

최종 파이프라인은 아래로 고정한다.

```text
contracts/*
schemas/current/*
  -> validate
  -> DesignIR
  -> PreviewApp bundle
  -> SwiftUI generator
  -> Compose generator
  -> adapter export
  -> HostApps runtime proof
  -> evidence + audit
```

## 2. 유지하는 원칙

아래 원칙은 리뉴얼 이후에도 유지한다.

1. contract-first
2. HTML canonical review
3. generated artifact disposable
4. Swift 6 + SPM + CLI 중심
5. thin MCP

## 3. 현재 저장소에 대한 판단

- `contracts/*`, `schemas/current/*`, `PreviewApp/*`, `HostApps/*`가 현재 작업 기준 경계다.
- command surface는 contract validation, HTML review, adapter sync, native generation, host proof, audit로 닫는다.
- generated artifact는 disposable이고 source of truth가 아니다.

## 4. authoritative source

최종 authoritative source는 아래로 닫는다.

```text
contracts/apps/*
contracts/flows/*
contracts/screens/*
contracts/motion/*
contracts/review/*
contracts/registry/*
contracts/tokens/*
schemas/current/*
docs/adr/*
PreviewApp/shell/*
PreviewApp/evidence/scripts/*
HostApps/*
meta/runtime/contracts.cue
```

다음은 authoritative source가 아니다.

```text
generated HTML/native source
adapter payloads
screenshots/videos/traces
sample app generated output
build/*
```

## 5. legacy 취급

- compatibility layer와 migration path는 유지하지 않는다.
- execution authority는 `docs/PLAN.md`, `docs/ARCHITECTURE.md`, `docs/RUNBOOK.md`가 가진다.

## 6. immediate priorities

1. authoritative contracts ADR 채택
2. 중복 문서와 generated doc/evidence 묶음을 제거한다
3. `contracts/`, `PreviewApp/`, `HostApps/` 경계를 구현 기준으로 고정
4. contract 입력 경로와 runtime path를 같은 기준으로 고정
5. Preview evidence와 native host proof 경계를 코드와 태스크로 고정

## 7. final rule

문서와 구현이 충돌할 때는 legacy 서사가 아니라 현재 계약, schema, renderer, host proof 경계를 기준으로 정렬한다.
