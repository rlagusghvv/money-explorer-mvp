import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/scenario_repository.dart';
import 'models/scenario.dart';

void main() {
  runApp(const KidEconMvpApp());
}

enum DifficultyLevel { easy, normal, hard }

extension DifficultyLabel on DifficultyLevel {
  String get label => switch (this) {
    DifficultyLevel.easy => '쉬움',
    DifficultyLevel.normal => '보통',
    DifficultyLevel.hard => '어려움',
  };

  String get questName => switch (this) {
    DifficultyLevel.easy => '초원 입문 코스',
    DifficultyLevel.normal => '협곡 전략 코스',
    DifficultyLevel.hard => '화산 마스터 코스',
  };

  String get icon => switch (this) {
    DifficultyLevel.easy => '🌿',
    DifficultyLevel.normal => '🪨',
    DifficultyLevel.hard => '🌋',
  };

  int get hintPenalty => switch (this) {
    DifficultyLevel.easy => 12,
    DifficultyLevel.normal => 20,
    DifficultyLevel.hard => 28,
  };
}

class KidEconMvpApp extends StatelessWidget {
  const KidEconMvpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '뉴스 포트폴리오 탐험대',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
      ),
      home: const BootstrapPage(),
    );
  }
}

class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  bool _loading = true;
  late AppState _state;
  late List<Scenario> _scenarios;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _state = await AppStateStore.load();
    _scenarios = await ScenarioRepository.loadScenarios();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return GameHomePage(initialState: _state, scenarios: _scenarios);
  }
}

class ScenarioResult {
  const ScenarioResult({
    required this.scenarioId,
    required this.invested,
    required this.profit,
    required this.returnPercent,
    required this.judgementScore,
    required this.riskManagementScore,
    required this.emotionControlScore,
    required this.hintUsed,
    required this.difficulty,
    required this.timestamp,
  });

  final int scenarioId;
  final int invested;
  final int profit;
  final int returnPercent;
  final int judgementScore;
  final int riskManagementScore;
  final int emotionControlScore;
  final bool hintUsed;
  final DifficultyLevel difficulty;
  final DateTime timestamp;

  int get totalLearningScore =>
      ((judgementScore + riskManagementScore + emotionControlScore) / 3)
          .round();
}

class AppState {
  const AppState({
    required this.playerName,
    required this.cash,
    required this.currentScenario,
    required this.results,
    required this.bestStreak,
    required this.onboarded,
    required this.selectedDifficulty,
  });

  factory AppState.initial() => const AppState(
    playerName: '탐험대원',
    cash: 1000,
    currentScenario: 0,
    results: [],
    bestStreak: 0,
    onboarded: false,
    selectedDifficulty: DifficultyLevel.easy,
  );

  final String playerName;
  final int cash;
  final int currentScenario;
  final List<ScenarioResult> results;
  final int bestStreak;
  final bool onboarded;
  final DifficultyLevel selectedDifficulty;

  int get solvedCount => results.length;
  int get totalProfit => results.fold(0, (sum, e) => sum + e.profit);
  int get hintUsedCount => results.where((e) => e.hintUsed).length;

  double get avgReturn {
    if (results.isEmpty) return 0;
    final sum = results.fold<int>(0, (acc, e) => acc + e.returnPercent);
    return sum / results.length;
  }

  int _avgBy(int Function(ScenarioResult e) pick) {
    if (results.isEmpty) return 0;
    return (results.fold<int>(0, (acc, e) => acc + pick(e)) / results.length)
        .round();
  }

  int get avgJudgementScore => _avgBy((e) => e.judgementScore);
  int get avgRiskManagementScore => _avgBy((e) => e.riskManagementScore);
  int get avgEmotionControlScore => _avgBy((e) => e.emotionControlScore);

  AppState copyWith({
    String? playerName,
    int? cash,
    int? currentScenario,
    List<ScenarioResult>? results,
    int? bestStreak,
    bool? onboarded,
    DifficultyLevel? selectedDifficulty,
  }) {
    return AppState(
      playerName: playerName ?? this.playerName,
      cash: cash ?? this.cash,
      currentScenario: currentScenario ?? this.currentScenario,
      results: results ?? this.results,
      bestStreak: bestStreak ?? this.bestStreak,
      onboarded: onboarded ?? this.onboarded,
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
    );
  }
}

class AppStateStore {
  static const _kPlayerName = 'playerName';
  static const _kCash = 'cash';
  static const _kCurrentScenario = 'currentScenario';
  static const _kResults = 'results';
  static const _kBestStreak = 'bestStreak';
  static const _kOnboarded = 'onboarded';
  static const _kDifficulty = 'difficulty';

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final initial = AppState.initial();
    final raw = prefs.getStringList(_kResults) ?? [];

    final parsed = raw
        .map((line) {
          final parts = line.split('|');
          if (parts.length < 8) return null;

          final isLegacy = parts.length < 11;
          if (isLegacy) {
            final legacyQuizCorrect = parts[4] == '1';
            final legacyReturn = int.tryParse(parts[3]) ?? 0;
            return ScenarioResult(
              scenarioId: int.tryParse(parts[0]) ?? 0,
              invested: int.tryParse(parts[1]) ?? 0,
              profit: int.tryParse(parts[2]) ?? 0,
              returnPercent: legacyReturn,
              judgementScore: legacyQuizCorrect ? 85 : 45,
              riskManagementScore: legacyReturn >= 8
                  ? 80
                  : legacyReturn >= 0
                  ? 65
                  : 45,
              emotionControlScore: (parts.length > 5 && parts[5] == '1') ? 55 : 75,
              hintUsed: parts.length > 5 ? parts[5] == '1' : false,
              difficulty: parts.length > 6
                  ? _difficultyFrom(parts[6])
                  : DifficultyLevel.easy,
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                int.tryParse(parts.length > 7 ? parts[7] : '') ??
                    DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }

          return ScenarioResult(
            scenarioId: int.tryParse(parts[0]) ?? 0,
            invested: int.tryParse(parts[1]) ?? 0,
            profit: int.tryParse(parts[2]) ?? 0,
            returnPercent: int.tryParse(parts[3]) ?? 0,
            judgementScore: int.tryParse(parts[4]) ?? 0,
            riskManagementScore: int.tryParse(parts[5]) ?? 0,
            emotionControlScore: int.tryParse(parts[6]) ?? 0,
            hintUsed: parts[7] == '1',
            difficulty: _difficultyFrom(parts[8]),
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(parts[9]) ?? DateTime.now().millisecondsSinceEpoch,
            ),
          );
        })
        .whereType<ScenarioResult>()
        .toList();

    return AppState(
      playerName: prefs.getString(_kPlayerName) ?? initial.playerName,
      cash: prefs.getInt(_kCash) ?? initial.cash,
      currentScenario:
          prefs.getInt(_kCurrentScenario) ?? initial.currentScenario,
      results: parsed,
      bestStreak: prefs.getInt(_kBestStreak) ?? initial.bestStreak,
      onboarded: prefs.getBool(_kOnboarded) ?? initial.onboarded,
      selectedDifficulty: _difficultyFrom(
        prefs.getString(_kDifficulty) ?? 'easy',
      ),
    );
  }

  static DifficultyLevel _difficultyFrom(String raw) {
    return DifficultyLevel.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => DifficultyLevel.easy,
    );
  }

  static Future<void> save(AppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlayerName, state.playerName);
    await prefs.setInt(_kCash, state.cash);
    await prefs.setInt(_kCurrentScenario, state.currentScenario);
    await prefs.setInt(_kBestStreak, state.bestStreak);
    await prefs.setBool(_kOnboarded, state.onboarded);
    await prefs.setString(_kDifficulty, state.selectedDifficulty.name);

    final encoded = state.results
        .map(
          (e) => [
            e.scenarioId,
            e.invested,
            e.profit,
            e.returnPercent,
            e.judgementScore,
            e.riskManagementScore,
            e.emotionControlScore,
            e.hintUsed ? 1 : 0,
            e.difficulty.name,
            e.timestamp.millisecondsSinceEpoch,
          ].join('|'),
        )
        .toList();
    await prefs.setStringList(_kResults, encoded);
  }
}

class GameHomePage extends StatefulWidget {
  const GameHomePage({
    super.key,
    required this.initialState,
    required this.scenarios,
  });

  final AppState initialState;
  final List<Scenario> scenarios;

  @override
  State<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends State<GameHomePage> {
  late AppState _state;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    if (!_state.onboarded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboarding());
    }
  }

  Future<void> _showOnboarding() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🧭 뉴스 포트폴리오 탐험대'),
        content: const Text(
          '탐험 지도를 따라 뉴스를 읽고, 근거를 세워 투자 결정을 내려봐요!\n\n'
          '이제 정답/오답이 아닌 점수형 평가예요.\n'
          '선택마다 부분 점수를 받아 성장 포인트를 확인할 수 있어요.\n\n'
          '힌트는 오답 뒤 1회 열리며, 사용 시 보상 코인이 줄어요.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              setState(() => _state = _state.copyWith(onboarded: true));
              _persist();
              Navigator.pop(context);
            },
            child: const Text('탐험 시작!'),
          ),
        ],
      ),
    );
  }

  Future<void> _persist() async => AppStateStore.save(_state);

  void _applyScenarioResult(ScenarioResult result) {
    final nextResults = [..._state.results, result];
    setState(() {
      _state = _state.copyWith(
        cash: max(0, _state.cash + result.profit),
        currentScenario: min(widget.scenarios.length, _state.currentScenario + 1),
        results: nextResults,
      );
      _tabIndex = 0;
    });
    _persist();
  }

  void _resetProgress() {
    setState(() {
      _state = AppState.initial().copyWith(
        playerName: _state.playerName,
        onboarded: true,
        selectedDifficulty: _state.selectedDifficulty,
      );
      _tabIndex = 0;
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _PlayTab(
        state: _state,
        scenarios: widget.scenarios,
        onDifficultyChanged: (d) {
          setState(() => _state = _state.copyWith(selectedDifficulty: d));
          _persist();
        },
        onDone: _applyScenarioResult,
      ),
      _WeeklyReportTab(state: _state),
      _GuideTab(onReset: _resetProgress),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('뉴스 포트폴리오 탐험대')),
      body: SafeArea(child: pages[_tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (v) => setState(() => _tabIndex = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore), label: '탐험 맵'),
          NavigationDestination(icon: Icon(Icons.insights), label: '리포트'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: '가이드'),
        ],
      ),
    );
  }
}

class _PlayTab extends StatelessWidget {
  const _PlayTab({
    required this.state,
    required this.scenarios,
    required this.onDone,
    required this.onDifficultyChanged,
  });

  final AppState state;
  final List<Scenario> scenarios;
  final ValueChanged<ScenarioResult> onDone;
  final ValueChanged<DifficultyLevel> onDifficultyChanged;

  static const List<String> _chapterObjectives = [
    '기회비용: 여러 선택지 중 가장 좋은 선택을 찾아요.',
    '분산투자: 수혜와 피해를 함께 보며 균형을 맞춰요.',
    '리스크 관리: 투자 비율을 조절해 흔들림을 줄여요.',
  ];

  String _objectiveForChapter(int chapterNumber) {
    if (chapterNumber <= 0) return _chapterObjectives.first;
    return _chapterObjectives[(chapterNumber - 1) % _chapterObjectives.length];
  }

  @override
  Widget build(BuildContext context) {
    final done = state.currentScenario >= scenarios.length;
    final chapter = done
        ? scenarios.length
        : (state.currentScenario + 1).clamp(1, scenarios.length);
    final chapterObjective = _objectiveForChapter(chapter);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F8FF), Color(0xFFEFF6FF), Color(0xFFFFFFFF)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _MascotMapHeader(state: state, total: scenarios.length),
            const SizedBox(height: 8),
            _ChapterObjectiveBanner(
              chapter: chapter,
              objective: chapterObjective,
            ),
            const SizedBox(height: 12),
            _DifficultySelector(
              current: state.selectedDifficulty,
              onChanged: onDifficultyChanged,
            ),
            const SizedBox(height: 12),
            _AdventureMapCard(state: state, totalScenarios: scenarios.length),
            const SizedBox(height: 12),
            if (done)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFFE6FFF4),
                ),
                child: const Text(
                  '🏆 모든 챕터를 완주했어요! 리포트 탭에서 3대 KPI를 확인해보세요.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            else
              Expanded(
                child: ScenarioPlayCard(
                  key: ValueKey(
                    'scenario-${state.currentScenario}-${state.selectedDifficulty.index}',
                  ),
                  scenario: scenarios[state.currentScenario],
                  cash: state.cash,
                  difficulty: state.selectedDifficulty,
                  onDone: onDone,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChapterObjectiveBanner extends StatelessWidget {
  const _ChapterObjectiveBanner({required this.chapter, required this.objective});

  final int chapter;
  final String objective;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFF8E8),
        border: Border.all(color: const Color(0xFFFFDFA5)),
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '챕터 $chapter 학습 목표: $objective',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xFF5F4A1F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotMapHeader extends StatelessWidget {
  const _MascotMapHeader({required this.state, required this.total});

  final AppState state;
  final int total;

  @override
  Widget build(BuildContext context) {
    final chapter = state.currentScenario + 1 > total ? total : state.currentScenario + 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4E5), Color(0xFFE9F7FF)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text('🧸', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '챕터 $chapter 이동 중 · 자산 ${state.cash}코인',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({required this.current, required this.onChanged});

  final DifficultyLevel current;
  final ValueChanged<DifficultyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: DifficultyLevel.values
            .map(
              (d) => Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: current == d
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFFF1F3F8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${d.icon} ${d.label}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: current == d
                                ? Colors.white
                                : const Color(0xFF444B6E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.questName,
                          style: TextStyle(
                            fontSize: 11,
                            color: current == d ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AdventureMapCard extends StatelessWidget {
  const _AdventureMapCard({required this.state, required this.totalScenarios});

  final AppState state;
  final int totalScenarios;

  @override
  Widget build(BuildContext context) {
    final points = List.generate(totalScenarios, (i) {
      final x = (i % 5) / 4;
      final y = i < 5 ? 0.25 : 0.75;
      return Offset(i < 5 ? x : 1 - x, y);
    });

    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF4FF), Color(0xFFF6EDFF)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            return Stack(
              children: [
                CustomPaint(
                  size: Size(c.maxWidth, c.maxHeight),
                  painter: _MapPathPainter(
                    points: points,
                    completedCount: state.currentScenario,
                  ),
                ),
                ...List.generate(points.length, (i) {
                  final p = points[i];
                  final status = i < state.currentScenario
                      ? _NodeState.done
                      : i == state.currentScenario
                      ? _NodeState.current
                      : _NodeState.locked;
                  const zoneIcons = [
                    '🌿',
                    '🏙️',
                    '🚢',
                    '🏭',
                    '⚡',
                    '🛰️',
                    '🌧️',
                    '💹',
                    '🌾',
                    '🌋',
                  ];
                  return Positioned(
                    left: p.dx * (c.maxWidth - 30),
                    top: p.dy * (c.maxHeight - 30),
                    child: _MapNode(
                      index: i + 1,
                      state: status,
                      icon: zoneIcons[i % zoneIcons.length],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _NodeState { done, current, locked }

class _MapNode extends StatelessWidget {
  const _MapNode({required this.index, required this.state, required this.icon});

  final int index;
  final _NodeState state;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final bg = switch (state) {
      _NodeState.done => const Color(0xFF34C759),
      _NodeState.current => const Color(0xFF6C63FF),
      _NodeState.locked => const Color(0xFFCFD5E4),
    };

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: state == _NodeState.done
            ? const Icon(Icons.check, color: Colors.white, size: 17)
            : Text(icon, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

class _MapPathPainter extends CustomPainter {
  _MapPathPainter({required this.points, required this.completedCount});

  final List<Offset> points;
  final int completedCount;

  @override
  void paint(Canvas canvas, Size size) {
    final donePaint = Paint()
      ..color = const Color(0xFF62D48F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final todoPaint = Paint()
      ..color = const Color(0x80A8B3C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    for (var i = 0; i < points.length - 1; i++) {
      final p1 = Offset(
        points[i].dx * (size.width - 30) + 15,
        points[i].dy * (size.height - 30) + 15,
      );
      final p2 = Offset(
        points[i + 1].dx * (size.width - 30) + 15,
        points[i + 1].dy * (size.height - 30) + 15,
      );
      canvas.drawLine(p1, p2, i < completedCount ? donePaint : todoPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPathPainter oldDelegate) {
    return oldDelegate.completedCount != completedCount;
  }
}

class ScenarioPlayCard extends StatefulWidget {
  const ScenarioPlayCard({
    super.key,
    required this.scenario,
    required this.cash,
    required this.difficulty,
    required this.onDone,
  });

  final Scenario scenario;
  final int cash;
  final DifficultyLevel difficulty;
  final ValueChanged<ScenarioResult> onDone;

  @override
  State<ScenarioPlayCard> createState() => _ScenarioPlayCardState();
}

class _ScenarioPlayCardState extends State<ScenarioPlayCard> {
  int? _selectedIndustry;
  int? _reasoningAnswer;
  int? _quizAnswer;
  int? _allocationPercent;
  bool _submitted = false;
  bool _hintUnlocked = false;
  bool _hintUsed = false;
  int _wrongAttempts = 0;
  _PerformanceSnapshot? _resultSnapshot;
  String _mascotSpeech = '뉴스를 읽고 어떤 산업이 먼저 움직일지 찾아보자!';

  static const String _fallbackReasoningQuestion = '어떤 분석 관점이 가장 중요할까?';
  static const List<String> _fallbackReasoningChoices = [
    '뉴스와 직접 연결된 산업 먼저 확인',
    '영향이 몇 주/몇 달 갈지 기간 확인',
    '수혜+피해를 함께 보고 분산 전략 세우기',
  ];
  static const List<String> _chapterObjectiveKeywords = ['기회비용', '분산투자', '리스크 관리'];

  String get _chapterObjective =>
      _chapterObjectiveKeywords[(widget.scenario.id - 1) % _chapterObjectiveKeywords.length];

  String get _reasoningQuestion =>
      widget.scenario.reasoningQuestion ?? _fallbackReasoningQuestion;

  List<String> get _reasoningChoices {
    final custom = widget.scenario.reasoningChoices;
    if (custom != null && custom.length == 3) return custom;
    return _fallbackReasoningChoices;
  }

  int? _customBestReasoningIndex() {
    final map = widget.scenario.reasoningBestByDifficulty;
    if (map == null) return null;
    final best = map[widget.difficulty.name];
    if (best == null || best < 0 || best > 2) return null;
    return best;
  }

  int _reasoningScore() {
    if (_reasoningAnswer == null) return 0;

    final customBest = _customBestReasoningIndex();
    if (customBest != null) {
      if (_reasoningAnswer == customBest) return 100;
      return switch (widget.difficulty) {
        DifficultyLevel.easy => 75,
        DifficultyLevel.normal => 70,
        DifficultyLevel.hard => 65,
      };
    }

    const easy = [100, 75, 65];
    const normal = [80, 100, 70];
    const hard = [65, 80, 100];
    return switch (widget.difficulty) {
      DifficultyLevel.easy => easy[_reasoningAnswer!],
      DifficultyLevel.normal => normal[_reasoningAnswer!],
      DifficultyLevel.hard => hard[_reasoningAnswer!],
    };
  }

  int _riskScore() {
    final r = _allocationPercent;
    if (r == null) return 0;
    final (safeMin, safeMax) = switch (widget.difficulty) {
      DifficultyLevel.easy => (30, 60),
      DifficultyLevel.normal => (35, 65),
      DifficultyLevel.hard => (25, 55),
    };

    if (r >= safeMin && r <= safeMax) return 100;
    if (r >= safeMin - 10 && r <= safeMax + 10) return 82;
    if (r >= 20 && r <= 80) return 62;
    return 40;
  }

  int _emotionScore(int judgementScore) {
    final calmBase = _riskScore();
    final retryPenalty = _wrongAttempts * 8;
    final hintPenalty = _hintUsed ? 12 : 0;
    final panicPenalty = judgementScore < 55 ? 10 : 0;
    return (calmBase - retryPenalty - hintPenalty - panicPenalty).clamp(0, 100);
  }

  int? get _allocation => _allocationPercent;

  int get _investedCoins {
    final a = _allocation;
    if (a == null) return 0;
    return (widget.cash * (a / 100)).round().clamp(0, widget.cash);
  }

  ({int returnPercent, int rawProfit, int adjustedProfit, int volatilityRisk, String formulaLine, String coachingLine})
  _calculateInvestmentOutcome({
    required int invested,
    required int judgementScore,
    required int riskManagementScore,
  }) {
    final isGoodDecision = judgementScore >= 70;
    final qualityEdge = ((judgementScore - 60) / 2.0).round();
    final stabilityAdj = ((riskManagementScore - 70) / 8.0).round();

    final baseVolatility = switch (widget.difficulty) {
      DifficultyLevel.easy => 4,
      DifficultyLevel.normal => 7,
      DifficultyLevel.hard => 10,
    };
    final allocation = _allocation ?? 0;
    final volatilitySeed = (widget.scenario.id * 7 + allocation) % 6;
    final directionalVolatility = volatilitySeed - 2;
    final volatilityEffect = directionalVolatility * baseVolatility;

    var returnPercent = isGoodDecision
        ? 6 + qualityEdge + stabilityAdj + volatilityEffect
        : -6 - qualityEdge.abs() - stabilityAdj.abs() + volatilityEffect;

    if (widget.difficulty == DifficultyLevel.hard && !isGoodDecision && allocation >= 60) {
      returnPercent -= ((allocation - 50) / 4).round();
    }

    returnPercent = returnPercent.clamp(-65, 55);
    final rawProfit = (invested * returnPercent / 100).round();

    var adjustedProfit = rawProfit;
    if (adjustedProfit < 0) {
      switch (widget.difficulty) {
        case DifficultyLevel.easy:
          adjustedProfit = (adjustedProfit * 0.7).round();
          final lossCap = (invested * 0.16).round();
          adjustedProfit = max(adjustedProfit, -lossCap);
          break;
        case DifficultyLevel.normal:
          break;
        case DifficultyLevel.hard:
          adjustedProfit = (adjustedProfit * 1.2).round();
          break;
      }
    }

    final formulaLine = isGoodDecision
        ? '좋은 판단 × 투자금 $invested코인 × 수익률 $returnPercent% = ${rawProfit >= 0 ? '+' : ''}$rawProfit코인'
        : '아쉬운 판단 × 투자금 $invested코인 × 변동 수익률 $returnPercent% = ${rawProfit >= 0 ? '+' : ''}$rawProfit코인';

    final coachingLine = switch (widget.difficulty) {
      DifficultyLevel.easy => adjustedProfit < 0
          ? '좋아요! 쉬움 모드 손실 완충이 적용됐어요. 다음엔 비중을 40~60%로 맞춰보세요.'
          : '좋아요! 다음에도 한 번에 올인하지 않고 비중을 나눠서 수익을 지켜봐요.',
      DifficultyLevel.normal => adjustedProfit < 0
          ? '다음 행동: 근거가 약하면 비중을 줄여 손실 폭을 먼저 관리해요.'
          : '다음 행동: 근거가 강할 때만 비중을 조금씩 늘려보세요.',
      DifficultyLevel.hard => adjustedProfit < 0
          ? '하드 모드 경고: 높은 비중 실수는 손실이 커져요. 다음엔 20~50%부터 검증해요.'
          : '하드 모드 팁: 승률이 높아도 비중 분할로 변동성 충격을 줄여요.',
    };

    final volatilityRisk = (100 - riskManagementScore + baseVolatility * 2).clamp(0, 100);
    return (
      returnPercent: returnPercent,
      rawProfit: rawProfit,
      adjustedProfit: adjustedProfit,
      volatilityRisk: volatilityRisk,
      formulaLine: formulaLine,
      coachingLine: coachingLine,
    );
  }

  void _submit() {
    if (_selectedIndustry == null || _quizAnswer == null || _reasoningAnswer == null || _allocation == null || _submitted) {
      return;
    }

    final industryScore = widget.scenario.industryOptions[_selectedIndustry!].score;
    final quizScore = widget.scenario.quizOptions[_quizAnswer!].score;
    final reasonScore = _reasoningScore();
    final judgementScore = ((industryScore * 0.45) + (quizScore * 0.35) + (reasonScore * 0.20)).round();

    if (judgementScore < 55 && _wrongAttempts == 0) {
      setState(() {
        _wrongAttempts = 1;
        _hintUnlocked = true;
        _mascotSpeech = '좋은 시도야! 정답 하나가 아니라 점수를 올리는 방식이야. 힌트를 열었어!';
        _resultSnapshot = null;
      });
      return;
    }

    final riskManagementScore = _riskScore();
    final emotionControlScore = _emotionScore(judgementScore);
    final learningScore = ((judgementScore + riskManagementScore + emotionControlScore) / 3).round();

    final invested = _investedCoins;
    final outcome = _calculateInvestmentOutcome(
      invested: invested,
      judgementScore: judgementScore,
      riskManagementScore: riskManagementScore,
    );

    final hintPenalty = _hintUsed ? widget.difficulty.hintPenalty : 0;
    final finalProfit = outcome.adjustedProfit - hintPenalty;

    setState(() {
      _submitted = true;
      _mascotSpeech = learningScore >= 80
          ? '멋져! 투자 비중과 판단 근거를 함께 잘 맞췄어!'
          : '좋아! 이번 기록을 바탕으로 다음 챕터에서 비중 조절까지 연습해보자.';
      _resultSnapshot = _PerformanceSnapshot(
        judgementScore: judgementScore,
        riskManagementScore: riskManagementScore,
        emotionControlScore: emotionControlScore,
        learningScore: learningScore,
        allocationPercent: _allocation!,
        invested: invested,
        returnPercent: outcome.returnPercent,
        rawProfit: outcome.rawProfit,
        finalProfit: finalProfit,
        hintPenalty: hintPenalty,
        volatilityRisk: outcome.volatilityRisk,
        resilience: emotionControlScore,
        formulaLine: outcome.formulaLine,
        coachingLine: outcome.coachingLine,
      );
    });

    widget.onDone(
      ScenarioResult(
        scenarioId: widget.scenario.id,
        invested: invested,
        profit: finalProfit,
        returnPercent: outcome.returnPercent,
        judgementScore: judgementScore,
        riskManagementScore: riskManagementScore,
        emotionControlScore: emotionControlScore,
        hintUsed: _hintUsed,
        difficulty: widget.difficulty,
        timestamp: DateTime.now(),
      ),
    );
  }

  Widget _choiceTile({
    required String text,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? const Color(0xFFEAE8FF) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : const Color(0xFFDCE0EA),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF6C63FF) : const Color(0xFF9DA6BC),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scenario;

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _bubbleCard(_mascotSpeech),
        const SizedBox(height: 10),
        _newsCard(s),
        const SizedBox(height: 10),
        _gameSection(
          title: '1) 어떤 산업 카드에 투자할까?',
          child: Column(
            children: List.generate(
              s.industryOptions.length,
              (i) => _choiceTile(
                text: s.industryOptions[i].label,
                selected: _selectedIndustry == i,
                onTap: _submitted
                    ? null
                    : () => setState(() {
                        _selectedIndustry = i;
                        _mascotSpeech = '좋아! 다음은 근거를 더 깊게 정리해보자.';
                      }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _gameSection(
          title: '2) $_reasoningQuestion',
          child: Column(
            children: List.generate(
              _reasoningChoices.length,
              (i) => _choiceTile(
                text: _reasoningChoices[i],
                selected: _reasoningAnswer == i,
                onTap: _submitted
                    ? null
                    : () => setState(() {
                        _reasoningAnswer = i;
                        _mascotSpeech = '좋아! 이제 리스크 비율을 조절해보자.';
                      }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _gameSection(
          title: '3) 투자 비중 선택 ${_allocation == null ? '(미선택)' : '$_allocation%'}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '포지션 사이징 연습: 확신이 낮을수록 비중을 줄이고, 근거가 탄탄할수록 조금씩 늘려요.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4E5B7A)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [20, 30, 40, 50, 60, 70, 80].map((v) {
                  final selected = _allocation == v;
                  return ChoiceChip(
                    label: Text('$v%'),
                    selected: selected,
                    onSelected: _submitted
                        ? null
                        : (_) => setState(() {
                            _allocationPercent = v;
                            _mascotSpeech = '좋아, $v% 비중으로 포지션을 잡았어. 이제 제출해보자!';
                          }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _allocation == null
                      ? '투자 비중을 먼저 선택해 주세요.'
                      : '투자금 $_investedCoins코인 (보유 ${widget.cash}코인 중 $_allocation%)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _gameSection(
          title: '4) 퀴즈: ${s.quizQuestion}',
          child: Column(
            children: [
              ...List.generate(
                s.quizOptions.length,
                (i) => _choiceTile(
                  text: s.quizOptions[i].label,
                  selected: _quizAnswer == i,
                  onTap: _submitted
                      ? null
                      : () => setState(() {
                          _quizAnswer = i;
                          _mascotSpeech = '준비됐어! 점수 기반 결과를 확인해보자!';
                        }),
                ),
              ),
              const SizedBox(height: 10),
              if (_hintUnlocked && !_hintUsed)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _hintUsed = true),
                  icon: const Icon(Icons.lightbulb),
                  label: Text('힌트 보기 (1회, -${widget.difficulty.hintPenalty}코인)'),
                ),
              if (_hintUsed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '힌트: "${s.goodIndustries.first}" 같은 직접 수혜와 "${s.badIndustries.first}" 같은 피해를 함께 보며 판단해보세요.',
                  ),
                ),
              FilledButton.icon(
                onPressed: (_submitted || _allocation == null) ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_circle),
                label: Text(_wrongAttempts == 0 ? '점수 확인' : '재도전 완료'),
              ),
              if (_resultSnapshot != null) ...[
                const SizedBox(height: 10),
                _PerformanceResultCard(snapshot: _resultSnapshot!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubbleCard(String speech) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: Text('🧸', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(speech, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _newsCard(Scenario s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🗺️ ${widget.difficulty.questName} · 챕터 ${s.id}'),
          const SizedBox(height: 6),
          Text(s.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '이번 챕터 핵심: $_chapterObjective',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF3D4E91),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(s.news),
          const SizedBox(height: 10),
          if (widget.difficulty == DifficultyLevel.easy)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(
                  '수혜 ${s.goodIndustries.join(', ')}',
                  const Color(0xFFE6F8EA),
                  const Color(0xFF1F8D48),
                ),
                _tag(
                  '피해 ${s.badIndustries.join(', ')}',
                  const Color(0xFFFFECEC),
                  const Color(0xFFB93838),
                ),
              ],
            )
          else
            const Text(
              '💡 고급 모드: 수혜/피해와 기간을 스스로 추론해 점수를 높여보세요.',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4E5B7A)),
            ),
        ],
      ),
    );
  }

  Widget _gameSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _PerformanceSnapshot {
  const _PerformanceSnapshot({
    required this.judgementScore,
    required this.riskManagementScore,
    required this.emotionControlScore,
    required this.learningScore,
    required this.allocationPercent,
    required this.invested,
    required this.returnPercent,
    required this.rawProfit,
    required this.finalProfit,
    required this.hintPenalty,
    required this.volatilityRisk,
    required this.resilience,
    required this.formulaLine,
    required this.coachingLine,
  });

  final int judgementScore;
  final int riskManagementScore;
  final int emotionControlScore;
  final int learningScore;
  final int allocationPercent;
  final int invested;
  final int returnPercent;
  final int rawProfit;
  final int finalProfit;
  final int hintPenalty;
  final int volatilityRisk;
  final int resilience;
  final String formulaLine;
  final String coachingLine;
}

class _PerformanceResultCard extends StatelessWidget {
  const _PerformanceResultCard({required this.snapshot});

  final _PerformanceSnapshot snapshot;

  String get _overallComment {
    if (snapshot.learningScore >= 80) {
      return '아주 좋아! 수익과 안정성을 함께 챙긴 멋진 운영이야.';
    }
    if (snapshot.learningScore >= 60) {
      return '좋아! 다음엔 리스크를 조금만 더 다듬으면 더 탄탄해져.';
    }
    return '괜찮아, 탐험은 연습이야! 투자 비율을 조절하면 더 안정적으로 갈 수 있어.';
  }

  String get _riskComment {
    if (snapshot.volatilityRisk <= 20) return '흔들림이 작아 안정적이야.';
    if (snapshot.volatilityRisk <= 40) return '적당한 흔들림, 관리 가능한 수준!';
    return '변동성이 큰 편이야. 분산과 비율 조절을 시도해보자!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF5F8FF),
        border: Border.all(color: const Color(0xFFDCE5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📈 이번 탐험 성과', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip('수익률', '${snapshot.returnPercent}%'),
              _metricChip('변동성/리스크', '${snapshot.volatilityRisk}'),
              _metricChip('회복력(안정성)', '${snapshot.resilience}점'),
            ],
          ),
          const SizedBox(height: 8),
          Text('• 투자 비중: ${snapshot.allocationPercent}%'),
          Text('• 투자금: ${snapshot.invested}코인'),
          Text('• 수익/손실 계산: ${snapshot.formulaLine}'),
          if (snapshot.hintPenalty > 0)
            Text('• 힌트 사용 페널티: -${snapshot.hintPenalty}코인'),
          Text(
            '• 최종 변화: ${snapshot.finalProfit >= 0 ? '+' : ''}${snapshot.finalProfit}코인',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '• 리스크 해석: $_riskComment',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            '• 다음 행동 코칭: ${snapshot.coachingLine}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '• 총평: $_overallComment',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF2F3A56)),
          children: [
            TextSpan(
              text: '$title\n',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyReportTab extends StatelessWidget {
  const _WeeklyReportTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final chunks = <List<ScenarioResult>>[];
    for (var i = 0; i < state.results.length; i += 5) {
      chunks.add(state.results.sublist(i, min(i + 5, state.results.length)));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 성장 리포트 (핵심 KPI)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _kpiTile('판단 정확도', state.avgJudgementScore, Icons.gps_fixed),
                  const SizedBox(height: 8),
                  _kpiTile('리스크 관리 점수', state.avgRiskManagementScore, Icons.shield),
                  const SizedBox(height: 8),
                  _kpiTile('감정 통제 점수', state.avgEmotionControlScore, Icons.self_improvement),
                  const Divider(height: 24),
                  Text('평균 수익률: ${state.avgReturn.toStringAsFixed(1)}%'),
                  Text('누적 손익: ${state.totalProfit >= 0 ? '+' : ''}${state.totalProfit}코인'),
                  Text('힌트 사용: ${state.hintUsedCount}회'),
                  Text('현재 자산: ${state.cash}코인'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...chunks.asMap().entries.map((entry) {
            final week = entry.key + 1;
            final list = entry.value;
            final profit = list.fold<int>(0, (sum, e) => sum + e.profit);
            final judge = (list.fold<int>(0, (sum, e) => sum + e.judgementScore) / list.length).round();
            final risk = (list.fold<int>(0, (sum, e) => sum + e.riskManagementScore) / list.length).round();
            final emotion = (list.fold<int>(0, (sum, e) => sum + e.emotionControlScore) / list.length).round();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주간 리포트 $week (시나리오 ${list.first.scenarioId}~${list.last.scenarioId})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text('주간 손익: ${profit >= 0 ? '+' : ''}$profit코인'),
                    Text('판단 정확도: $judge점 · 리스크 관리: $risk점 · 감정 통제: $emotion점'),
                  ],
                ),
              ),
            );
          }),
          if (state.results.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('아직 리포트가 없어요. 탐험 맵에서 첫 시나리오를 플레이해보세요!'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpiTile(String title, int score, IconData icon) {
    final color = score >= 80
        ? const Color(0xFF1E9E54)
        : score >= 60
        ? const Color(0xFFCC8A00)
        : const Color(0xFFC0392B);

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text('$score점', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _GuideTab extends StatelessWidget {
  const _GuideTab({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '학습 목표\n'
                '• 쉬움: 뉴스-산업 직접 연결 찾기\n'
                '• 보통: 영향 지속 기간(단기/중기) 판단\n'
                '• 어려움: 2차 파급 + 분산 전략 설계\n'
                '• 점수형 평가: 하나의 정답이 아니라 선택 조합의 질을 평가',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('진행 초기화', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: onReset, child: const Text('처음부터 다시 탐험하기')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
