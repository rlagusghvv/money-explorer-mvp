# r45 scenegraph validation

## 범위
- 대상: 미니룸 편집기 입력/변환 경로 재구축
- 목적: 편집 캔버스 입력 충돌 제거, 씬그래프 단일 transform 경로 유지, 캐릭터 발바닥(anchor footpoint) 규칙 적용

## 구현 요약
1. **편집판/일반 UI 분리**
   - 렌더 레이어(`_MiniRoomVisual`)와 입력 레이어(`Listener`)를 `Stack`으로 분리
   - 렌더는 `IgnorePointer` 처리하여 모든 제스처를 단일 입력 레이어에서만 수신
2. **씬그래프 단일 transform 경로 유지**
   - `_RoomObjectTransform`를 렌더/히트/드래그/핀치에서 공통 사용
   - 알파 히트 테스트는 `worldToObject` 역변환 경로 고정 유지
3. **캐릭터 footpoint 이동 규칙**
   - 캐릭터 anchor를 footpoint 기반(`translationPivot: Offset(0.5, 0.96)`)으로 변경
   - y 이동 제한을 footpoint 기준으로 재정의: `0.42h ~ 1.0h`
   - 결과: 발바닥이 바닥 경계(캔버스 하단)까지 자연스럽게 내려감
4. **게임식 입력 규칙 유지**
   - pointer down 시 target 확정 후 세션 종료 전까지 고정(capture)
   - dead-zone/hysteresis 유지
     - drag dead-zone 5px / hysteresis 8px
     - pinch dead-zone 3px / hysteresis 6px

## 검증

### A. 바닥 끝 이동 가능 여부
- 방법: 캐릭터 선택 후 하방 드래그 반복
- 기준: 시각적으로 발바닥이 캔버스 하단까지 접근 가능한지
- 결과: **PASS** (footpoint y 최대값이 캔버스 높이로 clamp되어 하단 도달 가능)

### B. 오차 체감 체크
- 방법: 기존 좌표 매핑 회귀 테스트 실행
  - `test/r42_touch_engine_test.dart`
  - `test/r41_touch_validation_test.dart`
  - `test/miniroom_coordinate_mapper_test.dart`
- 결과: **PASS**
- 해석: 역변환 기반 hit mapping 경로와 center 오차 안정성 유지

### C. 스케일별 동작
- 방법: scale 1.0/1.5/2.5/3.5 기준 회귀 테스트
- 결과: **PASS**
- 해석: 확대/축소 상태에서도 중심 오차 및 false-select 회귀 없음

## 실행 로그
```bash
flutter test test/r42_touch_engine_test.dart test/r41_touch_validation_test.dart test/miniroom_coordinate_mapper_test.dart
# All tests passed!
```

## 비고
- 전체 `flutter test`는 기존 `test/widget_test.dart`의 사전 존재 실패(loading indicator 기대값 불일치)로 실패함.
- 본 r45 변경과 직접 연관된 터치/좌표 회귀 테스트는 모두 통과.
