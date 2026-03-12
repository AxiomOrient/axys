# Architecture

이 저장소는 contract-first control plane이다. source of truth는 prose 문서가 아니라 `contracts/*` 와 `schemas/current/*` 다.

## 핵심 경계

- Contract root: `contracts/*`, `schemas/current/*`
- Review shell: `PreviewApp/*`
- Native proof: `HostApps/*`
- Runtime surface: `dsctl`, `ds-mcp`

## 파이프라인

```text
contracts/* + schemas/current/*
  -> validate
  -> HTML review bundle
  -> native generation
  -> adapter export
  -> HostApps proof
```

## 규칙

1. generated output은 source of truth가 아니다.
2. HTML review가 가장 먼저 본다.
3. MCP는 thin adapter여야 한다.
4. generated docs, evidence snapshots, trace bundles는 개발 입력으로 읽지 않는다.
5. 새 기능은 contract, review shell, host proof 경계 중 하나를 명확히 소유해야 한다.
