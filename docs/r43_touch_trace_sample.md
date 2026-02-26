# r43 touch trace sample (real-device calibration path)

## 목적
- 실기기 터치 오프셋 이슈를 재현 가능한 필드로 기록.
- **raw touch(global/local), hit target, object transform**를 같은 라인에 남겨 좌표 불일치 경로를 즉시 확인.
- 좌표 보정은 `_applyTouchCalibration()` 단일 함수만 사용.

## 로그 포맷

```text
<phase> | global(x,y) | local(x,y) | hit=<target> | transform=left=..,top=..,w=..,h=..
```

- `phase`: `down`, `down+`, `move:dragging`, `move:pinching`, `up`, `cancel`
- `global`: `PointerEvent.position` 원본 좌표
- `local`: `_applyTouchCalibration(global)` 결과
- `hit`: 히트된 타깃 (`character`, `zone:wall` 등)
- `transform`: 히트/조작 대상 `_RoomObjectTransform.worldRect`

## 샘플 (시뮬레이션 캡처)

```text
down | global(193.2,541.7) | local(151.6,298.4) | hit=zone:desk | transform=left=120.4,top=264.9,w=106.1,h=73.8
move:dragging | global(201.9,548.5) | local(160.3,305.2) | hit=zone:desk | transform=left=128.9,top=271.7,w=106.1,h=73.8
move:dragging | global(210.6,554.9) | local(169.0,311.6) | hit=zone:desk | transform=left=137.6,top=278.1,w=106.1,h=73.8
up | global(211.1,555.4) | local(169.5,312.1) | hit=zone:desk | transform=left=137.6,top=278.1,w=106.1,h=73.8
```

## 확인 포인트 (사용자 재현 시나리오 대응)
1. 첫 `down`에서 `hit`가 의도한 오브젝트와 일치해야 함.
2. `move:*` 동안 `global` 이동 방향과 `local` 이동 방향이 역전/점프 없이 동일해야 함.
3. `transform` 값이 프레임 간 연속적으로 변하고, 터치 반대방향으로 튀지 않아야 함.
4. `up` 시점 transform이 마지막 move와 불연속적으로 달라지지 않아야 함.

## 비고
- 본 문서는 로그 포맷/샘플 기준 문서이며, 실제 디버그 빌드에서 `[r43-touch-trace] ...` 라인으로 동일 포맷이 출력된다.
