# 뉴스 포트폴리오 탐험대 (Kid Econ MVP)

초등 고학년~중학생 대상, **뉴스/사회 이슈 기반 경제 의사결정 게임**입니다.

핵심 루프:
1. 사회 이슈/뉴스 확인
2. 수혜/피해 산업 추리
3. 가상 포트폴리오(리스크 비율 포함) 결정
4. 시나리오 퀴즈 풀이 + 결과 반영
5. 주간 리포트에서 학습 습관 확인

---

## MVP 범위 (완료)
- ✅ 한국어 UI + 게임 톤
- ✅ 시나리오 10개
- ✅ 시나리오별 퀴즈
- ✅ 간단 포트폴리오 시뮬레이션
- ✅ 감정조절(몰빵 패널티 / 안정 비율 보너스)
- ✅ 주간 리포트(5개 단위 요약 + 전체 성과)
- ✅ 로컬 저장(SharedPreferences)
- ✅ Flutter 구조 유지(iOS 확장 가능)

---

## 학습 목표
- 이슈 해석력
- 산업 지도 이해(수혜/피해 연결)
- 리스크/분산 개념
- 단기 vs 장기 관점
- 감정 조절(급한 의사결정 피하기)

---

## 기술 스택
- Flutter (Material 3)
- shared_preferences

---

## Web 우선 실행 방법 (로컬 데모)
```bash
cd kid_econ_mvp
flutter pub get
flutter run -d chrome
```

> Chrome 디바이스가 안 뜨면:
```bash
flutter config --enable-web
flutter doctor
flutter devices
```

---

## 정적 웹 빌드 확인
```bash
cd kid_econ_mvp
flutter build web
```

빌드 산출물: `build/web/`

---

## iOS 이식성 유지 포인트
- Flutter 단일 코드베이스 유지 (`lib/main.dart`)
- 플랫폼 전용 코드 없음
- SharedPreferences 기반 로컬 상태 저장

iOS 빌드:
```bash
cd kid_econ_mvp
flutter build ios
# 또는 배포용
flutter build ipa --release
```

---

## 파일 구조
- `lib/main.dart`: MVP 전체 플레이 로직/상태/UI
- `README.md`: 실행/검증/개요

---

## 다음 확장 아이디어
- 기업 단위 카드(산업 → 대표 기업 매핑 강화)
- 난이도별 리스크 모델 차등
- 부모/교사용 리포트 내보내기
- 서버 백업 + 계정 연동
