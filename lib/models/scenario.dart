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
  });

  final int id;
  final String title;
  final String news;
  final List<String> goodIndustries;
  final List<String> badIndustries;
  final List<ScenarioOption> industryOptions;
  final String quizQuestion;
  final List<ScenarioOption> quizOptions;

  factory Scenario.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
