class ScenarioOption {
  const ScenarioOption({required this.label, required this.score});

  final String label;
  final int score;

  factory ScenarioOption.fromJson(Map<String, dynamic> json) {
    return ScenarioOption(
      label: json['label'] as String,
      score: (json['score'] as num).round(),
    );
  }
}

class ScenarioExplanation {
  const ScenarioExplanation({
    required this.short,
    required this.why,
    required this.risk,
    required this.takeaway,
  });

  final String short;
  final String why;
  final String risk;
  final String takeaway;

  factory ScenarioExplanation.fromJson(Map<String, dynamic> json) {
    return ScenarioExplanation(
      short: json['short'] as String? ?? '',
      why: json['why'] as String? ?? '',
      risk: json['risk'] as String? ?? '',
      takeaway: json['takeaway'] as String? ?? '',
    );
  }

  static const fallback = ScenarioExplanation(
    short: '뉴스와 산업의 연결을 찾은 점이 좋아요.',
    why: '수혜와 피해를 함께 보면 판단이 더 정확해져요.',
    risk: '비중을 크게 잡으면 작은 실수도 손실이 커질 수 있어요.',
    takeaway: '다음에는 근거를 먼저 적고 비중을 40~60%에서 시작해요.',
  );
}

class Scenario {
  const Scenario({
    required this.id,
    required this.title,
    required this.news,
    required this.goodIndustries,
    required this.badIndustries,
    required this.industryOptions,
    required this.quizQuestion,
    required this.quizOptions,
    required this.explanation,
    this.reasoningQuestion,
    this.reasoningChoices,
    this.reasoningBestByDifficulty,
  });

  final int id;
  final String title;
  final String news;
  final List<String> goodIndustries;
  final List<String> badIndustries;
  final List<ScenarioOption> industryOptions;
  final String quizQuestion;
  final List<ScenarioOption> quizOptions;
  final ScenarioExplanation explanation;
  final String? reasoningQuestion;
  final List<String>? reasoningChoices;
  final Map<String, int>? reasoningBestByDifficulty;

  factory Scenario.fromJson(Map<String, dynamic> json) {
    final rawReasoningChoices = json['reasoningChoices'];
    final rawReasoningBest = json['reasoningBestByDifficulty'];
    final rawExplanation = json['explanation'];

    return Scenario(
      id: json['id'] as int,
      title: json['title'] as String,
      news: json['news'] as String,
      goodIndustries: List<String>.from(json['goodIndustries'] as List<dynamic>),
      badIndustries: List<String>.from(json['badIndustries'] as List<dynamic>),
      industryOptions: (json['industryOptions'] as List<dynamic>)
          .map((e) => ScenarioOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      quizQuestion: json['quizQuestion'] as String,
      quizOptions: (json['quizOptions'] as List<dynamic>)
          .map((e) => ScenarioOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      explanation: rawExplanation is Map<String, dynamic>
          ? ScenarioExplanation.fromJson(rawExplanation)
          : ScenarioExplanation.fallback,
      reasoningQuestion: json['reasoningQuestion'] as String?,
      reasoningChoices: rawReasoningChoices is List<dynamic>
          ? List<String>.from(rawReasoningChoices)
          : null,
      reasoningBestByDifficulty: rawReasoningBest is Map<String, dynamic>
          ? rawReasoningBest.map(
              (key, value) => MapEntry(key, (value as num).round()),
            )
          : null,
    );
  }
}
