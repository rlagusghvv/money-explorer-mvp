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
  final String? reasoningQuestion;
  final List<String>? reasoningChoices;
  final Map<String, int>? reasoningBestByDifficulty;

  factory Scenario.fromJson(Map<String, dynamic> json) {
    final rawReasoningChoices = json['reasoningChoices'];
    final rawReasoningBest = json['reasoningBestByDifficulty'];

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
