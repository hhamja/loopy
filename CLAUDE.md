# loopy — 프로젝트 지침

이 저장소에서 작업할 때 따를 규칙. 전역 `~/.claude/CLAUDE.md`와 병합해서 사용.

## 1. 새 기능은 Skill로 패키징 (Command 아님)

Claude Code 공식 가이드상 커스텀 슬래시 커맨드는 Skill로 통합됐다(`docs.claude.com` skills/commands/plugins). **신규 기능은 `skills/<name>/SKILL.md`로 만든다.**

- 부수효과가 있거나 사용자가 실행 타이밍을 정해야 하는 워크플로(배포·커밋·진단 류)는 `disable-model-invocation: true`를 붙여 자동 발동을 막는다.
- 인자는 `argument-hint` + 본문 `$ARGUMENTS`로 받는다.
- 기존 `commands/` 디렉터리는 **레거시**다. "이 레포가 `commands/`를 쓰니까 커맨드로 만들자"를 근거로 삼지 말 것 — 신규는 `skills/`.

## 2. 로컬 관례 < 공식 베스트 프랙티스

이 레포의 로컬 관례는 **증거이지 권위가 아니다.** 로컬 관례가 공식 Claude Code 가이드/문서와 충돌하면:

- 충돌을 **명시적으로 짚고**, 공식 쪽을 **기본값**으로 삼는다(다르게 하려면 물어볼 것).
- 관례를 따르느라 베스트 프랙티스를 조용히 버리지 말 것. "기존 파일들이 X를 쓴다"는 관찰은 X를 추천할 충분한 이유가 아니다.

## 3. 예산·검증 (기계 검증)

- 상주 표면(`commands/*.md`·`agents/*.md`·`skills/*/SKILL.md`의 단일 라인 `description:`) 합계 ≤ 300단어, 각 `skills/*/SKILL.md` 본문 ≤ 500단어. 유일한 증거는 `bash scripts/check_budget.sh` → `BUDGET OK`.
- 훅/스크립트 변경은 `bash tests/run.sh`(전부 통과) + `bash -n` + shellcheck로 검증. 결정적 로직은 프롬프트가 아니라 스크립트에 두고 골든/어서션 테스트를 붙인다.
- 로드되는 운영 파일(SKILL·커맨드·에이전트·스크립트·README)은 영어로, 채팅 리포트는 한국어로(mission 스펙 전역 규칙).
