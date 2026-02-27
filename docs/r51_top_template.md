# r51 상의 템플릿 재생성

- 기준: `assets/minimi/normalized/base_body.png` 알파 실루엣에서 torso 영역만 추출
- 템플릿: `assets/minimi/template/top_torso_template.png`
- 방법: torso 라운드 마스크 내부에 top 파츠를 리타겟(중심 정렬 + 목선 기준 상단 고정) 후 템플릿 외부는 클리핑
- 템플릿 bbox(512 기준): `(121, 212, 398, 443)`
- 교체 대상(top 5): top_green_hoodie, top_blue_jersey, top_orange_knit, top_purple_zipup, top_white_shirt
