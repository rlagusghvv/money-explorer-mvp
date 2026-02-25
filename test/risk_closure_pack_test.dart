import 'package:flutter_test/flutter_test.dart';
import 'package:kid_econ_mvp/data/scenario_repository.dart';
import 'package:kid_econ_mvp/main.dart';

void main() {
  group('리스크 클로저 팩 테스트', () {
    test('scenario parsing guard: malformed 항목을 스킵하고 카운트한다', () {
      const rawJson = '''
      {
        "scenarios": [
          {
            "id": 2,
            "title": "정상 시나리오",
            "news": "뉴스 본문",
            "goodIndustries": ["A"],
            "badIndustries": ["B"],
            "industryOptions": [{"label": "A", "score": 90}],
            "quizQuestion": "질문",
            "quizOptions": [{"label": "답", "score": 100}],
            "explanation": {
              "short": "요약",
              "why": "이유",
              "risk": "리스크",
              "takeaway": "행동"
            }
          },
          "broken-entry",
          123
        ]
      }
      ''';

      final outcome = ScenarioRepository.parseScenariosJson(rawJson);

      expect(outcome.scenarios.length, 1);
      expect(outcome.scenarios.first.id, 2);
      expect(outcome.skippedMalformedCount, 2);
    });

    test('daily mission reset date logic: KST 날짜 경계를 정확히 처리한다', () {
      final previousDayUtc = DateTime.utc(2026, 2, 24, 14, 59); // KST 23:59
      final nextDayUtc = DateTime.utc(2026, 2, 24, 15, 0); // KST 00:00

      final dayKey = buildSeoulDateKey(previousDayUtc);
      final nextDayKey = buildSeoulDateKey(nextDayUtc);

      expect(dayKey, '2026-02-24');
      expect(nextDayKey, '2026-02-25');
      expect(
        isDailyMissionResetRequired(currentDateKey: dayKey, now: nextDayUtc),
        isTrue,
      );
      expect(
        isDailyMissionResetRequired(
          currentDateKey: nextDayKey,
          now: nextDayUtc,
        ),
        isFalse,
      );
    });

    test('wrong-note reward/claim logic: 복습 완료시에만 보상 델타가 발생한다', () {
      final completed = reviewRoundRewardDelta(completed: true);
      final incomplete = reviewRoundRewardDelta(completed: false);

      expect(completed.cashDelta, 45);
      expect(completed.rewardPointsDelta, 18);
      expect(incomplete.cashDelta, 0);
      expect(incomplete.rewardPointsDelta, 0);
    });
  });
}
