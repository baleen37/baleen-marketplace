# baleen-marketplace 자동 release 설계

## 목표

`main`에 머지될 때 conventional commit을 분석해 자동으로 semver 태그와 GitHub Release를 발행한다.

memmem(`baleen37/memmem`)이 사용하는 semantic-release 기반 릴리스 패턴을 마켓플레이스 저장소에 맞게 단순화하여 적용한다.

## 배경

- 이 저장소는 순수 Shell 프로젝트로 `package.json`/빌드 도구가 없다.
- 저장소 자체에는 태그도 GitHub Release도 없다.
- `marketplace.json`의 플러그인 버전 갱신은 기존 `reusable-update-versions.yml`(매시간 스케줄 + `update_versions` dispatch)이 담당하며, 이번 작업 범위에 포함하지 않는다.

## 흐름

```
main에 머지
   ↓
release.yml (semantic-release)
   ├─ conventional commit 분석 → semver 결정
   └─ git 태그 + GitHub Release 발행
```

## 추가 파일

### 1. `.releaserc.json` (신규)

`package.json`/빌드/플러그인 동기화가 없으므로 memmem 대비 `@semantic-release/exec`, `@semantic-release/git`, `@semantic-release/npm`을 제거하고 3개 플러그인만 사용한다.

```json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/github"
  ]
}
```

### 2. `.github/workflows/release.yml` (신규)

```yaml
name: Release
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: write
  issues: write
  pull-requests: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: true
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
      - run: npx --yes semantic-release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

lockfile/의존성이 없으므로 `npx --yes`로 semantic-release를 즉석 실행한다(저장소에 Node 의존성을 추가하지 않는다).

## 결정 사항 / 가정

- **첫 릴리스 버전**: 태그가 없으므로 semantic-release의 기본값인 `v1.0.0`으로 시작한다.
- **시크릿**: 자기 저장소에 릴리스만 발행하므로 기본 `GITHUB_TOKEN`으로 충분하다.
- **release 후 버전 갱신 연계(`on-release`)는 이번 범위에서 제외**한다. 추후 필요하면 별도 작업으로 추가한다.

## 검증

- `actionlint`로 release.yml lint
- `jq`로 `.releaserc.json` 유효성 확인
- 실제 동작은 머지 후 Actions 로그와 Releases 탭에서 확인
