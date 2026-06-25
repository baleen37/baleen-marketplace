# baleen-marketplace release 후 버전 갱신 연계 설계

## 목표

마켓플레이스 자체 release가 발행되면, 곧바로 소스 플러그인 버전 갱신을 실행해 `marketplace.json`을 최신으로 맞춘다.

## 배경 / 설계 변경 이력

초기 설계는 별도 `on-release.yml`을 두어 `release: published` 이벤트로 `reusable-update-versions.yml`을 트리거하려 했다. 그러나 GitHub Actions는 **기본 `GITHUB_TOKEN`으로 만든 release/태그가 다른 워크플로우를 트리거하지 못하게 막는다**(무한 루프 방지). release.yml의 semantic-release가 기본 토큰으로 release를 발행하므로 on-release.yml은 끝내 트리거되지 않았다.

→ `on-release.yml`을 제거하고, **release.yml의 semantic-release 성공 직후 같은 job에서 버전 갱신 스크립트를 직접 실행**하는 방식으로 변경한다. 토큰 트리거 제약을 받지 않고 확실히 동작한다.

## 흐름

```
main에 머지
   ↓
release.yml
   ├─ semantic-release: conventional commit 분석 → 태그 + GitHub Release 발행
   └─ update-versions.sh: 소스 플러그인 최신 버전 폴링 → marketplace.json 갱신/커밋·푸시
```

## 변경 사항

### `.github/workflows/release.yml` (수정)

semantic-release 스텝 뒤에 버전 갱신 스텝을 추가한다.

```yaml
      - name: Update plugin versions
        env:
          GH_TOKEN: ${{ secrets.BALEEN_MARKETPLACE_RELEASE_LOOKUP_TOKEN || github.token }}
          MARKETPLACE_JSON: .claude-plugin/marketplace.json,.agents/plugins/marketplace.json
        run: bash scripts/update-versions.sh
```

### `.github/workflows/on-release.yml` (제거)

토큰 트리거 제약으로 동작하지 않으므로 삭제한다.

## 결정 사항 / 가정

- **무한 루프 없음**: update-versions.sh의 커밋 메시지는 `chore: update plugin versions`이므로 release.yml의 semantic-release가 새 릴리스를 만들지 않는다.
- **변경 없을 때**: 스크립트가 "No version changes detected"로 exit 0 → job 성공. release job을 깨지 않는다.
- **토큰**: 비공개 release 조회를 위해 `BALEEN_MARKETPLACE_RELEASE_LOOKUP_TOKEN`을 우선 쓰고, 없으면 `github.token`으로 폴백한다.

## 검증

- `actionlint`로 release.yml lint → OK
- `update-versions.sh`를 `DRY_RUN=true`로 로컬 실행 → 5개 플러그인 폴링, 변경 없음 확인
- 실제 동작은 머지 → Release 워크플로우의 "Update plugin versions" 스텝 로그에서 확인
