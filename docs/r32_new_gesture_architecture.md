# [r32 새 제스처 아키텍처]

## 1) 무엇을 새로 갈아탔는지
- **편집 전용 캔버스 분리**
  - 마이룸 카드 내부 즉시 편집(스크롤 ListView 내부)을 제거.
  - `편집 모드` 버튼으로 **full-screen editor**(`_MiniRoomEditorScreen`) 진입.
  - 에디터는 `Scaffold + SafeArea + GestureDetector(onScale*)` 단독 구성으로 상위 스크롤 간섭을 구조적으로 차단.
- **제스처 엔진 교체**
  - 기존 포인터 상태머신(`Listener + pointer map + baseline reset`)을 폐기.
  - 검증된 pan/zoom 패턴인 **ScaleGestureDetector 기반 단일 transform 모델**로 교체.
  - 오브젝트별 `baseAdjustment + pivot(local) + scale`로 변환 계산.
  - 드래그/핀치를 동일한 `onScaleUpdate` 경로로 처리(단일 모델).
- **Per-pixel alpha hit test 유지**
  - `_AlphaMaskData` 기반 alpha 마스크 로딩/히트테스트 유지.
  - 투명 영역 오탭 방지 로직 유지.

## 2) 왜 이전보다 안정적인지
- 편집이 ListView 내부에서 일어나지 않으므로, 스크롤/부모 제스처와 경쟁이 사라짐.
- 이벤트 경로가 `onScaleStart/Update/End` 하나로 단순화되어 모드 전환 경계(1손↔2손) 불연속성이 크게 감소.
- 오브젝트 로컬 pivot 고정 방식으로 확대/축소 중 위치 계산이 연속적.

## 3) 품질 게이트 수치
> 실기기 로그 기준 게이트는 아직 **미집행** (이 문서 시점 기준 업로드 보류)

- [ ] 15초 드래그 중 역점프 0
- [ ] 핀치 20회 불연속 jump 0
- [ ] 선택 정확도(투명영역 미선택) 유지

현재 확보된 정적/자동 검증:
- `flutter analyze`: PASS
- `flutter test`: PASS

## 4) 업로드 성공/실패 + build
- 버전: `1.0.0+29` (**build +1 적용**)
- 상태: **TestFlight 업로드 미실행** (실기기 품질 게이트 미통과/미측정 상태라 정책상 보류)

## 5) 사용자가 확인할 3가지
1. 마이룸 탭에서 `편집 모드` 진입 시 전체화면으로 전환되고, 부모 스크롤이 전혀 개입하지 않는지
2. 1손 드래그 15초 동안 오브젝트가 손 반대방향으로 튀는 역점프가 0인지
3. 핀치 20회 반복 시 스케일 변화가 연속적이고, 투명영역 탭이 선택되지 않는지
