# r49 미니미 정렬/렌더 검증 체크리스트

## 범위
- 대상: 미니미 프리뷰 합성(`_MinimiPreviewComposite`)
- 파츠: 헤어/상의/소품
- 기준: `base_body` anchor 표준 유지 + 메타 기반 오프셋/z-order

## 구조 검증
- [x] 단일 렌더 경로 사용: `_buildMinimiRenderLayers(...)`
- [x] 카테고리 오프셋이 중앙 테이블에 존재 (`_kMinimiCategoryAnchorOffset`)
- [x] 아이템별 오버라이드가 중앙 테이블에 존재 (`_kMinimiItemAnchorOffset`)
- [x] z-order가 중앙 테이블에 존재 (`_kMinimiLayerZByItem`)
- [x] 위젯 내부 산발적 하드코딩 오프셋 제거

## 시각 검증(샘플 9조합)
- 산출물: `docs/r49_minimi_preview_grid.png`
- [x] 헤어가 상의 위에 정상 배치됨
- [x] 안경/별배지가 얼굴/머리 전면 레이어로 노출됨
- [x] 캡/헤드폰은 헤어 대비 자연스러운 depth 유지
- [x] 프리뷰 카드 영역에서 파츠 비정상 잘림/도약 현상 없음

## 회귀 리스크 점검
- [x] `acc_none` 선택 시 소품 레이어 미렌더링 확인
- [x] 존재하지 않는 asset id는 스킵(Null-safe)
- [x] 메타 누락 아이템은 기본 z(99)로 안전 fallback

## 후속 권장
- 파츠 추가 시: asset 등록 + preset 등록 + z/offset 메타만 추가
- 필요 시 JSON 외부화하여 아트 파이프라인과 동기화
