# r48 미니미 정렬 체크리스트

## 목적
- 생성 파츠(헤어/상의/소품)의 원본 캔버스 크기·앵커 편차로 발생하던 합성 축 어긋남을 제거한다.
- `base_body` 기준 단일 좌표계(512x512)로 정규화 후, 프리뷰는 단순 레이어 스택으로 렌더한다.

## 정규화 방식
- 입력: `assets/minimi/generated/*.png`
- 출력: `assets/minimi/normalized/*.png`
- 기준 캔버스: `512x512`
- 정렬 기준(anchor map):
  - head 계열: hair
  - torso 계열: top
  - face/accessory 계열: accessory
- 구현 상세:
  - `scripts/r48_minimi_normalize.py`
  - 기존 r47 프리뷰 style(카테고리별 anchor/size)를 기준으로 각 파츠를 512 좌표로 재투영하여 기준점을 일치시킴
  - base_body와 동일 기준 좌표계로 합성 가능하도록 전체 파츠를 full-canvas PNG로 변환

## 프리뷰 렌더 정책 (r48)
- 하드코딩 오프셋 테이블 제거
- `Stack` 단순 레이어 순서:
  1. base_body
  2. top
  3. hair
  4. accessory
- 허용 미세 오프셋(카테고리 단위):
  - hair: `(0, -1.0)`
  - top: `(0, 0.5)`
  - accessory: `(0, 0)`

## 품질 게이트 샘플
- 산출물:
  - Before(legacy): `docs/r48_minimi_preview_grid_before.png`
  - After(r48 normalized): `docs/r48_minimi_preview_grid.png`
- 5개 조합:
  1. basic_black / green_hoodie / none
  2. brown_wave / blue_jersey / cap
  3. pink_bob / orange_knit / glass
  4. blue_short / purple_zipup / headphone
  5. blonde / white_shirt / star_pin

## 사람이 보는 수동 체크리스트
- [ ] 헤어가 두피 기준점에서 뜨거나 함몰되지 않는가
- [ ] 상의 목선이 몸통 목/어깨와 자연스럽게 접하는가
- [ ] 안경/모자/헤드폰이 얼굴/머리 기준점에 맞는가
- [ ] 별 배지가 가슴 부근에 일관되게 위치하는가
- [ ] 5개 샘플 모두에서 레이어 겹침(z-order)이 자연스러운가
- [ ] 확대/축소 시 가장자리 aliasing이 과도하지 않은가
