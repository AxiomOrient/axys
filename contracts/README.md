# contracts/

`contracts/`는 axys의 사람 기준 source-owned 계약 루트다. 이 디렉토리 아래의 파일만이 UI generation 입력 권한을 가진다.

```text
contracts/
  apps/
  flows/
  screens/
  motion/
  review/
  registry/
  tokens/
  fixtures/
```

## 규칙

1. `contracts/` 아래 파일은 generated file이 아니다.
2. generated HTML/native/adapters/evidence는 이 경로 아래에 들어오지 않는다.
3. validation은 반드시 현재 계약 스키마를 통과해야 한다.
4. app/flow/screen/motion/review/registry/tokens 외 파일 형식 추가는 ADR로 먼저 고정한다.
5. PreviewApp, HostApps, adapter export는 이 경로를 수정할 수 없다.

## ownership

- product / design systems: `apps`, `flows`, `review`
- compiler / platform: `registry`, `motion`, `schemas/current`
- brand / theme owners: `tokens`
- feature owners: `screens`, `fixtures`
