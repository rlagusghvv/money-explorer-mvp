class ScenarioOption {
  const ScenarioOption({required this.label, required this.score});

  final String label;
  final int score;

  factory ScenarioOption.fromJson(Map<String, dynamic> json) {
    return ScenarioOption(
      label: _asString(json['label']),
      score: _asInt(json['score']),
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
      id: _asInt(json['id']),
      title: _asString(json['title']),
      news: _asString(json['news']),
      goodIndustries: _asStringList(json['goodIndustries']),
      badIndustries: _asStringList(json['badIndustries']),
      industryOptions: _asOptionList(json['industryOptions']),
      quizQuestion: _asString(json['quizQuestion']),
      quizOptions: _asOptionList(json['quizOptions']),
      explanation: rawExplanation is Map<String, dynamic>
          ? ScenarioExplanation.fromJson(rawExplanation)
          : ScenarioExplanation.fallback,
      reasoningQuestion: json['reasoningQuestion'] as String?,
      reasoningChoices: rawReasoningChoices is List<dynamic>
          ? List<String>.from(rawReasoningChoices)
          : null,
      reasoningBestByDifficulty: rawReasoningBest is Map<String, dynamic>
          ? rawReasoningBest.map((key, value) => MapEntry(key, _asInt(value)))
          : null,
    );
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null) {
    return fallback;
  }
  final trimmed = text.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

List<String> _asStringList(Object? value) {
  if (value is List<dynamic>) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

List<ScenarioOption> _asOptionList(Object? value) {
  if (value is List<dynamic>) {
    return value
        .whereType<Map<String, dynamic>>()
        .map(ScenarioOption.fromJson)
        .toList();
  }
  return const [];
}
