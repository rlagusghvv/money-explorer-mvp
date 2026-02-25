# Task #4 앱 안정성 우선 QA 리포트

- 일시: 2026-02-25 10:30~
- 대상: `kid_econ_mvp`
- 목적: 코어 플로우 안정성 점검 + 로컬 검증 + 저위험 런타임 가드 반영

## 1) 안정성 QA 체크리스트 및 실행 결과

| 항목 | 방법 | 결과 | 비고 |
|---|---|---|---|
| 앱 실행(launch) | `flutter run -d emulator-5554` | **PASS** | Android 에뮬레이터에서 APK 설치/실행 및 VM Service 기동 확인 |
| 온보딩 | 코드 경로 점검 + 부팅 위젯 테스트 | **PARTIAL** | 자동화된 UI 시나리오 부재로 전체 탭/버튼 수동 E2E는 미수행 |
| 로그인/회원가입 | 코드 경로 점검(`auth_sync_service`) | **PARTIAL** | 실제 서버 계정 기반 상호작용 E2E 미수행 |
| 메인 문제 풀이 플로우 | 시나리오 로딩/파싱 경로 점검 + 가드 추가 | **PASS (코드경로)** | malformed JSON 대응 가드 추가로 크래시 리스크 완화 |
| 데일리 미션 수령 | 상태 필드/복원 코드 경로 점검 | **PARTIAL** | 실제 일자 변경/서버 동기화 UI 시뮬레이션 미수행 |
| 오답노트 복습 | wrong-note 역직렬화 경로 점검 | **PARTIAL** | 런타임 E2E 미수행 |
| MyHome 편집 인터랙션 | 관련 저장/복원 코드 경로 점검 | **PARTIAL** | 드래그/스케일 제스처 수동 E2E 미수행 |
| 저장/복원(save/restore) | JSON 역직렬화 가드/폴백 점검 | **PASS (코드경로)** | 시나리오 데이터 파싱 실패 시 안전 폴백/스킵 처리 |

> 주의: 본 Task에서는 통합 테스트 자동화가 준비되어 있지 않아, 핵심 UI 플로우의 완전 수동 E2E는 제한적으로만 검증했습니다.

## 2) 로컬 검증 결과

### 2-1. 정적/단위 검증
- `flutter analyze` → **PASS (No issues found)**
- `flutter test` → **PASS (All tests passed, 1 test)**

### 2-2. Android 에뮬레이터 스모크
- 기기: `emulator-5554 (sdk gphone64 arm64)`
- 명령: `flutter run -d emulator-5554 --debug --target lib/main.dart`
- 결과: **PASS**
  - APK 빌드/설치 성공
  - 앱 실행 후 VM Service endpoint 노출 확인
  - 시작 직후 치명 크래시 재현 없음

### 2-3. 웹 빌드 sanity (econ)
- `flutter build web` → **PASS**
- 산출물: `build/web`

## 3) 적용한 저위험 런타임 가드(코드 변경)

### 변경 파일
1. `lib/models/scenario.dart`
   - 강제 캐스팅(`as`) 위주의 파싱을 안전 파서 기반으로 완화
   - `_asInt`, `_asString`, `_asStringList`, `_asOptionList` 헬퍼 도입
   - JSON 값 이상/누락 시 폴백값 반환하여 런타임 예외 리스크 축소

2. `lib/data/scenario_repository.dart`
   - JSON 루트 타입/`scenarios` 타입 검증 추가
   - 개별 시나리오 파싱 실패 시 전체 중단 대신 해당 항목만 skip

## 4) 배포/재기동 및 헬스체크

코드 변경이 있어 econ 배포 수행:
1. `flutter build web`
2. `rsync -a --delete kid_econ_mvp/build/web/ coupang-automation/public/econ/`
3. `coupang-automation/scripts/server-bg.sh restart`

### 운영 고정 체크리스트 결과
- `/app` 200: **PASS** (`http://127.0.0.1:3000/app/`)
- `/econ` 200: **PASS** (`http://127.0.0.1:3000/econ/`)
- 정적 파일 200: **PASS**
  - `/econ/index.html`
  - `/econ/main.dart.js`
- 재시작 후 외부 헬스체크: **PASS**
  - `https://app2.splui.com/app/` → 200
  - `https://app2.splui.com/econ/` → 200
  - `https://app2.splui.com/econ/index.html` → 200
  - `https://app2.splui.com/econ/main.dart.js` → 200

## 5) Known Issues / Remaining Risks

1. **UI 통합 테스트 부재**
   - 온보딩/로그인/데일리미션/MyHome 제스처 등은 완전 자동화 회귀망이 없음
2. **시나리오 데이터 품질 의존성**
   - 파싱 가드로 크래시는 줄였으나, 데이터 이상 시 일부 시나리오가 silently skip 될 수 있음(서비스 관측/로그 보강 권장)
3. **테스트 커버리지 제한**
   - 현재 `flutter test`는 기본 부팅 테스트 위주(1건)

---

결론: **안정성 관점의 크래시 리스크는 개선되었고, 빌드/배포/헬스체크는 모두 통과**. 다만 핵심 사용자 플로우의 완전 E2E 회귀 자동화는 후속 과제로 남아 있음.
