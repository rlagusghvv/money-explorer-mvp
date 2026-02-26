# r42 touch validation (OSS transform-first engine)

## 실행 커맨드

```bash
flutter test test/r42_touch_engine_test.dart test/r41_touch_validation_test.dart test/miniroom_coordinate_mapper_test.dart
```

## 결과 요약

- PASS (총 7 tests)
- inverseTransform 기반 hit test 경로 정상 동작
- pointer capture 고정/drag monotonic 기존 회귀 테스트 통과

## 항목별 검증

### 1) scale 1.0 / 1.5 / 2.5 / 3.5 오차 측정

측정 방법:
- 동일 월드 중심점(center)을 각 scale에서 `worldToObject(inverse)`로 역변환.
- normalize 좌표가 `(0.5, 0.5)`에서 얼마나 벗어나는지 측정.

| scale | |nx-0.5| | |ny-0.5| |
|---|---:|---:|
| 1.0 | 0.0000 | 0.0000 |
| 1.5 | 0.0000 | 0.0000 |
| 2.5 | 0.0000 | 0.0000 |
| 3.5 | 0.0000 | 0.0000 |

결론: scale 증가에 따른 오차 증폭 없음(수학 경로 단일화 확인).

### 2) 투명영역 오선택

측정 방법:
- 1px 투명 테두리 + 내부 불투명 alpha 마스크(10x10) 샘플.
- 투명 코너 샘플 4점 hit 검사.

결과:
- false select = **0 / 4**

### 3) 드래그 타깃 튐 여부

근거 테스트:
- `test/r41_touch_validation_test.dart`의 `30 drag updates are monotonic (no jump)`
- 30-step 연속 이동에서 위치 증가 단조성/step bound 유지

결과:
- PASS (target jump 재현 없음)

## 자동 테스트 추가

- 신규: `test/r42_touch_engine_test.dart`
  - inverse transform 중심 오차 안정성
  - 투명 경계 오선택 방지
