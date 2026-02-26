# r49 미니미 OSS/공식 패턴 레퍼런스

## 1) Flutter 공식 `Stack` + `Positioned/Transform` 레이어 합성
- 링크: https://api.flutter.dev/flutter/widgets/Stack-class.html
- 링크: https://docs.flutter.dev/ui/layout
- 채택 이유:
  - 미니미 합성은 본질적으로 다중 레이어 오버레이이므로 Flutter 기본 렌더 모델과 가장 일치
  - 단일 Stack 경로로 유지 시 디버깅/예측 가능성이 높고, 레이어 순서(z) 통제가 명확함
  - 외부 엔진 종속 없이 앱 런타임/빌드 리스크 최소화

## 2) Flame Component Tree의 계층/우선순위 패턴 (오픈소스)
- 링크: https://github.com/flame-engine/flame
- 링크: https://docs.flame-engine.org/latest/flame/components.html
- 채택 이유:
  - 부모-자식 계층 + priority(z) 기반 렌더 순서가 아바타 파츠 합성 모델과 구조적으로 동일
  - r49에서 아이템별 z 테이블(`_kMinimiLayerZByItem`)로 반영해 하드코딩 분산을 제거
  - 이후 파츠 추가 시 규칙 기반 확장(메타 추가)만으로 대응 가능

## 3) Spine Slot/Attachment 개념 (오픈소스 런타임 생태계)
- 링크: https://github.com/EsotericSoftware/spine-runtimes
- 링크: http://esotericsoftware.com/spine-slots
- 채택 이유:
  - 캐릭터 커스터마이징에서 "슬롯(부위)" + "첨부(아이템)" 분리가 검증된 패턴
  - r49에서 카테고리(anchor offset) + 아이템 오버라이드(item offset) 2단 메타 구조로 적용
  - 특정 아이템(안경/뱃지) 미세 정렬을 중앙 테이블에서 관리 가능

---

## r49 적용 요약
- 카테고리 기본 앵커 오프셋: `_kMinimiCategoryAnchorOffset`
- 아이템별 오프셋 오버라이드: `_kMinimiItemAnchorOffset`
- 아이템별 z-order: `_kMinimiLayerZByItem`
- 단일 합성 경로: `_buildMinimiRenderLayers(...)` → `_MinimiPreviewComposite`

위 구조로 파츠 정렬/겹침 정책이 코드 전역 하드코딩이 아닌 메타 테이블로 수렴되도록 정리했다.
