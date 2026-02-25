# r21 터치 개선 레퍼런스 (Flutter 드래그/핀치/캔버스 UX)

## 1) Flutter `InteractiveViewer` (official)
- 근거: Flutter 공식 위젯으로 pan/scale 제스처 충돌 완화, scale clamp, boundary 처리 패턴 제공.
- 적용 포인트:
  - scale 최소/최대값 하드 클램프(`_minScale`, `_maxScale`) 유지
  - 제스처 시작/업데이트/종료 lifecycle 분리 (start/update/end)
  - parent scroll 충돌은 편집 중 외부 스크롤 잠금으로 해결
- 링크: https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html

## 2) `flutter_box_transform` (open source package)
- 근거: 선택/조작 대상의 시각적 bounds와 hit area를 분리해 과도한 hit 영역을 줄이는 패턴이 안정적.
- 적용 포인트:
  - hit slop 최소화(기존 18 -> 6)
  - 실제 시각 rect 기준으로 조작 시작
  - 디버그 시 bounds 표시하여 실제 터치 범위 검증
- 링크: https://pub.dev/packages/flutter_box_transform

## 3) `graphx`/canvas editor style gesture pattern (open source community pattern)
- 근거: 1손가락 drag, 2손가락 pinch를 mode 전환하며 baseline 리셋해 jump를 줄이는 방식.
- 적용 포인트:
  - pointerCount 기반 gesture mode(1F/2F) 전환
  - 모드 전환 시 focal/rect baseline 재설정
  - tap-select와 scale/drag 충돌 시 selection lock/suppress background tap 적용
- 링크: https://pub.dev/packages/graphx

## 4) 보조 레퍼런스: Flutter GestureDetector/Scale details
- 근거: `onScaleUpdate`에서 `pointerCount`, `scale`, `focalPoint`를 함께 쓰는 멀티터치 전이 안정화 패턴.
- 적용 포인트:
  - 1F: focal delta로 translation only
  - 2F: baseline width * scale + focal delta
- 링크: https://api.flutter.dev/flutter/widgets/GestureDetector-class.html

---

## 우리 코드에 바로 이식한 안정화 체크포인트
1. hit test 정밀화: visual bounds + 최소 hit slop 적용
2. 입력 상태기계 단순화: tap-select / 1F drag / 2F pinch 분리
3. parent scroll lock: 조작 시작 시 잠금, end/cancel 시 복구
4. 모드 전이 안정화: 1F↔2F 전환 시 baseline 리셋
5. 디버그 가시성: `kDebugMode`에서만 bounds/gesture 로그 노출
