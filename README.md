# 뉴스 포트폴리오 탐험대 (kid_econ_mvp)

초등/중학생 대상 경제 학습 게임 MVP입니다.

## 이번 업데이트 (Task 12)
- 회원가입/로그인 (이메일 + 비밀번호)
- 백엔드 인증 + 계정별 클라우드 저장
- 계정별 진행 데이터 동기화:
  - points(탐험 포인트)
  - owned/equipped cosmetics
  - chapter progress
  - report stats(플레이 결과 기반 지표)
- `내 공간` 탭 추가 (현재 캐릭터/베이스 + 핵심 진행 요약)
- 로컬 저장 유지 + 클라우드 실패 시 fallback(오프라인 진행 가능)

---

## 1) Backend 실행
```bash
cd kid_econ_mvp/backend
npm install
npm start
```
- 기본 포트: `8787`
- 헬스체크: `GET http://localhost:8787/health`

### 보안(MVP)
- 비밀번호 평문 저장 금지
- bcrypt 해시 저장
- 기본 이메일/비밀번호 검증
- JWT 기반 인증

---

## 2) Flutter Web 실행
새 터미널에서:
```bash
cd kid_econ_mvp
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8787
```

> 모바일/시뮬레이터에서 백엔드 접근 시 `API_BASE_URL`을 환경에 맞게 변경하세요.

---

## 테스트/체크
### Flutter
```bash
cd kid_econ_mvp
flutter analyze
flutter test
```

### Backend
```bash
cd kid_econ_mvp/backend
npm test
```

---

## Minimi 보정 도구 문서
- 로컬 웹 보정 툴 사용법: `docs/minimi_web_calibrator.md`
- 도구 위치: `tools/minimi-calibrator/index.html`
