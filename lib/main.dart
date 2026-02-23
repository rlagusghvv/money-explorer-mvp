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

  @override
  Widget build(BuildContext context) {
    final done = state.currentScenario >= scenarios.length;

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
  double _riskRatio = 55;
  bool _submitted = false;
  bool _hintUnlocked = false;
  bool _hintUsed = false;
  int _wrongAttempts = 0;
  String? _resultText;
  String _mascotSpeech = '뉴스를 읽고 어떤 산업이 먼저 움직일지 찾아보자!';

  int _reasoningScore() {
    if (_reasoningAnswer == null) return 0;
    const easy = [100, 75, 65];
    const normal = [80, 100, 70];
    const hard = [65, 80, 100];
    return switch (widget.difficulty) {
      DifficultyLevel.easy => easy[_reasoningAnswer!],
      DifficultyLevel.normal => normal[_reasoningAnswer!],
      DifficultyLevel.hard => hard[_reasoningAnswer!],
    };
  }

  List<String> get _reasoningChoices => const [
    '뉴스와 직접 연결된 산업 먼저 확인',
    '영향이 몇 주/몇 달 갈지 기간 확인',
    '수혜+피해를 함께 보고 분산 전략 세우기',
  ];

  int _riskScore() {
    final r = _riskRatio.round();
    if (r >= 45 && r <= 65) return 100;
    if (r >= 35 && r <= 75) return 85;
    if (r >= 25 && r <= 85) return 65;
    return 40;
  }

  int _emotionScore(int judgementScore) {
    final calmBase = _riskScore();
    final retryPenalty = _wrongAttempts * 8;
    final hintPenalty = _hintUsed ? 12 : 0;
    final panicPenalty = judgementScore < 55 ? 10 : 0;
    return (calmBase - retryPenalty - hintPenalty - panicPenalty).clamp(0, 100);
  }

  int _toReturnPercent(int learningScore) {
    final base = switch (widget.difficulty) {
      DifficultyLevel.easy => -6,
      DifficultyLevel.normal => -10,
      DifficultyLevel.hard => -14,
    };
    final gain = (learningScore / 100 * 28).round();
    return base + gain;
  }

  void _submit() {
    if (_selectedIndustry == null || _quizAnswer == null || _reasoningAnswer == null || _submitted) {
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
        _resultText = '현재 판단 정확도 $judgementScore점. 힌트로 근거를 다듬고 점수를 올려보자!';
      });
      return;
    }

    final riskManagementScore = _riskScore();
    final emotionControlScore = _emotionScore(judgementScore);
    final learningScore = ((judgementScore + riskManagementScore + emotionControlScore) / 3).round();

    final invested = max(100, (widget.cash * (_riskRatio / 100)).round());
    final returnPercent = _toReturnPercent(learningScore);
    final rawProfit = (invested * returnPercent / 100).round();
    final hintPenalty = _hintUsed ? widget.difficulty.hintPenalty : 0;
    final finalProfit = rawProfit - hintPenalty;

    setState(() {
      _submitted = true;
      _mascotSpeech = learningScore >= 80
          ? '멋져! 여러 선택지 중에서도 균형 있게 높은 점수를 만들었어!'
          : '좋아! 이번 기록을 바탕으로 다음 챕터에서 더 높은 점수를 노려보자.';
      _resultText =
          '판단 정확도 $judgementScore점 · 리스크 관리 $riskManagementScore점 · 감정 통제 $emotionControlScore점\n'
          '학습 점수 평균 $learningScore점\n'
          '투자금 $invested코인 · 수익률 $returnPercent%\n'
          '최종 변화: ${finalProfit >= 0 ? '+' : ''}$finalProfit코인';
    });

    widget.onDone(
      ScenarioResult(
        scenarioId: widget.scenario.id,
        invested: invested,
        profit: finalProfit,
        returnPercent: returnPercent,
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
          title: '2) 어떤 분석 관점이 가장 중요할까?',
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
          title: '3) 리스크 게이지 ${_riskRatio.round()}%',
          child: Column(
            children: [
              Slider.adaptive(
                value: _riskRatio,
                min: 20,
                max: 100,
                divisions: 8,
                label: '${_riskRatio.round()}%',
                onChanged: _submitted
                    ? null
                    : (v) => setState(() {
                        _riskRatio = v;
                      }),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('투자 예정금 ${max(100, (widget.cash * (_riskRatio / 100)).round())}코인'),
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
                onPressed: _submitted ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_circle),
                label: Text(_wrongAttempts == 0 ? '점수 확인' : '재도전 완료'),
              ),
              if (_resultText != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFF5F8FF),
                  ),
                  child: Text(_resultText!, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
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
