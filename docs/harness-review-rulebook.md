# Harness Engineering Best Practices — Reviewing Agent용 룰북

버전 1.0 (2026-07-11) · 대상 독자: 하네스 설계·코드를 점검하는 AI 에이전트(및 엔지니어) · 형식: 규칙 ID + 근거 + 체크리스트 · 근거 소스는 §10

---

## 0. 이 문서를 읽는 에이전트에게 (사용 프로토콜)

당신(리뷰 에이전트)의 임무는 대상 하네스의 설계·코드·문서를 이 문서의 규칙에 대조하여 판정하는 것이다. 이 문서는 지식 자료가 아니라 **판정 기준(rulebook)**이다.

**0.1 규범 용어.** MUST(필수) / MUST NOT(금지) / SHOULD(강한 권장 — 위반 시 사유 문서화 요구) / MAY(선택).

**0.2 인용 규율.** 모든 발견사항(finding)은 규칙 ID를 인용한다. 규칙 ID 없는 지적은 "의견"으로 분류하고 판정에 반영하지 않는다.

**0.3 심각도.**
- `BLOCKER`: 검증 루프 부재(P-1), 비가역 행동 무게이트(SAFE-2), 인젝션 경계 부재(SAFE-3), 트랜스크립트 부재(OBS-1) → 머지/배포 불가
- `MAJOR`: 원칙(P-*) 또는 MUST 규칙 위반으로 신뢰성·재현성·재개가능성 훼손
- `MINOR`: SHOULD 위반, 효율/비용/스타일

**0.4 리포트 출력 포맷.**

```
## Harness Review Report
대상: <repo/branch/commit 또는 문서 버전>
판정: PASS | PASS_WITH_CONDITIONS | FAIL

### Findings
[SEVERITY][RULE-ID] <파일:위치 또는 설계 섹션> — <한 줄 요약>
  근거: <직접 관찰한 사실(코드/설정/로그)>
  수정: <구체적 변경안 — 코드/설정 수준으로>

### 미확인 (증거 부족으로 판정 불가한 규칙 ID)
### 강점 (선택)
```

**0.5 판정 우선순위.** 안전(SAFE) > 검증(VER) > 관측(OBS) > 상태/재개(STATE) > 단순성 > 비용/성능 > 스타일.

**0.6 증거 규율.** 코드·설정·로그에서 직접 확인한 것만 "위반"으로 보고한다. 추정은 "미확인"으로 분류한다. 자기 추론을 사실로 승격하지 않는다.

**0.7 판정 규칙.** BLOCKER ≥ 1 → FAIL. MAJOR만 존재 → PASS_WITH_CONDITIONS(수정 목록 필수). 핵심 항목(D-1, D-3, D-7, C-9)이 미확인이면 PASS 불가.

---

## 1. 정의와 범위

**1.1 Agent = Model + Harness.** 하네스는 모델을 제외한 에이전트의 전부다: 에이전트 루프, 도구 계층, 컨텍스트 조립, 검증, 상태/메모리, 권한, 관측, 평가. 2026년 업계 합의 정의이며, 하네스가 프로덕션 성능의 1차 결정 변수다. 실증: LangChain은 모델 교체 없이 하네스만 개선(구조화 검증 루프, 디렉토리 맵 주입, 루프 감지 미들웨어, 계획·검증 단계에 사고 집중)해 Terminal Bench 2.0 점수를 52.8%→66.5%로 올려 30위권에서 5위권에 진입했다.

**1.2 계보.** 프롬프트 엔지니어링(문구 최적화) ⊂ 컨텍스트 엔지니어링(창 안 정보 큐레이션) ⊂ 하네스 엔지니어링(창 밖 구조: 루프, 게이트, 컨텍스트 리셋, 세션 간 핸드오프, 검증 시스템). 하네스는 "정보와 행동의 배관" 설계다.

**1.3 핵심 강령 (Hashimoto 원칙).** "에이전트가 실수를 하면, 같은 실수를 다시는 못 하도록 공학적 해법을 만든다." 해법의 우선순위는 ① 검증기/게이트(결정적) ② 도구 개선 ③ 컨텍스트 개선 ④ 프롬프트 문구 — 프롬프트는 최후 수단이다.

**1.4 Guide와 Sensor (Böckeler 분류).** 하네스 요소는 두 방향으로 나뉜다.
- **Guide(feedforward)**: 행동 전에 좋은 결과 확률을 높이는 것 — 규칙 파일, 디렉토리 맵, 템플릿, 예제
- **Sensor(feedback)**: 행동 후에 결과를 감지·교정하는 것 — 컴파일러, 테스트, 린터, 훅, LLM 리뷰
각각 **computational(결정적, 저렴, 매 변경마다 실행)**과 **inferential(LLM 기반, 비싸고 비결정적, 선별 사용)**으로 다시 나뉜다. 리뷰 시 "이 요구는 guide인가 sensor인가, computational로 가능한가"를 항상 물어라.

**1.5 Workflow vs Agent (Anthropic 구분).** 코드가 제어 흐름을 소유하면 workflow, 모델이 루프 안에서 도구 피드백을 보고 다음 행동을 결정하면 agent. 경로를 미리 열거할 수 있는 문제에 agent를 쓰는 것은 그 자체로 설계 결함이다(P-5).

**1.6 적용 범위.** 단일 프로세스 CLI 에이전트(Claude Code류)부터 서버형 멀티에이전트 시스템까지. Claude Code 프리미티브 매핑은 §9.

---

## 2. 핵심 원칙 P-1 ~ P-12 (모든 하위 규칙의 상위 기준)

**P-1 (검증 루프 우선).** 하네스는 닫힌 피드백 루프다: 행동→관찰→검증→교정. 기계 검증 가능한 성공 신호(컴파일, 테스트, 스키마 검사, 스크린샷 diff 등)가 없는 태스크는 하네스를 만들기 전에 **태스크를 재설계**하라. 검증기 없는 에이전트 루프는 방향 없는 랜덤워크이며, 배포 불가(BLOCKER).
- 위반 신호: "완료"의 유일한 근거가 모델의 자기 주장.

**P-2 (결정성의 원칙).** 결정적으로 처리 가능한 모든 것은 코드로, 판단이 필요한 것만 모델로. 라우팅, 파싱, 재시도, 포맷 변환, 카운팅, 집계를 프롬프트로 시키는 설계는 비용과 오류율을 동시에 산다. "이 로직을 if문으로 쓸 수 있는가?" — 예라면 모델에게 시키지 마라.

**P-3 (컨텍스트는 예산).** 컨텍스트는 유한하고, 채울수록 회수 정확도가 떨어진다(context rot). 목표는 "기대 결과를 만드는 최소한의 고신호 토큰 집합". 턴당 예산을 코드로 관리하고 초과를 계측하라.

**P-4 (모델과 싸우지 않기 / bitter-lesson 호환성).** 모델 약점을 보완하려는 하드코딩 스캐폴드는 다음 모델에서 성능 상한이 된다. Anthropic의 하네스 설계 3원칙: ① 모델이 이미 아는 도구(bash, 파일, 표준 CLI) 위에 구축 ② 모델 능력이 오르면 하네스의 가정을 제거 ③ UX·비용·안전 경계는 신중히 설정. 실패마다 프롬프트에 특례 지시를 덧대는 패치 누적을 금지한다 — 근본 원인(1.3의 우선순위)을 고쳐라.

**P-5 (단순 우선).** 복잡도는 단일 LLM 호출 → workflow → single agent → multi-agent 순서로만, 각 단계는 **측정된 필요**가 있을 때만 올린다. 시작점은 항상 가장 단순한 형태다.

**P-6 (전면 관측).** 모델에 들어간 정확한 프롬프트 원문, 나온 모든 토큰, 모든 도구 호출과 결과를 재생 가능한 형태로 저장(MUST). "지금 이 턴에 모델에 정확히 무엇이 들어갔는가"에 즉답 못 하는 하네스는 디버깅 불가능하며 리뷰 불합격.

**P-7 (실패는 시끄럽고 유익하게).** 에러는 모델 독자를 가정하고 작성한다 — 무엇이 왜 실패했고 다음에 무엇을 하면 되는지. 조용한 catch, 빈 결과 반환, 스택트레이스 원문 덤프 모두 금지.

**P-8 (중단·재개 내성).** 어떤 턴에서 프로세스가 죽어도 디스크 상태만으로 재개 가능해야 한다. 부수효과 도구는 멱등하거나 멱등키를 받는다.

**P-9 (자기보고 불신).** 에이전트의 완료 주장·자체 요약·자체 평가는 신뢰 경계 밖의 검증기로 확인한다. maker와 checker의 컨텍스트를 분리하라 — 자기 추론 히스토리를 본 검증자는 이미 오염돼 있다.

**P-10 (최소 권한 · 가역성 게이트).** 기본 read-only, 쓰기·실행·네트워크는 명시 allowlist. 비가역 행동(삭제, 외부 발신, 결제, 배포, 권한 변경)은 휴먼 게이트 또는 강한 자동 게이트. 게이트는 프롬프트가 아니라 코드/훅으로 강제한다.

**P-11 (평가가 회귀 게이트).** 프롬프트 한 줄, 도구 설명 한 문장도 하네스 동작을 바꾼다. 현실 과업 기반 eval(초기 20개 내외면 충분)이 없으면 하네스 변경 금지. 채점은 결과 기반(최종 상태가 요구를 만족하는가) — 경로가 아니라 결과를 채점한다.

**P-12 (하네스도 제품).** 버전, 체인지로그, 자체 테스트, 문서를 갖춘다. "임시 스크립트" 상태로 운영 중인 하네스는 MINOR가 아니라 MAJOR 위반이다.

---

## 3. 참조 아키텍처

### 3.1 레이어 모델

```
┌───────────────────────────────────────────────────────┐
│ L7 Control Plane   권한 정책, 예산 상한, 휴먼 승인 게이트        │
│ L6 Observability   트레이스, 트랜스크립트, 비용 계측, Evals      │
├───────────────────────────────────────────────────────┤
│ L5 Orchestration   서브에이전트 위임, 병렬화, 태스크 계약         │
│ L4 Verification    훅/게이트, 오라클 계층, maker-checker 분리   │
│ L3 Context Mgmt    조립, 컴팩션, JIT 검색, 메모리 파일           │
│ L2 Tool Layer      레지스트리, 스키마 검증, 실행기, 샌드박스       │
│ L1 Agent Loop      상태기계, 종료 조건, 스톨 감지               │
│ L0 Model Interface API 클라이언트, 재시도, 스트리밍             │
└───────────────────────────────────────────────────────┘
        ⇅  디스크 = 단일 진실 원천 (single source of truth)
   state.json · NOTES.md · transcript.jsonl · git history
```

**3.2 (MUST) 디스크가 진실 원천.** 프로세스 메모리에만 존재하는 상태는 존재하지 않는 상태다. 루프의 모든 의미 있는 상태 전이는 디스크에 반영된다(P-8의 구조적 구현).

**3.3 (MUST) 실행 순서 불변식.** 모델은 도구를 직접 실행하지 않는다. 모델은 구조화된 도구 호출을 **반환**하고, 하네스가 ① 스키마 검증 → ② 권한 검사 → ③ 실행 → ④ 결과 성형 → ⑤ 주입 순서로 처리한다. 이 5단계 중 하나라도 생략된 경로가 있으면 MAJOR(인젝션이 코드 실행으로 승격되는 경로가 됨 — SAFE-3).

**3.4 MVP 구성.** L0–L4 + transcript가 최소 완결 단위다. L5(멀티에이전트)는 측정된 병목(컨텍스트 포화 실측 또는 3배 이상 병렬화 이득)이 있을 때만 추가한다(P-5).

---

## 4. 컴포넌트별 설계·구현 규격

### 4.1 Agent Loop (LOOP-*)

**LOOP-1 (MUST)** 루프는 명시적 상태기계다: `INIT → [ASSEMBLE → INFER → ACT → OBSERVE → CHECK]×N → VERIFY → DONE | FAIL | ESCALATE`. 상태 전이의 소유자는 코드다. 전이 조건이 코드에 없고 "모델이 알아서"에 의존하면 MAJOR.

**LOOP-2 (MUST)** 종료 조건 4종을 코드로 강제한다: ① max_turns 하드리밋 ② 토큰/비용 예산 ③ 명시적 완료 신호(완료 도구 호출 또는 구조화 출력 — 자연어 "다 했다"는 신호가 아니다) ④ 검증기 통과. ①②는 안전망, ③④가 정상 종료 경로다.

**LOOP-3 (MUST)** 스톨(stall) 감지: 연속 K턴(권장 3) 동안 상태 델타(파일 변경, 테스트 통과 수 증감, 신규 관찰)가 없으면 전략 전환 프롬프트를 주입하거나 ESCALATE. **동일 도구 + 동일 인자**의 반복 호출은 감지 즉시 차단하고 사유를 모델에 반환한다(루프 감지 미들웨어).

**LOOP-4 (MUST)** 완료의 2단계 게이트: 모델의 done 선언 → 하네스가 검증 스위트 실행 → 실패 시 실패 증거와 함께 루프로 자동 반려. 검증 없이 done을 수용하는 경로가 하나라도 있으면 BLOCKER(P-1, P-9).

**LOOP-5 (SHOULD)** 매 턴 transcript.jsonl에 append: {turn, prompt_hash, tool_calls, result_digest, usage, latency}. (OBS-1의 최소 구현)

**LOOP-6 (SHOULD)** 계획 단계 분리: 행동 전 계획을 산출물(파일)로 강제하면 사람/체커가 개입할 지점이 생기고, 사고 예산을 계획·검증 단계에 집중시킬 수 있다(LangChain "reasoning sandwich": 최대 사고를 계획과 검증에, 중간 실행은 가볍게).

**LOOP-7 (MAY)** 루프 유형을 태스크 형태에 맞춰 선택한다: turn-based(대화형 기본), goal-based(목표 달성까지 반복), time-based(스케줄/반복 실행), proactive. 어떤 유형이든 결정적 종료 조건과 토큰 예산은 동일하게 적용된다(LOOP-2).

### 4.2 Tool Layer (TOOL-*)

도구는 에이전트의 UI다(ACI, agent-computer interface). 도구 품질이 프롬프트 문구보다 성능에 크게 작용하는 경우가 많다.

**TOOL-1 (MUST)** 모든 입력은 JSON Schema로 선언·검증. 검증 실패 응답은 "무엇이 왜 틀렸고, 어떻게 고쳐 재호출할지"를 문장으로 담는다.

**TOOL-2 (MUST)** 에러 계약: `{ok:false, error_type, message, hint, retryable}`. message의 독자는 사람이 아니라 모델이다. 스택트레이스 원문 금지, 빈 문자열 금지, 침묵 금지.

```
✗ "Error: ENOENT"
✓ {ok:false, error_type:"file_not_found",
   message:"src/app.ts가 없음. 현재 작업 디렉토리는 /repo이며 상대경로 기준.",
   hint:"list_files로 실제 경로를 먼저 확인하라.", retryable:true}
```

**TOOL-3 (MUST)** 부수효과 도구는 멱등키 또는 dry-run을 제공한다. 재시도 정책의 소유자는 하네스(코드)다 — 모델에게 "실패하면 다시 시도해"라고 시키는 것은 정책이 아니다.

**TOOL-4 (MUST)** 출력은 고신호로 성형한다: 기본 truncation + "전체를 보려면 X 하라"는 후속 지시, 페이지네이션 기본값, 저신호 필드(uuid, raw HTML, 내부 메타) 제거, 기계 식별자는 사람이 읽는 이름으로 해석해 반환(id→name).

**TOOL-5 (SHOULD)** `response_format: "concise" | "detailed"` 파라미터로 토큰 소비를 호출자가 제어하게 한다.

**TOOL-6 (SHOULD)** 도구 수는 최소, 기능이 겹치는 도구 금지. 모델이 반복하는 고정 3단계 시퀀스는 하나의 상위 도구로 통합한다(예: `search_then_fetch`). 명명은 `동사_목적어`, 다중 서비스면 네임스페이스 접두(`jira_create_issue`).

**TOOL-7 (SHOULD)** 도구 설명(description)에 ① 언제 쓰는지 ② 언제 쓰면 **안** 되는지 ③ 입출력 예시 1개를 포함한다. 도구 설명은 프롬프트다 — eval로 A/B 검증 대상이다.

**TOOL-8 (MUST)** 실행기에서 타임아웃·출력 바이트 상한·리소스 상한을 강제한다. 상한 초과는 TOOL-2 형식의 에러로 반환한다.

**TOOL-9 (SHOULD)** 읽기 도구와 쓰기 도구를 물리적으로 분리해 권한 계층(SAFE-1)이 도구 단위로 걸리게 한다.

### 4.3 Context Manager (CTX-*)

**CTX-1 (MUST)** 시스템 프롬프트는 "올바른 고도"를 유지한다: 케이스별 if-else 나열(취약, 유지보수 불가) ✗, 모호한 격언("좋은 코드를 써라") ✗. 담을 것은 역할, 불변 규칙, 도구 사용 원칙, 출력 계약뿐이며 명시적 섹션(`<role>`, `<rules>`, `<output_contract>` 등)으로 구분한다.

**CTX-2 (MUST)** 사전 적재 최소화, just-in-time 검색이 기본값. 대용량 자료는 경로/식별자만 주고 도구로 필요한 부분만 읽게 한다(progressive disclosure). 디렉토리 맵·인덱스 같은 가벼운 guide는 상주시켜도 좋다.

**CTX-3 (MUST)** 컴팩션 정책을 명시한다: 트리거 임계(예: 창의 70–80%), 절대 보존 목록(시스템 프롬프트, 태스크 계약, 최근 N턴, 미해결 결정), 제거 우선순위(오래된 도구 결과 원문부터), 요약본의 디스크 이중 저장(복구 가능성). "무엇을 절대 버리지 않는가"가 정책의 핵심이다.

**CTX-4 (MUST)** 구조화 노트: 장기 태스크는 NOTES.md(또는 동급)에 진행 상태·핵심 결정·실패 원인을 기록하고 세션/컴팩션 경계에서 재적재한다. 컨텍스트 창 밖의 기억은 전부 디스크로(3.2).

**CTX-5 (SHOULD)** 턴당 컨텍스트 예산표를 코드로 관리한다(예: 시스템 10% / 태스크·노트 15% / 히스토리 45% / 도구 결과 30%). 초과 시 축소 우선순위를 고정한다.

**CTX-6 (SHOULD)** 도구 결과는 히스토리에 성형본만 남기고 원문은 파일 참조로 대체한다.

**CTX-7 (MUST NOT)** "혹시 몰라서" 넣는 문서·스키마·예시 금지. 컨텍스트의 모든 토큰에는 존재 이유가 있어야 한다(P-3).

### 4.4 Verification Layer (VER-*)

**VER-1 (MUST)** 오라클 계층을 상위부터 사용한다: ① 결정적 검사(컴파일·타입체크·테스트·스키마·린트 — computational sensor) ② 코드로 쓴 도메인 규칙 검사 ③ LLM 판정(inferential sensor)은 루브릭 기반으로 최후에만. **결정적 오라클이 존재하는 속성을 LLM 판정으로 대체하는 것은 MAJOR.**

**VER-2 (MUST)** maker/checker 분리: 검증자는 제작자의 추론 히스토리를 보지 않는 fresh context에서 실행하며, 입력은 산출물 + 요구사항뿐이다.

**VER-3 (MUST)** 증거 기반 완료: 완료 판정에는 검증 실행 로그(명령, exit code, 출력 요지)가 첨부돼야 한다. 로그 없는 완료 = 미완료로 취급한다.

**VER-4 (SHOULD)** 결정적 게이트를 훅으로 루프에 박는다: 행동 전(위험 명령·경로 차단), 행동 후(포맷터/린터/타입체크 자동 실행), 종료 전(테스트 스위트). 게이트 실패는 사유와 함께 모델에게 반환되어 다음 턴 입력이 된다.

**VER-5 (SHOULD)** 검증 비대칭을 활용해 태스크를 쪼갠다: 생성은 어려워도 검증이 쉬운 단위(단일 기능 + 해당 e2e 테스트)로.

**VER-6 (MUST NOT)** 체커가 실패를 "지적만" 하고 루프가 이를 소비하지 않는 구조 금지 — 검증 실패는 반드시 다음 턴의 입력이 된다(개방 루프 금지).

### 4.5 Orchestration / Subagents (ORCH-*)

**ORCH-1 (MUST)** 서브에이전트의 정당한 사유는 둘뿐이다: ① 컨텍스트 격리(대량 탐색·검증을 본 루프 창 밖에서 수행) ② 병렬화(읽기 전용 조사·검증). "역할극"이나 조직도 모방은 사유가 아니다.

**ORCH-2 (MUST)** single-writer 원칙: 코드/문서의 변형은 한 시점에 한 에이전트만 수행한다. 병렬 쓰기 멀티에이전트는 암묵적 결정 충돌이 복리로 쌓여 비일관을 만든다(Cognition의 논거). 병렬화는 읽기·조사·독립 검증에 한정한다.

**ORCH-3 (MUST)** 태스크 계약 없는 위임 금지. 계약 필수 필드: `objective`(목표), `context_digest`(최소 배경), `output_contract`(형식과 저장 경로), `tool_allowlist`, `budget`(턴/토큰), `done_criteria`(완료 기준). 모호한 위임("X 조사해줘")은 중복 작업과 공백을 낳는다.

**ORCH-4 (MUST)** 대형 산출물은 파일로 저장하고 참조를 반환한다. 오케스트레이터가 서브에이전트 결과를 자연어로 재요약해 전달하는 전화게임(정보 손실 체인)을 금지한다.

**ORCH-5 (SHOULD)** 노력 스케일링 규칙을 명시한다(Anthropic 멀티에이전트 리서치 휴리스틱): 단순 사실 확인 = 에이전트 1개·도구 호출 3–10회, 직접 비교 = 서브에이전트 2–4개, 대규모 조사 = 10개 이상. 기본값은 항상 "적게".

**ORCH-6 (SHOULD)** 멀티에이전트는 토큰 소비가 단일 채팅 대비 한 자릿수 배(Anthropic 보고 기준 약 15배)로 뛴다. 태스크 가치가 이를 정당화하고 병렬화 가능한 구조일 때만 채택한다(P-5).

### 4.6 State & Memory (STATE-*)

**STATE-1 (MUST)** 상태 스키마를 버전과 함께 정의한다(state.json): 태스크 계약, 완료 기준 체크리스트(항목별 binary pass/fail + 증거 링크), 현재 단계, 재개 포인터.

**STATE-2 (MUST)** 체크포인트: 의미 있는 작업 단위마다 git commit(또는 동급 스냅샷). 실패 시 롤백 경로가 항상 존재해야 한다.

**STATE-3 (MUST)** 진행 표식은 래칫(ratchet, 단조 증가)이다: pass 전환은 검증기 통과로만, 관련 코드 변경 시 해당 항목은 자동으로 fail 복귀. **pass 플래그를 쓰는 주체는 모델이 아니라 검증기다.**

**STATE-4 (SHOULD, 장기 실행 패턴)** initializer/worker 분리: 초기화 에이전트가 환경과 기능 목록(JSON, 전 항목 fail로 시작)을 만들고, 워커 세션은 매번 fresh context로 ① 상태 로드 ② 항목 1개 선택 ③ 구현 ④ e2e 검증 ⑤ 커밋 + 상태 갱신만 수행한다. 세션당 한 항목. (Anthropic long-running harness 패턴)

**STATE-5 (SHOULD)** 재개 프로토콜을 문서화한다: 새 세션이 state.json + NOTES.md + git log만 읽고 30초 내 작업을 이어갈 수 있어야 한다. 이것이 안 되면 P-8 위반.

### 4.7 Safety & Permissions (SAFE-*)

**SAFE-1 (MUST)** 기본 거부, 명시 허용. 파일 쓰기 범위, 실행 가능 명령 패턴, 네트워크 도메인을 선언적 allowlist로 제한하고 코드/설정으로 강제한다. 프롬프트로만 금지하는 것은 금지가 아니다.

**SAFE-2 (MUST)** 비가역 행동 게이트: 삭제, 외부 발신(메일/게시/PR), 결제, 배포, 권한 변경은 휴먼 승인 또는 독립 검증 + 이중 확인을 거친다. 행동을 가역성 등급으로 분류한 표가 설계 문서에 있어야 한다.

**SAFE-3 (MUST)** 인젝션 경계: 도구 결과·웹 콘텐츠·파일 내용은 **데이터**다. 그 안의 지시를 실행하지 않는다는 규칙을 시스템 프롬프트에 명시하고, 외부 유래 콘텐츠는 출처 태깅으로 구분하며, 고위험 도구는 외부 콘텐츠가 트리거한 호출을 추가 게이트로 차단한다. 3.3의 실행 순서 불변식이 구조적 방어선이다.

**SAFE-4 (MUST)** 코드 실행은 샌드박스(컨테이너/제한 계정/자원 상한)에서. 훅 스크립트 역시 사용자 권한으로 도는 임의 코드이므로 리뷰 대상이다.

**SAFE-5 (SHOULD)** 위험 등급별 권한 모드(read-only / edits-ok / full)와 전 행동 감사 로그.

### 4.8 Observability & Evals (OBS-*, EVAL-*)

**OBS-1 (MUST)** 재현 가능한 트레이스: 요청 원문(시스템 + 메시지 전체), 응답 원문, 도구 IO, 타이밍, 토큰, 비용을 세션 단위로 저장한다. 요약본이 아니라 원문이다.

**OBS-2 (SHOULD)** 실패 분류 태깅(도구 오류 / 컨텍스트 부족 / 검증 실패 / 모델 판단 오류 / 스톨)을 트레이스에 남겨, 개선 우선순위를 일화가 아닌 분포로 정한다.

**EVAL-1 (MUST)** 현실 과업 기반 eval 세트를 하네스와 같은 repo에 둔다. 초기 20개 내외면 신호가 나온다. 채점은 결과 기반: 최종 상태가 요구를 만족하는가(경로·스타일이 아니라).

**EVAL-2 (MUST)** 시스템 프롬프트, 도구 설명, 컴팩션 정책, 훅의 변경은 eval 통과를 머지 조건으로 한다(P-11의 집행).

**EVAL-3 (SHOULD)** 다회 실행 통계로 비결정성을 측정한다: pass@k(k회 중 1회 이상 성공)와 신뢰성 지표 pass^k(k회 전부 성공). 프로덕션 신뢰성 주장에는 pass^k를 사용한다.

**EVAL-4 (SHOULD)** 주기적 트랜스크립트 정독 루틴을 유지한다. 집계 지표가 놓치는 실패 양식(교묘한 우회, 검증 회피, 이상 반복)은 원문에서만 보인다.

---

## 5. 안티패턴 카탈로그 (AP-*)

형식: 증상 → 원인 → 수정. 리뷰 시 해당 AP를 발견하면 연결된 규칙 ID로 판정한다.

**AP-1 프롬프트 패치 누적.** 실패할 때마다 지시 한 줄 추가 → 시스템 프롬프트가 if-else 늪이 되고 다음 모델에서 부채화 → 근본 원인 우선순위(1.3)로 수정하고, 특례 지시를 분기마다 다이어트한다. [P-4, CTX-1]

**AP-2 컨텍스트 스터핑.** "관련될 수도 있는" 문서·스키마 전부 사전 적재 → 회수 정확도 하락, 비용 폭증 → JIT 검색 + 경로 참조로 전환. [CTX-2, CTX-7]

**AP-3 도구 스프롤.** 기능이 겹치는 도구 다수, 어떤 것을 쓸지 모델이 헷갈림 → 통합·삭제, 설명에 "언제 쓰지 마라" 명시. [TOOL-6, TOOL-7]

**AP-4 자기보고 신뢰.** "테스트 통과했습니다"를 검증 없이 수용 → 미완성 산출물 배포 → 완료 2단계 게이트 + 증거 첨부. [LOOP-4, VER-3, P-9]

**AP-5 전화게임 요약.** 서브에이전트 결과를 오케스트레이터가 재요약해 전달 → 정보 손실 복리 → 파일 참조 반환. [ORCH-4]

**AP-6 스톨 루프.** 같은 실패를 같은 방법으로 반복 → 예산 소진 → 상태 델타 기반 스톨 감지 + 전략 전환 주입 + 동일 호출 차단. [LOOP-3]

**AP-7 조용한 실패.** 도구가 catch 후 빈 결과 반환 → 모델이 "결과 없음"으로 오판하고 진행 → 구조화 에러 계약 강제. [TOOL-2, P-7]

**AP-8 모델에게 예산 관리 위임.** "남은 턴을 세면서 작업해" → 모델은 카운터가 아니다 → 코드가 카운트하고 남은 예산을 상태로 주입. [P-2, LOOP-2]

**AP-9 비멱등 재시도.** 재시도 정책 + 부수효과 도구에 멱등키 없음 → 이중 발송/이중 생성 → 멱등키 또는 dry-run. [TOOL-3]

**AP-10 숨은 상태.** 진행 상태가 프로세스 메모리에만 존재 → 크래시 시 전손, 디버깅 불가 → 디스크 단일 진실 원천. [3.2, STATE-1]

**AP-11 과잉 오케스트레이션.** 단일 파일 수정에 멀티에이전트 → 15배 비용, 충돌 위험 → workflow 또는 single agent로 강등. [P-5, ORCH-6]

**AP-12 바이브 반복.** eval 없이 일화 기반으로 프롬프트 수정 → 개선인지 회귀인지 알 수 없음 → eval 세트를 머지 게이트로. [P-11, EVAL-2]

**AP-13 판사 남용.** 컴파일·테스트로 검증 가능한 속성을 LLM 판정에 맡김 → 비싸고 비결정적 → 오라클 계층 준수. [VER-1]

**AP-14 지시-데이터 혼동.** 웹 페이지/파일 안의 지시문을 실행 → 인젝션이 행동으로 승격 → 출처 태깅 + 경계 규칙 + 게이트. [SAFE-3]

**AP-15 동결 스캐폴드.** 모델 약점 보완용 하드코딩이 모델 업그레이드 후 성능 상한이 됨 → 모델 릴리스마다 하네스 가정 재검토·제거. [P-4]

**AP-16 개방 검증 루프.** 검증기가 실패를 로그에만 남기고 루프가 소비하지 않음 → 실패가 교정으로 이어지지 않음 → 검증 실패는 반드시 다음 턴 입력. [VER-6]

---

## 6. 리뷰 체크리스트

### 6.1 설계 리뷰 (D-*) — 각 항목은 예/아니오로 판정

- **D-1** 태스크의 기계 검증 가능한 성공 신호가 정의되어 있는가? [P-1] — 아니오면 BLOCKER
- **D-2** workflow로 충분한 문제를 agent로 풀고 있지 않은가? [P-5, 1.5]
- **D-3** 종료 조건 4종(턴/예산/완료신호/검증)이 설계에 명시되어 있는가? [LOOP-2]
- **D-4** 컨텍스트 예산과 컴팩션 정책(보존 목록 포함)이 문서화되어 있는가? [CTX-3, CTX-5]
- **D-5** maker/checker 분리가 설계에 있는가? [VER-2]
- **D-6** 상태가 디스크 스키마로 정의되고 재개 프로토콜이 있는가? [STATE-1, STATE-5]
- **D-7** 비가역 행동 목록과 게이트가 있는가? [SAFE-2] — 아니오면 BLOCKER
- **D-8** eval 세트와 머지 게이트가 있는가? [EVAL-1, EVAL-2]
- **D-9** (멀티에이전트인 경우) 격리/병렬화 사유가 명시되고 single-writer가 지켜지는가? [ORCH-1, ORCH-2]
- **D-10** 프롬프트 원문 수준의 재생이 가능한 관측 설계인가? [OBS-1]
- **D-11** 각 하네스 요소가 guide/sensor, computational/inferential로 분류되어 있고, computational로 가능한 것을 inferential로 하고 있지 않은가? [1.4, VER-1]
- **D-12** 모델 업그레이드 시 제거할 하네스 가정이 식별되어 있는가? [P-4]

### 6.2 코드 리뷰 (C-*)

- **C-1** 루프 상태 전이가 코드로 명시돼 있는가(암묵 전이 없음)? [LOOP-1]
- **C-2** max_turns / 예산 하드리밋이 코드에 있는가? [LOOP-2]
- **C-3** 동일 도구+동일 인자 반복 차단과 상태 델타 스톨 감지가 있는가? [LOOP-3]
- **C-4** 도구 입력 스키마 검증 + 구조화 에러 계약이 구현돼 있는가? [TOOL-1, TOOL-2]
- **C-5** 도구 출력 truncation/pagination 기본값이 있는가? [TOOL-4]
- **C-6** 부수효과 도구에 멱등키 또는 dry-run이 있는가? [TOOL-3]
- **C-7** 실행기에 타임아웃과 출력 바이트 상한이 있는가? [TOOL-8]
- **C-8** 컴팩션 트리거와 절대 보존 목록이 코드에 있는가? [CTX-3]
- **C-9** 검증기 실행이 완료 경로에 배선돼 있는가(우회 경로 없음)? [LOOP-4, VER-6] — 아니오면 BLOCKER
- **C-10** 검증 로그가 상태 파일에 증거로 남는가? [VER-3]
- **C-11** 트랜스크립트가 원문 수준으로 append되는가? [OBS-1]
- **C-12** allowlist가 코드/설정으로 강제되는가(프롬프트 의존 아님)? [SAFE-1]
- **C-13** 외부 유래 콘텐츠의 지시-데이터 경계 처리가 있는가? [SAFE-3]
- **C-14** 서브에이전트 위임에 태스크 계약 필드 검사가 있는가? [ORCH-3]
- **C-15** pass 플래그를 쓰는 주체가 검증기인가(모델이 직접 쓰지 못함)? [STATE-3]
- **C-16** 시스템 프롬프트/도구 설명 변경이 eval을 거치는 CI 배선이 있는가? [EVAL-2]

### 6.3 판정 합산

0.7의 규칙을 적용한다. 추가로: 미확인 항목이 전체의 30%를 넘으면 "판정 보류 — 증거 요청 목록"을 우선 출력한다.

---

## 7. 결정 규칙 (빠른 참조)

**7.1 Workflow vs Agent.** 실행 경로를 사전에 열거할 수 있는가? → 예: workflow(prompt chaining / routing / parallelization / orchestrator-workers / evaluator-optimizer 중 택1). 아니오(도구 피드백을 봐야 다음 행동이 정해짐): agent.

**7.2 단일 vs 멀티에이전트.** 컨텍스트 창 포화가 실측되었거나 읽기 병렬화 이득이 3배 이상인가? → 예: 멀티(단, single-writer 유지). 아니오: 단일. 비용 배수(~15×)를 항상 명시적으로 정당화한다.

**7.3 새 도구 vs 기존 조합.** 모델이 같은 다단계 시퀀스를 3회 이상 반복하는가? → 통합 도구 신설. 1회성인가? → bash/코드 실행으로 처리.

**7.4 상주 vs JIT.** 매 턴 필요하고 작다(수백 토큰) → 컨텍스트 상주. 크거나 간헐적 → 경로만 주고 도구로 읽게 한다.

**7.5 검증 수단 선택.** computational sensor로 표현 가능한가? → 항상 그것부터. inferential(LLM judge)은 의미·취향 판단이 불가피할 때 루브릭과 함께 최후에.

**7.6 모델 티어.** 오케스트레이터/체커 = 상위 모델, 대량 병렬 워커 = 중위 모델로 시작해 eval 결과로 조정한다.

**7.7 프레임워크.** 루프를 숨기는 추상화보다 프리미티브를 노출하는 SDK 또는 자작 루프(코어 500 LOC 이내)를 우선한다. 판별 질문: "지금 이 턴에 모델에 정확히 무엇이 들어갔는지 1분 안에 출력할 수 있는가?" — 아니오면 그 프레임워크는 실격.

**7.8 사람의 위치.** 하네스의 목표는 인간 제거가 아니라 인간 입력을 가장 가치 있는 지점(비가역 게이트, 취향 판단, 요구 정의)으로 재배치하는 것이다. "Humans steer. Agents execute."

---

## 8. 최소 구현 스켈레톤 (TypeScript)

핵심 불변식(LOOP-1~4, TOOL-2/4/8, VER-3/6, OBS-1)이 코드 어디에 배선되는지를 보여주는 참조 골격이다. 프로덕션에서는 스키마 검증(ajv 등), 컴팩션, 권한 계층을 추가한다.

```typescript
// harness.ts — 검증 루프 + 종료 조건 + 스톨 감지 + 관측이 배선된 최소 골격
import Anthropic from "@anthropic-ai/sdk";
import { appendFileSync } from "node:fs";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
const exec = promisify(execFile);

type ToolDef = {
  name: string;
  description: string;          // TOOL-7: 언제 쓰는지/안 쓰는지/예시
  input_schema: object;
  execute: (input: unknown) => Promise<string>;
  sideEffect?: boolean;         // TOOL-9: 권한 계층 분리 지점
};

const BUDGET = { maxTurns: 30, maxToolOutChars: 4_000, toolTimeoutMs: 60_000 }; // LOOP-2 ①②

const log = (e: object) =>                                       // OBS-1 / LOOP-5
  appendFileSync("transcript.jsonl", JSON.stringify({ t: Date.now(), ...e }) + "\n");

const truncate = (s: string, n: number) =>
  s.length <= n ? s : s.slice(0, n) + `\n[…truncated ${s.length - n} chars — 필요 시 범위를 좁혀 재호출]`; // TOOL-4

async function runTool(tool: ToolDef, input: unknown): Promise<string> {
  try {
    const out = await Promise.race([
      tool.execute(input),
      new Promise<never>((_, rej) =>
        setTimeout(() => rej(new Error("timeout")), BUDGET.toolTimeoutMs)), // TOOL-8
    ]);
    return truncate(out, BUDGET.maxToolOutChars);
  } catch (e: any) {                                              // TOOL-2: 구조화 에러, 모델 독자용
    return JSON.stringify({
      ok: false, error_type: e?.code ?? e?.name ?? "tool_error",
      message: String(e?.message ?? e),
      hint: "인자를 점검하거나 선행 조회 도구로 전제를 확인한 뒤 재호출하라.",
      retryable: true,
    });
  }
}

async function verify(): Promise<{ pass: boolean; evidence: string }> {   // VER-1: 결정적 오라클 우선
  try {
    const r = await exec("npm", ["test", "--silent"]);
    return { pass: true, evidence: `exit=0\n${r.stdout.slice(-2000)}` };
  } catch (e: any) {
    return { pass: false, evidence: `exit=${e?.code}\n${String(e?.stdout ?? "").slice(-2000)}` };
  }
}

export async function runAgent(task: string, tools: ToolDef[], system: string) {
  const client = new Anthropic();
  const messages: Anthropic.MessageParam[] = [{ role: "user", content: task }];
  let lastDigest = "", stall = 0;

  for (let turn = 1; turn <= BUDGET.maxTurns; turn++) {           // LOOP-2 ① 하드리밋
    const res = await client.messages.create({
      model: "claude-sonnet-4-6",
      max_tokens: 4096,
      system,                                                     // CTX-1: 역할/불변규칙/출력계약만
      messages,
      tools: tools.map(({ execute, sideEffect, ...t }) => t as Anthropic.Tool),
    });
    log({ turn, usage: res.usage, stop: res.stop_reason });

    const toolUses = res.content.filter(b => b.type === "tool_use");

    if (toolUses.length === 0) {                                  // 모델의 done 선언(LOOP-2 ③)
      const v = await verify();                                   // LOOP-4: 검증 게이트(LOOP-2 ④)
      log({ turn, verified: v.pass });
      if (v.pass) return { status: "DONE" as const, turns: turn, evidence: v.evidence }; // VER-3
      messages.push({ role: "assistant", content: res.content });
      messages.push({ role: "user",
        content: `완료 검증 실패. 증거:\n${v.evidence}\n원인을 수정하고 계속하라.` });    // VER-6: 실패는 다음 턴 입력
      continue;
    }

    messages.push({ role: "assistant", content: res.content });
    const results: Anthropic.ToolResultBlockParam[] = [];
    for (const tu of toolUses) {
      const tool = tools.find(t => t.name === tu.name);
      const out = tool ? await runTool(tool, tu.input)
        : JSON.stringify({ ok: false, error_type: "unknown_tool",
            message: `${tu.name}은 등록되지 않은 도구.`, hint: "제공된 도구 목록만 사용하라.", retryable: false });
      log({ turn, tool: tu.name, input: tu.input, out: out.slice(0, 500) });
      results.push({ type: "tool_result", tool_use_id: tu.id, content: out });
    }
    messages.push({ role: "user", content: results });

    const digest = JSON.stringify(toolUses.map(t => [t.name, t.input])); // LOOP-3: 스톨 감지
    stall = digest === lastDigest ? stall + 1 : 0;
    lastDigest = digest;
    if (stall >= 2) {
      messages.push({ role: "user",
        content: "경고: 동일 행동 반복 감지. 지금까지의 가설을 요약하고 다른 접근을 채택하라." });
      stall = 0;
    }
    // 컴팩션(CTX-3): 토큰 추정 > 임계 시 — 보존 목록 유지, 오래된 tool_result부터 요약 (구현 생략)
  }
  return { status: "FAIL" as const, reason: "max_turns" };        // ESCALATE 지점: 사람에게 상태 파일과 함께 반환
}
```

이 골격에서 리뷰어가 확인해야 할 배선: ① done 선언 → verify() 를 우회하는 return 경로가 없는가(C-9) ② 모든 도구 경로가 runTool의 truncation/에러 계약을 통과하는가(C-4, C-5) ③ transcript가 원문 수준인가 — 위 코드는 out을 500자로 자르므로 프로덕션에서는 전문을 별도 파일로 저장해야 OBS-1을 충족한다.

---

## 9. Claude Code 매핑 표 (하네스 구성요소 → Claude Code 프리미티브)

Claude Code 위에 하네스를 구축·리뷰할 때의 대응표. 이벤트/필드 명세는 버전에 따라 진화하므로, 판정 시에는 대상 repo가 참조하는 공식 문서(code.claude.com/docs) 버전을 기준으로 한다.

| 하네스 구성요소 | Claude Code 프리미티브 | 관련 규칙 |
|---|---|---|
| 상주 규칙/역할 (guide) | CLAUDE.md(사용자/프로젝트 계층, @import), output style | CTX-1 |
| 도구 계층 | 내장 도구(Bash, Edit, Read, Glob, Grep 등) + MCP 서버 | TOOL-* |
| 결정적 게이트 (sensor) | hooks — PreToolUse(사전 차단), PostToolUse/PostToolUseFailure(사후 검사·포맷), Stop(턴 종료 게이트), UserPromptSubmit·SessionStart(컨텍스트 주입), PreCompact(체크포인트), SubagentStart/SubagentStop | VER-4, LOOP-4 |
| 게이트의 통신 규약 | exit 0 + stdout JSON = 결정 전달, exit 2 + stderr = 차단·사유가 모델에 피드백 | VER-6, P-7 |
| 훅 핸들러 유형 | command(셸), HTTP, prompt, MCP tool, agent | VER-1 (computational→command, inferential→prompt/agent) |
| 권한/allowlist | settings.json의 allow/deny 규칙, permission mode, 관리형 설정(allowManagedHooksOnly) | SAFE-1, SAFE-5 |
| 컨텍스트 격리/병렬 | subagents(독립 컨텍스트·도구·모델 지정), Task 위임 | ORCH-1, ORCH-2 |
| 컴팩션 | 자동 컴팩션 + PreCompact 훅에서 NOTES 체크포인트 | CTX-3, CTX-4 |
| 상태/메모리 | 작업 파일(state.json, NOTES.md) + git + CLAUDE.md 계층 | STATE-* |
| 배포 단위 | plugin(commands + agents + hooks + MCP 번들) | P-12 |
| 헤드리스/CI | `claude -p`(비대화 모드) + JSON 출력 → eval 러너로 사용 | EVAL-* |

주의 2가지. ① CLAUDE.md는 **요청**이고 훅은 **보장**이다 — "반드시"가 붙는 요구를 CLAUDE.md에만 두면 MAJOR(SAFE-1, VER-4). ② 훅은 사용자 권한으로 실행되는 임의 코드이며 샌드박스가 없다 — 훅 스크립트 자체가 SAFE-4 리뷰 대상이다.

---

## 10. 참고 문헌 (근거 소스)

이 문서의 규칙은 아래 1차 소스의 공개된 실증·권고를 종합한 것이다.

1. Anthropic — Building Effective Agents (2024): workflow/agent 구분, 패턴 5종, 단순 우선
2. Anthropic — How we built our multi-agent research system (2025): orchestrator-worker, 노력 스케일링, 토큰 비용 배수
3. Anthropic — Writing effective tools for AI agents (2025): 도구 통합, 토큰 효율 응답, response_format
4. Anthropic — Effective context engineering for AI agents (2025): context rot, 최소 고신호 토큰, JIT 검색, 컴팩션, 구조화 노트
5. Anthropic — Effective harnesses for long-running agents (2025): initializer/worker, 기능 목록 JSON, 세션당 1항목, e2e 증거
6. Anthropic — Agent Harness Design: 3 Patterns (2026): 모델이 아는 도구 위 구축, 가정 제거, 경계 설정
7. Anthropic — Claude Code hooks reference / getting started with loops (2026): 훅 이벤트·exit code 규약, 루프 유형 분류
8. Mitchell Hashimoto (2026): 하네스 엔지니어링 강령 — 같은 실수의 재발을 공학적으로 봉쇄
9. OpenAI, Ryan Lopopolo (2026): 무수작업 코드 프로덕션 사례, "Humans steer. Agents execute."
10. LangChain (2026): Terminal Bench 2.0 하네스-온리 개선(52.8→66.5%, Top30→Top5) — 검증 루프, 컨텍스트 주입, 루프 감지, reasoning sandwich
11. Birgitta Böckeler, martinfowler.com — Harness engineering for coding agent users (2026): guide/sensor, computational/inferential 분류
12. Cognition — Don't Build Multi-Agents (2025): single-writer 논거(암묵 결정 충돌)
13. SWE-agent, Yang et al. (2024): ACI(agent-computer interface) 개념

— 끝. 이 문서 자체도 P-12를 따른다: 규칙 추가·수정 시 버전을 올리고, 변경이 리뷰 판정을 바꾸는 경우 changelog에 기록할 것.
