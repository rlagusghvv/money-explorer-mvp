# r43 touch validation

## 코드 경로 정합성
- global→local 보정은 `_applyTouchCalibration()` 단일 함수로 통일.
- pointer down/move/up/cancel 모두 동일 함수 호출.
- 좌표 보정 우회 경로(별도 heuristic 변환) 없음.

검증 명령:
```bash
grep -n "_applyTouchCalibration\|globalToLocal" lib/main.dart
```

## 시뮬레이션/자동 검증
실행 명령:
```bash
flutter test test/r42_touch_engine_test.dart test/r41_touch_validation_test.dart test/miniroom_coordinate_mapper_test.dart
```

기대 관찰:
- transform 역변환 기반 center 오차 0 유지
- 투명영역 false select 0
- drag monotonic(no jump) 회귀 통과

## 사용자 재현 시나리오 체크 항목 (실기기 수동 확인용)
1. 마이룸에서 책상/바닥 아이템을 길게 눌러 드래그 시작
2. 손가락을 우하향으로 천천히 이동(약 2~3초)
3. 아이템이 손가락과 같은 방향으로 따라오는지 확인
4. 손을 떼는 순간 마지막 위치에서 점프가 없는지 확인
5. 동작 중 trace 로그(`docs/r43_touch_trace_sample.md` 포맷)에서 global/local/hit/transform 연속성 확인

> 자동 테스트만으로 PASS 판단 금지. 반드시 실기기 수동 체크를 함께 기록할 것.
