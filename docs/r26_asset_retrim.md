# [r26 자산 재트림]

## 1) 재트림 적용 범위/방식
- 대상: 마이룸 캐릭터 6종 + 주요 데코 19종 (총 25 PNG)
- 경로: `assets/miniroom/generated/item_*.png` (room 배경 제외)
- 방식:
  - 알파 임계치 `alpha > 20` 기준으로 실제 시각 영역 bbox 추출
  - bbox로 무손실 crop 후, 과도한 가장자리 잘림 방지를 위해 약 6% 안전 패딩만 재부여
  - 원본 비율 유지(리샘플링/축소 없음, 캔버스만 재구성)

## 2) 여백 축소 결과
- 평균 투명 면적(=여백) 비율: `82.7% -> 35.6%`
- 평균 여백 축소율: **56.9% 감소**

## 3) 렌더/앵커 호환 보정
- 자산이 타이트해지며 체감 크기가 커지는 문제를 완화하기 위해 anchor base size 보정:
  - character: `110x110 -> 68x68`
  - wall: `138x88 -> 72x46`
  - window: `124x88 -> 64x46`
  - shelf: `138x118 -> 72x61`
  - desk: `176x122 -> 102x71`
  - floor: `206x112 -> 124x67`
- 정렬 기준 alignment/depth는 유지하여 기존 저장 좌표와의 시각적 맥락을 보존

## 4) hitbox/선택 정리
- `lib/main.dart`의 `_alphaHitInsetByItemId`를 재트림 자산 기준으로 전면 갱신
- 기존 r25 alpha hitbox 체계는 유지하고, 값만 새 자산에 맞게 재산출
- 결과적으로 오브젝트 주변 투명영역 오선택 가능성 축소

## 5) 검증
- 정적/자동 검증
  - `flutter analyze` 통과
  - `flutter test` 통과
- 샘플 5+5 자산에 대해 알파 커버리지 개선 확인
  - 캐릭터 5종: 예) teddy `0.175 -> 0.747`, fox `0.257 -> 0.779`
  - 데코 5종: 예) wall_chart `0.103 -> 0.550`, globe `0.215 -> 0.797`
- 의미: 동일한 렌더 rect 기준 실제 시각 영역 밀도가 크게 개선되어 선택 정확도 개선 근거 확보

## 6) iOS/TestFlight
- 버전: `1.0.0+23` (build +1)
- IPA 빌드 성공
- TestFlight 업로드 성공
  - 업로드 산출물: `build/ios/ipa/kid_econ_mvp.ipa`
  - fastlane pilot: success
