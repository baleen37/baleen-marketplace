# baleen-marketplace release 후 버전 갱신 연계 설계

## 목표

마켓플레이스 자체 release(`v1.x`)가 발행되면, 곧바로 소스 플러그인 버전 갱신(`reusable-update-versions.yml`)을 트리거해 `marketplace.json`을 최신으로 맞춘다.

기존 자동 release 설계(`2026-06-25-auto-release-design.md`)에서 범위 밖으로 두었던 on-release 연계를 추가하는 후속 작업이다.

## 흐름

```
release published (release.yml가 발행)
   ↓
on-release.yml
   └─ reusable-update-versions.yml 호출
        → 소스 플러그인 최신 버전 폴링 → marketplace.json 갱신/커밋
```

## 추가 파일

### `.github/workflows/on-release.yml` (신규)

```yaml
name: On Release
on:
  release:
    types: [published]
permissions:
  contents: write
jobs:
  update-versions:
    uses: ./.github/workflows/reusable-update-versions.yml
    secrets:
      token: ${{ secrets.BALEEN_MARKETPLACE_RELEASE_LOOKUP_TOKEN }}
```

reusable 워크플로우의 `workflow_call` secret 이름은 `token`이다(이전 `github-token`에서 변경됨).

## 결정 사항 / 가정

- **무한 루프 없음**: update-versions가 `marketplace.json`을 커밋할 때 메시지는 `chore: update plugin versions`이므로 release.yml의 semantic-release가 새 릴리스를 만들지 않는다.
- **시크릿**: 기존 `BALEEN_MARKETPLACE_RELEASE_LOOKUP_TOKEN`을 그대로 사용한다.

## 검증

- `actionlint`로 on-release.yml lint (reusable 호출 secret 이름 호환성 포함)
- 실제 동작은 머지 → release 발행 → On Release 워크플로우 실행 로그에서 확인
