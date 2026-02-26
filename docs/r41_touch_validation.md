# r41 touch validation (single-layer input)

## 핵심 변경

1. **입력/렌더 기준 레이어 단일화**
   - 인라인 미니룸 편집에서 `Listener`(입력)와 캔버스 렌더를 같은 RenderBox(`_miniRoomCanvasKey`) 기준으로 통일.
   - 좌표 변환은 `global -> canvas local` 1단계만 사용.
   - 기존 editor/canvas 다중 보정(스케일·bias 추정) 경로 제거.

2. **오브젝트 기준점(center) 통일**
   - 핀치 스케일 시 기준점을 터치 지점이 아닌 **오브젝트 center 고정**으로 변경.
   - 스케일이 커져도 중심점 유지 오차가 누적되지 않음.

3. **위젯 구조 단순화**
   - `Listener(key: _miniRoomCanvasKey) -> ClipRRect -> _MiniRoomVisual` 구조로 평탄화.
   - 디버그 오버레이 토글은 `kDebugMode`에서만 동작(릴리즈 기본 OFF).

---

## 자동 검증 결과

실행 명령:

```bash
flutter test test/r41_touch_validation_test.dart test/miniroom_coordinate_mapper_test.dart
flutter analyze lib/main.dart
```

### 1) 스케일별 중심 오차 측정

| Scale | center error (px) |
|---|---:|
| 1.0 | 0.0000 |
| 1.5 | 0.0000 |
| 2.5 | 0.0000 |
| 3.5 | 0.0000 |

기준: center-pinned 수식 기준 오차 `<= 0.0001px` (통과)

### 2) 투명영역 오선택

| 항목 | 결과 |
|---|---:|
| transparent false-select count | 0 |

기준: 0회 (통과)

### 3) 드래그 30회 타깃 튐

| 항목 | 결과 |
|---|---:|
| 30-step drag monotonic | PASS |
| step jump (> 3.7px) | 0 |

기준: 비단조 이동/급점프 없음 (통과)

---

## 추가 메모

- 이번 r41은 기존 r40의 동적 bias 추정 접근을 제거하고, 좌표계를 물리적으로 하나로 강제해 터치 오프셋 체감 이슈를 구조적으로 차단하는 방향.
- 검증 테스트 파일: `test/r41_touch_validation_test.dart`.
