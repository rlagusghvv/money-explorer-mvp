# r29 픽셀 선택 품질 게이트

## 실행
- 명령: `python3 scripts/r29_quality_gate.py`
- 대상 에셋: `assets/miniroom/generated/item_teddy_bear.png`
- 판정 임계값: alpha > 40

## 결과 (수치)
- 투명영역 20포인트 탭: **0회 선택**
- 실픽셀 20포인트 탭: **20회 선택**

## 드래그/핀치 기본 동작 확인
- `flutter analyze`: 통과
- `flutter test`: 통과 (기존 제스처 코드 경로 이상 없음)

## 참고
- 본 게이트는 release 전 선행 검증이며, 실패 시 업로드 금지.
