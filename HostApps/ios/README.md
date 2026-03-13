# iOS HostApps

이 디렉토리는 generated SwiftUI output을 실제 iOS host harness에 mount해서 검증하는 루트다.

## proof 기준

- Level 0: `GeneratedUI/ios/*` generated source 존재 확인
- Level 1: `HostSmoke/ios/*` wrapper/build 로그 확인
- Level 2: `BuildArtifacts/ios/*` runtime smoke 로그 확인
- Level 3: `HostProof/proof.manifest.json` 과 요약 결과 확인

## 실행

`build-sample-apps` 가 sample root를 만든 뒤 아래 스크립트로 proof를 읽는다.

```bash
HostApps/ios/scripts/run-host-proof.sh <sample-root>
```
