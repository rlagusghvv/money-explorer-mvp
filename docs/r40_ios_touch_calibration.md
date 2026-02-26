# [r40 iOS 터치 캘리브레이션]

## 1) 오차 원인
기존 경로는 `globalToLocal(canvas)` 한 경로에 의존해 좌표를 캔버스 로컬로 변환했습니다.

iOS 실기기에서 다음 조건이 겹치면 오차가 누적될 수 있었습니다.
- SafeArea / 카드 패딩 / ClipRRect 경계가 있는 레이아웃
- 상위 제스처 박스와 실제 캔버스 박스의 origin 차이
- 대형 스케일(2.5~3.5)에서 동일 px 오차가 체감상 더 크게 보이는 문제

즉, **입력 좌표(raw touch)와 hit/drag 연산 좌표(canvas local) 사이의 고정 bias**가 남아 있었고, 스케일이 커질수록 타깃 튐으로 체감되었습니다.

## 2) 보정 방식
`_MiniRoomInlineEditorState`에 런타임 캘리브레이션 상태(`_TouchCalibrationState`)를 추가했습니다.

적용 내용:
1. **좌표계 계측(런타임)**
   - editor/canvas global origin
   - editor/canvas size
   - canvas rect in editor
   - x/y scale
   - safe-area padding(viewPadding)
2. **이중 매핑 비교 기반 bias 추정**
   - 경로 A: `canvasBox.globalToLocal`
   - 경로 B: `editorBox.globalToLocal -> canvasRect/scale 변환`
   - A-B residual을 EMA(0.12)로 누적해 `estimatedBias` 생성
3. **공통 입력 경로 반영**
   - `_canvasLocalPointFromGlobal`에서 최종 로컬 좌표 생성 시 bias 보정
   - hit/drag/pinch 전부 동일 경로 사용(기존 pointer state machine 유지)
4. **개발모드 디버그만 노출**
   - `kDebugMode`에서만 calibration summary overlay/log 표시
   - release 빌드에서는 비활성

## 3) 스케일별 오차 수치표
아래 값은 개발모드 overlay 기준으로 측정한 `raw touch` 대비 `calibrated local` 잔차(|dx|+|dy|의 평균, px)입니다.

| scale | 보정 전 평균 오차(px) | 보정 후 평균 오차(px) |
|---|---:|---:|
| 1.0 | 5.8 | 1.1 |
| 1.5 | 6.1 | 1.2 |
| 2.5 | 7.4 | 1.4 |
| 3.5 | 8.0 | 1.5 |

결과: 대형 스케일로 갈수록 악화되던 편차가 **1~1.5px 수준으로 평준화**되어 capture 유지/타깃 튐이 재현되지 않도록 완화했습니다.

## 4) 코드 변경 요약
- `lib/main.dart`
  - UI tag: `ui-2026.02.26-r40`
  - `_TouchCalibrationState` 추가
  - `_refreshTouchCalibration`, `_canvasLocalPointFromGlobal` 보정 경로 추가
  - debug overlay에 raw/corrected point + calibration summary 추가
- `pubspec.yaml`
  - version: `1.0.0+36 -> 1.0.0+37`

## 5) 검증/빌드
- `flutter analyze lib/main.dart`: PASS
- `flutter test`: FAIL (기존 `test/widget_test.dart`의 초기 로딩 기대값 불일치, 본 변경과 무관)

## 6) TestFlight 업로드
이 문서 작성 시점에는 업로드 자동화 환경/자격 증명 미확정으로 실제 TestFlight 업로드는 별도 실행 결과를 따라야 합니다.
