# r42 OSS touch engine adoption

## 참고한 오픈소스/공식 패턴

1. W3C Pointer Events Level 3 (공식)
   - 링크: https://www.w3.org/TR/pointerevents3/
   - 채택: `pointerdown` 시 대상(target) 캡처 후 `pointerup/cancel` 전까지 동일 타깃 유지.
   - 반영 위치: `lib/main.dart` `_onPointerDown`, `_onPointerMove`, `_onPointerUpOrCancel`의 `_TouchSession.target` 고정.

2. Flutter Matrix4 / inverse transform 패턴 (공식 프레임워크)
   - 링크: https://api.flutter.dev/flutter/vector_math_64/Matrix4-class.html
   - 링크: https://api.flutter.dev/flutter/painting/MatrixUtils/transformPoint.html
   - 채택: world->object 단일 역변환 경로(inverseTransform)로 hit test 좌표를 계산.
   - 반영 위치:
     - `lib/main.dart` `_RoomObjectTransform.worldToObject`
     - `lib/miniroom_coordinate_mapper.dart` `mapWorldPointToPixelWithTransform`
     - `_AlphaMaskData.hitTest`에서 rect 직접 계산 대신 transform 기반 매핑 사용.

3. Konva hit graph / transform-first input 패턴 (오픈소스)
   - 링크: https://konvajs.org/docs/overview.html
   - 채택: 렌더 transform과 hit transform을 분리하지 않고 동일 수학 경로 사용(입력/렌더 불일치 방지).
   - 반영 위치: drag/pinch 모두 `_RoomObjectTransform` 기준으로 계산, hit test도 동일 transform의 inverse 사용.

## r42 교체 내용

- 임시 좌표 보정 경로(여러 좌표계 혼합) 대신 `_RoomObjectTransform` 단일 소스를 사용.
- alpha hit test를 `visualRect` 직접 투영 방식에서 `worldToObject` 기반 방식으로 교체.
- pointer down target capture는 기존 유지(강화 문서화), move 중 hit retargeting 없음.
- drag/pinch 모두 동일 transform 체인 사용:
  - drag: `transform.left/top + focal delta`
  - pinch: `base transform center` + `scaleRatio`로 재계산
- 디버그 오버레이는 `kDebugMode`에서만 long-press 토글 가능, 기본 OFF 유지.

## 제거/비활성화

- 기존 임시 보정 상수/별도 캘리브레이션 경로는 r41에서 정리된 상태를 유지하고,
  r42에서는 hit test의 rect 직접 경로를 제거해 transform 단일화 완료.
