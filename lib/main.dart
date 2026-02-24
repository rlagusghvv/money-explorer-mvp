import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/auth_sync_service.dart';
import 'data/scenario_repository.dart';
import 'models/scenario.dart';

void main() {
  runApp(const KidEconMvpApp());
}

enum DifficultyLevel { easy, normal, hard }

enum LearnerAgeBand { younger, middle, older }

enum MarketMood { calm, balanced, wobbly }

enum QuizInteractionType { multipleChoice, ox, ordering, matching }

extension QuizInteractionTypeX on QuizInteractionType {
  String get label => switch (this) {
    QuizInteractionType.multipleChoice => '객관식',
    QuizInteractionType.ox => 'OX',
    QuizInteractionType.ordering => '순서 배열',
    QuizInteractionType.matching => '매칭',
  };
}

extension MarketMoodX on MarketMood {
  String get label => switch (this) {
    MarketMood.calm => '맑음',
    MarketMood.balanced => '보통',
    MarketMood.wobbly => '흔들림',
  };

  String icon(LearnerAgeBand band) => switch (this) {
    MarketMood.calm => '☀️',
    MarketMood.balanced => '⛅',
    MarketMood.wobbly => band == LearnerAgeBand.younger ? '🌧️' : '🌪️',
  };
}

class ChapterCondition {
  const ChapterCondition({
    required this.marketMood,
    required this.volatilityShift,
    required this.riskContext,
  });

  final MarketMood marketMood;
  final int volatilityShift;
  final String riskContext;

  String summary(LearnerAgeBand band) {
    final volatilityWord = volatilityShift > 0
        ? '+$volatilityShift'
        : volatilityShift < 0
        ? '$volatilityShift'
        : '0';
    return '${marketMood.icon(band)} ${marketMood.label} · 변동 $volatilityWord';
  }
}

class StoredSession {
  const StoredSession({
    required this.userId,
    required this.email,
    required this.token,
  });

  final String userId;
  final String email;
  final String token;

  factory StoredSession.fromJson(Map<String, dynamic> json) {
    return StoredSession(
      userId: json['userId'] as String,
      email: json['email'] as String,
      token: json['token'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'token': token,
  };
}

extension LearnerAgeBandX on LearnerAgeBand {
  String get label => switch (this) {
    LearnerAgeBand.younger => '8-10세',
    LearnerAgeBand.middle => '11-13세',
    LearnerAgeBand.older => '14-16세',
  };

  String get learningStyle => switch (this) {
    LearnerAgeBand.younger => '쉬운 문장 + 구체적 힌트',
    LearnerAgeBand.middle => '적당한 추론 + 균형형 힌트',
    LearnerAgeBand.older => '심화 용어 + 근거 중심 피드백',
  };

  DifficultyLevel get defaultDifficulty => switch (this) {
    LearnerAgeBand.younger => DifficultyLevel.easy,
    LearnerAgeBand.middle => DifficultyLevel.normal,
    LearnerAgeBand.older => DifficultyLevel.hard,
  };

  String get introLine => switch (this) {
    LearnerAgeBand.younger => '뉴스를 생활 장면과 연결해서 생각해요.',
    LearnerAgeBand.middle => '뉴스의 원인-결과를 단계적으로 분석해요.',
    LearnerAgeBand.older => '변수 간 상호작용과 리스크를 논리적으로 검토해요.',
  };
}

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
  StoredSession? _session;
  final _authService = AuthSyncService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _state = await AppStateStore.load();
    _scenarios = await ScenarioRepository.loadScenarios();
    _session = await AppStateStore.loadSession();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return GameHomePage(
      initialState: _state,
      scenarios: _scenarios,
      initialSession: _session,
      authService: _authService,
    );
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
    required this.allocationPercent,
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
  final int allocationPercent;

  factory ScenarioResult.fromJson(Map<String, dynamic> json) {
    return ScenarioResult(
      scenarioId: (json['scenarioId'] as num?)?.round() ?? 0,
      invested: (json['invested'] as num?)?.round() ?? 0,
      profit: (json['profit'] as num?)?.round() ?? 0,
      returnPercent: (json['returnPercent'] as num?)?.round() ?? 0,
      judgementScore: (json['judgementScore'] as num?)?.round() ?? 0,
      riskManagementScore: (json['riskManagementScore'] as num?)?.round() ?? 0,
      emotionControlScore: (json['emotionControlScore'] as num?)?.round() ?? 0,
      hintUsed: json['hintUsed'] == true,
      difficulty: DifficultyLevel.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => DifficultyLevel.easy,
      ),
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      allocationPercent: (json['allocationPercent'] as num?)?.round() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
    'scenarioId': scenarioId,
    'invested': invested,
    'profit': profit,
    'returnPercent': returnPercent,
    'judgementScore': judgementScore,
    'riskManagementScore': riskManagementScore,
    'emotionControlScore': emotionControlScore,
    'hintUsed': hintUsed,
    'difficulty': difficulty.name,
    'timestamp': timestamp.toIso8601String(),
    'allocationPercent': allocationPercent,
  };

  int get totalLearningScore =>
      ((judgementScore + riskManagementScore + emotionControlScore) / 3)
          .round();
}

enum CosmeticType { character, home, decoration }

enum DecorationZone { wall, floor, desk }

extension DecorationZoneX on DecorationZone {
  String get key => name;

  String get label => switch (this) {
    DecorationZone.wall => '벽 꾸미기',
    DecorationZone.floor => '바닥 꾸미기',
    DecorationZone.desk => '소품 선반',
  };
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.emoji,
    required this.description,
    this.zone,
  });

  final String id;
  final String name;
  final CosmeticType type;
  final int price;
  final String emoji;
  final String description;
  final DecorationZone? zone;
}

const List<ShopItem> kShopItems = [
  ShopItem(
    id: 'char_default',
    name: '기본 탐험곰',
    type: CosmeticType.character,
    price: 0,
    emoji: '🧸',
    description: '처음 함께하는 든든한 탐험대장!',
  ),
  ShopItem(
    id: 'char_fox',
    name: '번개여우',
    type: CosmeticType.character,
    price: 120,
    emoji: '🦊',
    description: '빠르게 뉴스 흐름을 읽는 여우!',
  ),
  ShopItem(
    id: 'char_penguin',
    name: '쿨펭',
    type: CosmeticType.character,
    price: 130,
    emoji: '🐧',
    description: '침착함으로 변동장을 버티는 친구!',
  ),
  ShopItem(
    id: 'char_tiger',
    name: '용감호랑',
    type: CosmeticType.character,
    price: 150,
    emoji: '🐯',
    description: '결단력 있는 투자 파트너!',
  ),
  ShopItem(
    id: 'char_robot',
    name: '데이터봇',
    type: CosmeticType.character,
    price: 180,
    emoji: '🤖',
    description: '근거 중심으로 차근차근 분석!',
  ),
  ShopItem(
    id: 'char_unicorn',
    name: '드림유니',
    type: CosmeticType.character,
    price: 210,
    emoji: '🦄',
    description: '꾸준한 저축 습관을 응원해요!',
  ),
  ShopItem(
    id: 'home_base_default',
    name: '기본 베이스',
    type: CosmeticType.home,
    price: 0,
    emoji: '🏕️',
    description: '기본 캠프 베이스예요.',
  ),
  ShopItem(
    id: 'home_forest',
    name: '숲속 캠프',
    type: CosmeticType.home,
    price: 110,
    emoji: '🌲',
    description: '초록 에너지로 안정감 업!',
  ),
  ShopItem(
    id: 'home_city',
    name: '시티 허브',
    type: CosmeticType.home,
    price: 140,
    emoji: '🏙️',
    description: '뉴스 정보가 모이는 분주한 본부!',
  ),
  ShopItem(
    id: 'home_ocean',
    name: '오션 독',
    type: CosmeticType.home,
    price: 150,
    emoji: '🌊',
    description: '파도처럼 유연한 리스크 관리!',
  ),
  ShopItem(
    id: 'home_space',
    name: '스페이스 랩',
    type: CosmeticType.home,
    price: 180,
    emoji: '🚀',
    description: '미래 산업 분석에 딱 맞는 기지!',
  ),
  ShopItem(
    id: 'home_castle',
    name: '코인 캐슬',
    type: CosmeticType.home,
    price: 220,
    emoji: '🏰',
    description: '저축왕만 입장 가능한 꿈의 성!',
  ),
  ShopItem(
    id: 'deco_wall_chart',
    name: '경제 차트 포스터',
    type: CosmeticType.decoration,
    zone: DecorationZone.wall,
    price: 0,
    emoji: '📊',
    description: '벽면에 붙이는 탐험 차트 포스터!',
  ),
  ShopItem(
    id: 'deco_wall_star',
    name: '반짝 별 스티커',
    type: CosmeticType.decoration,
    zone: DecorationZone.wall,
    price: 80,
    emoji: '🌟',
    description: '벽을 환하게 만드는 별빛 장식!',
  ),
  ShopItem(
    id: 'deco_floor_rug',
    name: '포근 러그',
    type: CosmeticType.decoration,
    zone: DecorationZone.floor,
    price: 0,
    emoji: '🧶',
    description: '바닥에 깔아 아늑함 업!',
  ),
  ShopItem(
    id: 'deco_floor_coinbox',
    name: '코인 저금 상자',
    type: CosmeticType.decoration,
    zone: DecorationZone.floor,
    price: 105,
    emoji: '💰',
    description: '저축 습관을 보여주는 미니 박스!',
  ),
  ShopItem(
    id: 'deco_desk_globe',
    name: '뉴스 지구본',
    type: CosmeticType.decoration,
    zone: DecorationZone.desk,
    price: 0,
    emoji: '🌍',
    description: '선반 위 글로벌 뉴스 탐험 소품!',
  ),
  ShopItem(
    id: 'deco_desk_trophy',
    name: '미니 트로피',
    type: CosmeticType.decoration,
    zone: DecorationZone.desk,
    price: 120,
    emoji: '🏆',
    description: '챕터 완주를 기념하는 반짝 트로피!',
  ),
];

class AppState {
  const AppState({
    required this.playerName,
    required this.cash,
    required this.rewardPoints,
    required this.currentScenario,
    required this.results,
    required this.bestStreak,
    required this.onboarded,
    required this.selectedDifficulty,
    required this.learnerAgeBand,
    required this.ownedItemIds,
    required this.equippedCharacterId,
    required this.equippedHomeId,
    required this.equippedDecorations,
    required this.totalPointsSpent,
    required this.soundMuted,
  });

  factory AppState.initial() => const AppState(
    playerName: '탐험대원',
    cash: 1000,
    rewardPoints: 0,
    currentScenario: 0,
    results: [],
    bestStreak: 0,
    onboarded: false,
    selectedDifficulty: DifficultyLevel.easy,
    learnerAgeBand: LearnerAgeBand.middle,
    ownedItemIds: {
      'char_default',
      'home_base_default',
      'deco_wall_chart',
      'deco_floor_rug',
      'deco_desk_globe',
    },
    equippedCharacterId: 'char_default',
    equippedHomeId: 'home_base_default',
    equippedDecorations: {
      DecorationZone.wall: 'deco_wall_chart',
      DecorationZone.floor: 'deco_floor_rug',
      DecorationZone.desk: 'deco_desk_globe',
    },
    totalPointsSpent: 0,
    soundMuted: false,
  );

  final String playerName;
  final int cash;
  final int rewardPoints;
  final int currentScenario;
  final List<ScenarioResult> results;
  final int bestStreak;
  final bool onboarded;
  final DifficultyLevel selectedDifficulty;
  final LearnerAgeBand learnerAgeBand;
  final Set<String> ownedItemIds;
  final String equippedCharacterId;
  final String equippedHomeId;
  final Map<DecorationZone, String?> equippedDecorations;
  final int totalPointsSpent;
  final bool soundMuted;

  ShopItem get equippedCharacter => kShopItems.firstWhere(
    (item) => item.id == equippedCharacterId,
    orElse: () => kShopItems.first,
  );

  ShopItem get equippedHome => kShopItems.firstWhere(
    (item) => item.id == equippedHomeId,
    orElse: () =>
        kShopItems.firstWhere((item) => item.type == CosmeticType.home),
  );

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

  factory AppState.fromJson(Map<String, dynamic> json) {
    final initial = AppState.initial();
    final owned = {
      ...initial.ownedItemIds,
      ...((json['ownedItemIds'] as List<dynamic>? ?? const [])
          .whereType<String>()),
    };

    final rawDecorations =
        json['equippedDecorations'] as Map<String, dynamic>? ?? const {};
    final equippedDecorations = {
      for (final zone in DecorationZone.values)
        zone: rawDecorations[zone.key] as String?,
    };

    return AppState(
      playerName: json['playerName'] as String? ?? initial.playerName,
      cash: (json['cash'] as num?)?.round() ?? initial.cash,
      rewardPoints:
          (json['rewardPoints'] as num?)?.round() ?? initial.rewardPoints,
      currentScenario:
          (json['currentScenario'] as num?)?.round() ?? initial.currentScenario,
      results: (json['results'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ScenarioResult.fromJson)
          .toList(),
      bestStreak: (json['bestStreak'] as num?)?.round() ?? initial.bestStreak,
      onboarded: json['onboarded'] == true,
      selectedDifficulty: DifficultyLevel.values.firstWhere(
        (d) => d.name == json['selectedDifficulty'],
        orElse: () => initial.selectedDifficulty,
      ),
      learnerAgeBand: LearnerAgeBand.values.firstWhere(
        (b) => b.name == json['learnerAgeBand'],
        orElse: () => initial.learnerAgeBand,
      ),
      ownedItemIds: owned,
      equippedCharacterId:
          (json['equippedCharacterId'] as String?) ??
          initial.equippedCharacterId,
      equippedHomeId:
          (json['equippedHomeId'] as String?) ?? initial.equippedHomeId,
      equippedDecorations: {
        for (final zone in DecorationZone.values)
          zone: owned.contains(equippedDecorations[zone])
              ? equippedDecorations[zone]
              : null,
      },
      totalPointsSpent:
          (json['totalPointsSpent'] as num?)?.round() ??
          initial.totalPointsSpent,
      soundMuted: json['soundMuted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerName': playerName,
    'cash': cash,
    'rewardPoints': rewardPoints,
    'currentScenario': currentScenario,
    'results': results.map((e) => e.toJson()).toList(),
    'bestStreak': bestStreak,
    'onboarded': onboarded,
    'selectedDifficulty': selectedDifficulty.name,
    'learnerAgeBand': learnerAgeBand.name,
    'ownedItemIds': ownedItemIds.toList(),
    'equippedCharacterId': equippedCharacterId,
    'equippedHomeId': equippedHomeId,
    'equippedDecorations': {
      for (final entry in equippedDecorations.entries)
        entry.key.key: entry.value,
    },
    'totalPointsSpent': totalPointsSpent,
    'soundMuted': soundMuted,
  };

  AppState copyWith({
    String? playerName,
    int? cash,
    int? rewardPoints,
    int? currentScenario,
    List<ScenarioResult>? results,
    int? bestStreak,
    bool? onboarded,
    DifficultyLevel? selectedDifficulty,
    LearnerAgeBand? learnerAgeBand,
    Set<String>? ownedItemIds,
    String? equippedCharacterId,
    String? equippedHomeId,
    Map<DecorationZone, String?>? equippedDecorations,
    int? totalPointsSpent,
    bool? soundMuted,
  }) {
    return AppState(
      playerName: playerName ?? this.playerName,
      cash: cash ?? this.cash,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      currentScenario: currentScenario ?? this.currentScenario,
      results: results ?? this.results,
      bestStreak: bestStreak ?? this.bestStreak,
      onboarded: onboarded ?? this.onboarded,
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
      learnerAgeBand: learnerAgeBand ?? this.learnerAgeBand,
      ownedItemIds: ownedItemIds ?? this.ownedItemIds,
      equippedCharacterId: equippedCharacterId ?? this.equippedCharacterId,
      equippedHomeId: equippedHomeId ?? this.equippedHomeId,
      equippedDecorations: equippedDecorations ?? this.equippedDecorations,
      totalPointsSpent: totalPointsSpent ?? this.totalPointsSpent,
      soundMuted: soundMuted ?? this.soundMuted,
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
  static const _kLearnerAgeBand = 'learnerAgeBand';
  static const _kRewardPoints = 'rewardPoints';
  static const _kOwnedItemIds = 'ownedItemIds';
  static const _kEquippedCharacterId = 'equippedCharacterId';
  static const _kEquippedHomeId = 'equippedHomeId';
  static const _kEquippedDecorations = 'equippedDecorations';
  static const _kTotalPointsSpent = 'totalPointsSpent';
  static const _kAuthSession = 'authSession';
  static const _kSoundMuted = 'soundMuted';

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final initial = AppState.initial();
    final raw = prefs.getStringList(_kResults) ?? [];

    final parsed = raw
        .map((line) {
          final parts = line.split('|');
          if (parts.length < 8) return null;

          final isVeryLegacy = parts.length < 10;
          if (isVeryLegacy) {
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
              emotionControlScore: (parts.length > 5 && parts[5] == '1')
                  ? 55
                  : 75,
              hintUsed: parts.length > 5 ? parts[5] == '1' : false,
              difficulty: parts.length > 6
                  ? _difficultyFrom(parts[6])
                  : DifficultyLevel.easy,
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                int.tryParse(parts.length > 7 ? parts[7] : '') ??
                    DateTime.now().millisecondsSinceEpoch,
              ),
              allocationPercent: 50,
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
            allocationPercent: parts.length > 10
                ? int.tryParse(parts[10]) ?? 50
                : 50,
          );
        })
        .whereType<ScenarioResult>()
        .toList();

    final ageBand = _ageBandFrom(
      prefs.getString(_kLearnerAgeBand) ?? LearnerAgeBand.middle.name,
    );

    final owned = {
      ...initial.ownedItemIds,
      ...(prefs.getStringList(_kOwnedItemIds) ?? const []),
    };
    final equippedCharacterId =
        prefs.getString(_kEquippedCharacterId) ?? initial.equippedCharacterId;
    final equippedHomeId =
        prefs.getString(_kEquippedHomeId) ?? initial.equippedHomeId;
    Map<String, dynamic> decorationRaw = const {};
    final decorationJson = prefs.getString(_kEquippedDecorations);
    if (decorationJson != null && decorationJson.isNotEmpty) {
      try {
        decorationRaw = jsonDecode(decorationJson) as Map<String, dynamic>;
      } catch (_) {
        decorationRaw = const {};
      }
    }

    return AppState(
      playerName: prefs.getString(_kPlayerName) ?? initial.playerName,
      cash: prefs.getInt(_kCash) ?? initial.cash,
      rewardPoints: prefs.getInt(_kRewardPoints) ?? initial.rewardPoints,
      currentScenario:
          prefs.getInt(_kCurrentScenario) ?? initial.currentScenario,
      results: parsed,
      bestStreak: prefs.getInt(_kBestStreak) ?? initial.bestStreak,
      onboarded: prefs.getBool(_kOnboarded) ?? initial.onboarded,
      selectedDifficulty: _difficultyFrom(
        prefs.getString(_kDifficulty) ?? ageBand.defaultDifficulty.name,
      ),
      learnerAgeBand: ageBand,
      ownedItemIds: owned,
      equippedCharacterId: owned.contains(equippedCharacterId)
          ? equippedCharacterId
          : initial.equippedCharacterId,
      equippedHomeId: owned.contains(equippedHomeId)
          ? equippedHomeId
          : initial.equippedHomeId,
      equippedDecorations: {
        for (final zone in DecorationZone.values)
          zone: owned.contains(decorationRaw[zone.key])
              ? decorationRaw[zone.key] as String?
              : null,
      },
      totalPointsSpent:
          prefs.getInt(_kTotalPointsSpent) ?? initial.totalPointsSpent,
      soundMuted: prefs.getBool(_kSoundMuted) ?? initial.soundMuted,
    );
  }

  static DifficultyLevel _difficultyFrom(String raw) {
    return DifficultyLevel.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => DifficultyLevel.easy,
    );
  }

  static LearnerAgeBand _ageBandFrom(String raw) {
    return LearnerAgeBand.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => LearnerAgeBand.middle,
    );
  }

  static Future<void> save(AppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlayerName, state.playerName);
    await prefs.setInt(_kCash, state.cash);
    await prefs.setInt(_kRewardPoints, state.rewardPoints);
    await prefs.setInt(_kCurrentScenario, state.currentScenario);
    await prefs.setInt(_kBestStreak, state.bestStreak);
    await prefs.setBool(_kOnboarded, state.onboarded);
    await prefs.setString(_kDifficulty, state.selectedDifficulty.name);
    await prefs.setString(_kLearnerAgeBand, state.learnerAgeBand.name);
    await prefs.setStringList(_kOwnedItemIds, state.ownedItemIds.toList());
    await prefs.setString(_kEquippedCharacterId, state.equippedCharacterId);
    await prefs.setString(_kEquippedHomeId, state.equippedHomeId);
    await prefs.setString(
      _kEquippedDecorations,
      jsonEncode({
        for (final entry in state.equippedDecorations.entries)
          entry.key.key: entry.value,
      }),
    );
    await prefs.setInt(_kTotalPointsSpent, state.totalPointsSpent);
    await prefs.setBool(_kSoundMuted, state.soundMuted);

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
            e.allocationPercent,
          ].join('|'),
        )
        .toList();
    await prefs.setStringList(_kResults, encoded);
  }

  static Future<StoredSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAuthSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return StoredSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSession(StoredSession? session) async {
    final prefs = await SharedPreferences.getInstance();
    if (session == null) {
      await prefs.remove(_kAuthSession);
      return;
    }
    await prefs.setString(_kAuthSession, jsonEncode(session.toJson()));
  }
}

class GameHomePage extends StatefulWidget {
  const GameHomePage({
    super.key,
    required this.initialState,
    required this.scenarios,
    required this.authService,
    this.initialSession,
  });

  final AppState initialState;
  final List<Scenario> scenarios;
  final AuthSyncService authService;
  final StoredSession? initialSession;

  @override
  State<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends State<GameHomePage> {
  late AppState _state;
  int _tabIndex = 0;
  StoredSession? _session;
  bool _syncing = false;
  String? _syncMessage;

  bool get _isLoggedIn => _session != null;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _session = widget.initialSession;
    if (!_state.onboarded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboarding());
    }
    if (_isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryLoadCloudProgress(),
      );
    }
  }

  Future<void> _showOnboarding() async {
    var selectedBand = _state.learnerAgeBand;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('🧭 탐험대 등록'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '플레이 시작 전 학습자 연령대를 선택해주세요.\n'
                  '연령대에 따라 질문 문장, 힌트 깊이, 기본 난이도가 자동 조정돼요.',
                ),
                const SizedBox(height: 12),
                ...LearnerAgeBand.values.map(
                  (band) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setDialogState(() => selectedBand = band),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedBand == band
                              ? const Color(0xFF6C63FF)
                              : const Color(0xFFD8DCEE),
                        ),
                        color: selectedBand == band
                            ? const Color(0xFFEDEBFF)
                            : Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${band.label} · ${band.learningStyle}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('기본 난이도: ${band.defaultDifficulty.label}'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '이제 정답/오답이 아닌 점수형 평가예요.\n'
                  '선택마다 부분 점수를 받고, 힌트는 오답 뒤 1회 열립니다.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                setState(() {
                  _state = _state.copyWith(
                    onboarded: true,
                    learnerAgeBand: selectedBand,
                    selectedDifficulty: selectedBand.defaultDifficulty,
                  );
                });
                _persist();
                Navigator.pop(context);
              },
              child: const Text('탐험 시작!'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persist() async {
    await AppStateStore.save(_state);
    final session = _session;
    if (session == null) return;
    try {
      await widget.authService.saveProgress(
        token: session.token,
        progress: _state.toJson(),
      );
      if (mounted) {
        setState(() => _syncMessage = '클라우드 동기화 완료');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _syncMessage = '오프라인 저장됨 (클라우드 재시도 가능)');
      }
    }
  }

  Future<void> _tryLoadCloudProgress() async {
    final session = _session;
    if (session == null || _syncing) return;
    setState(() {
      _syncing = true;
      _syncMessage = '클라우드 데이터 확인 중...';
    });
    try {
      final cloud = await widget.authService.loadProgress(token: session.token);
      if (cloud != null) {
        _state = AppState.fromJson(cloud);
        await AppStateStore.save(_state);
      } else {
        await widget.authService.saveProgress(
          token: session.token,
          progress: _state.toJson(),
        );
      }
      if (mounted) {
        setState(() => _syncMessage = '클라우드 동기화 완료');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _syncMessage = '로컬 모드로 진행 중');
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _onAuthChanged(StoredSession? session) async {
    _session = session;
    await AppStateStore.saveSession(session);
    if (mounted) {
      setState(() {
        _syncMessage = session == null ? '게스트 모드' : '로그인됨: ${session.email}';
      });
    }
    if (session != null) {
      await _tryLoadCloudProgress();
    }
  }

  int _earnedPointsFromResult(ScenarioResult result) {
    final base = (result.totalLearningScore * 0.9).round();
    final streakBonus = _state.results.isNotEmpty ? 8 : 0;
    final noHintBonus = result.hintUsed ? 0 : 10;
    return max(15, base + streakBonus + noHintBonus);
  }

  void _applyScenarioResult(ScenarioResult result) {
    final nextResults = [..._state.results, result];
    final earnedPoints = _earnedPointsFromResult(result);
    setState(() {
      _state = _state.copyWith(
        cash: max(0, _state.cash + result.profit),
        rewardPoints: _state.rewardPoints + earnedPoints,
        currentScenario: min(
          widget.scenarios.length,
          _state.currentScenario + 1,
        ),
        results: nextResults,
      );
      _tabIndex = 0;
    });
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🎁 탐험 포인트 +$earnedPoints! 상점에서 꾸미기를 열어보세요.')),
    );
  }

  void _buyAndEquipItem(ShopItem item) {
    if (_state.ownedItemIds.contains(item.id)) {
      _equipItem(item);
      return;
    }
    if (_state.rewardPoints < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '포인트가 ${item.price - _state.rewardPoints}점 부족해요. 탐험으로 모아보자!',
          ),
        ),
      );
      return;
    }

    final owned = {..._state.ownedItemIds, item.id};
    final nextDecorations = {..._state.equippedDecorations};
    if (item.type == CosmeticType.decoration && item.zone != null) {
      nextDecorations[item.zone!] = item.id;
    }

    setState(() {
      _state = _state.copyWith(
        rewardPoints: _state.rewardPoints - item.price,
        ownedItemIds: owned,
        totalPointsSpent: _state.totalPointsSpent + item.price,
        equippedCharacterId: item.type == CosmeticType.character
            ? item.id
            : _state.equippedCharacterId,
        equippedHomeId: item.type == CosmeticType.home
            ? item.id
            : _state.equippedHomeId,
        equippedDecorations: nextDecorations,
      );
    });
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.emoji} ${item.name} 구매 완료! 바로 장착됐어요.')),
    );
  }

  void _equipItem(ShopItem item) {
    if (!_state.ownedItemIds.contains(item.id)) return;
    final nextDecorations = {..._state.equippedDecorations};
    if (item.type == CosmeticType.decoration && item.zone != null) {
      nextDecorations[item.zone!] = item.id;
    }

    setState(() {
      _state = _state.copyWith(
        equippedCharacterId: item.type == CosmeticType.character
            ? item.id
            : _state.equippedCharacterId,
        equippedHomeId: item.type == CosmeticType.home
            ? item.id
            : _state.equippedHomeId,
        equippedDecorations: nextDecorations,
      );
    });
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.emoji} ${item.name} 장착 완료!')),
    );
  }

  void _placeDecoration(DecorationZone zone, String? itemId) {
    if (itemId != null && !_state.ownedItemIds.contains(itemId)) return;
    final next = {..._state.equippedDecorations, zone: itemId};
    setState(() {
      _state = _state.copyWith(equippedDecorations: next);
    });
    _persist();
  }

  void _resetProgress() {
    setState(() {
      _state = AppState.initial().copyWith(
        playerName: _state.playerName,
        onboarded: true,
        selectedDifficulty: _state.selectedDifficulty,
        learnerAgeBand: _state.learnerAgeBand,
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
        onSoundMutedChanged: (muted) {
          setState(() => _state = _state.copyWith(soundMuted: muted));
          _persist();
        },
      ),
      _MyHomeTab(
        state: _state,
        syncMessage: _syncMessage,
        session: _session,
        onPlaceDecoration: _placeDecoration,
      ),
      _ShopTab(state: _state, onBuyOrEquip: _buyAndEquipItem),
      _WeeklyReportTab(state: _state),
      _GuideTab(
        state: _state,
        session: _session,
        isSyncing: _syncing,
        onReset: _resetProgress,
        onSessionChanged: _onAuthChanged,
        authService: widget.authService,
        onAgeBandChanged: (band) {
          setState(() {
            _state = _state.copyWith(
              learnerAgeBand: band,
              selectedDifficulty: band.defaultDifficulty,
            );
          });
          _persist();
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('뉴스 포트폴리오 탐험대')),
      body: SafeArea(child: pages[_tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (v) => setState(() => _tabIndex = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore), label: '탐험 맵'),
          NavigationDestination(icon: Icon(Icons.cottage), label: '마이홈'),
          NavigationDestination(icon: Icon(Icons.storefront), label: '상점'),
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
    required this.onSoundMutedChanged,
  });

  final AppState state;
  final List<Scenario> scenarios;
  final ValueChanged<ScenarioResult> onDone;
  final ValueChanged<DifficultyLevel> onDifficultyChanged;
  final ValueChanged<bool> onSoundMutedChanged;

  static const List<String> _chapterObjectives = [
    '기회비용: 여러 선택지 중 가장 좋은 선택을 찾아요.',
    '분산투자: 수혜와 피해를 함께 보며 균형을 맞춰요.',
    '리스크 관리: 투자 비율을 조절해 흔들림을 줄여요.',
  ];

  String _objectiveForChapter(int chapterNumber) {
    if (chapterNumber <= 0) return _chapterObjectives.first;
    return _chapterObjectives[(chapterNumber - 1) % _chapterObjectives.length];
  }

  ChapterCondition _conditionForNextChapter() {
    if (state.results.isEmpty) {
      return const ChapterCondition(
        marketMood: MarketMood.balanced,
        volatilityShift: 0,
        riskContext: '첫 챕터라 기본 시장 컨디션이에요. 차분하게 시작해요!',
      );
    }

    final last = state.results.last;
    final quality =
        ((last.judgementScore +
                    last.riskManagementScore +
                    last.emotionControlScore) /
                3)
            .round();
    final aggressive = last.allocationPercent >= 70;

    if (quality >= 82 && last.returnPercent >= 0 && !aggressive) {
      return const ChapterCondition(
        marketMood: MarketMood.calm,
        volatilityShift: -2,
        riskContext: '지난 챕터에서 균형 잡힌 결정을 했어요. 다음 장은 비교적 차분해요.',
      );
    }
    if (quality < 62 || last.returnPercent < 0 || aggressive) {
      return const ChapterCondition(
        marketMood: MarketMood.wobbly,
        volatilityShift: 4,
        riskContext: '지난 선택 영향으로 시장이 조금 흔들려요. 이번엔 비중을 나눠 안전하게 가요.',
      );
    }
    return const ChapterCondition(
      marketMood: MarketMood.balanced,
      volatilityShift: 1,
      riskContext: '시장 분위기는 보통이에요. 근거 1개를 더 확인하면 점수가 더 좋아져요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompactMobile = media.size.width <= 430 || media.size.height <= 820;
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
        padding: EdgeInsets.fromLTRB(16, isCompactMobile ? 10 : 16, 16, 16),
        child: Column(
          children: [
            if (!isCompactMobile) ...[
              _MascotMapHeader(
                state: state,
                total: scenarios.length,
                mascotEmoji: state.equippedCharacter.emoji,
                homeEmoji: state.equippedHome.emoji,
              ),
              const SizedBox(height: 8),
              _ChapterObjectiveBanner(
                chapter: chapter,
                objective: chapterObjective,
              ),
              const SizedBox(height: 10),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFFEFF6FF),
                ),
                child: Text(
                  '🧸 챕터 $chapter · $chapterObjective',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: _DifficultySelector(
                    current: state.selectedDifficulty,
                    onChanged: onDifficultyChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: state.soundMuted ? '효과음 켜기' : '효과음 끄기',
                  child: IconButton.filledTonal(
                    onPressed: () => onSoundMutedChanged(!state.soundMuted),
                    icon: Icon(
                      state.soundMuted ? Icons.volume_off : Icons.volume_up,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isCompactMobile || done) ...[
              _AdventureMapCard(
                state: state,
                totalScenarios: scenarios.length,
                compact: isCompactMobile,
                homeEmoji: state.equippedHome.emoji,
              ),
              const SizedBox(height: 10),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFEAF4FF),
                ),
                child: Text(
                  '🗺️ 집중 모드 · 챕터 ${state.currentScenario + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
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
                  learnerAgeBand: state.learnerAgeBand,
                  chapterCondition: _conditionForNextChapter(),
                  soundMuted: state.soundMuted,
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
  const _ChapterObjectiveBanner({
    required this.chapter,
    required this.objective,
  });

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
  const _MascotMapHeader({
    required this.state,
    required this.total,
    required this.mascotEmoji,
    required this.homeEmoji,
  });

  final AppState state;
  final int total;
  final String mascotEmoji;
  final String homeEmoji;

  @override
  Widget build(BuildContext context) {
    final chapter = state.currentScenario + 1 > total
        ? total
        : state.currentScenario + 1;
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
            child: Center(
              child: Text(mascotEmoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '챕터 $chapter 이동 중 · 자산 ${state.cash}코인\n$homeEmoji 베이스 · 탐험 포인트 ${state.rewardPoints}P',
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
                            color: current == d
                                ? Colors.white70
                                : Colors.black54,
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
  const _AdventureMapCard({
    required this.state,
    required this.totalScenarios,
    required this.homeEmoji,
    this.compact = false,
  });

  final AppState state;
  final int totalScenarios;
  final String homeEmoji;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final points = List.generate(totalScenarios, (i) {
      final x = (i % 5) / 4;
      final y = i < 5 ? 0.25 : 0.75;
      return Offset(i < 5 ? x : 1 - x, y);
    });

    return Container(
      height: compact ? 120 : 170,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF4FF), Color(0xFFF6EDFF)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: LayoutBuilder(
          builder: (context, c) {
            return Stack(
              children: [
                Positioned(
                  right: 4,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '베이스 $homeEmoji',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
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
  const _MapNode({
    required this.index,
    required this.state,
    required this.icon,
  });

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
    required this.learnerAgeBand,
    required this.chapterCondition,
    required this.soundMuted,
    required this.onDone,
  });

  final Scenario scenario;
  final int cash;
  final DifficultyLevel difficulty;
  final LearnerAgeBand learnerAgeBand;
  final ChapterCondition chapterCondition;
  final bool soundMuted;
  final ValueChanged<ScenarioResult> onDone;

  @override
  State<ScenarioPlayCard> createState() => _ScenarioPlayCardState();
}

class _ScenarioPlayCardState extends State<ScenarioPlayCard> {
  int? _selectedIndustry;
  int? _reasoningAnswer;
  int? _quizAnswer;
  bool? _oxAnswer;
  late QuizInteractionType _quizType;
  late bool _oxStatementIsTrue;
  late String _oxStatement;
  late List<int> _orderingIndices;
  late List<String> _matchPrompts;
  late List<String> _matchTargets;
  late List<int?> _matchAnswers;
  int? _allocationPercent;
  late List<ScenarioOption> _industryChoices;
  late List<ScenarioOption> _quizChoices;
  bool _submitted = false;
  bool _hintUnlocked = false;
  bool _hintUsed = false;
  int _wrongAttempts = 0;
  _PerformanceSnapshot? _resultSnapshot;
  ScenarioResult? _pendingResult;
  String _mascotSpeech = '뉴스 한 줄! 어디가 움직일까?';
  int _stage = 0;
  final AudioPlayer _sfxPlayer = AudioPlayer();

  static const List<String> _fallbackReasoningChoices = [
    '뉴스와 직접 연결된 산업 먼저 확인',
    '영향이 몇 주/몇 달 갈지 기간 확인',
    '수혜+피해를 함께 보고 분산 전략 세우기',
  ];
  static const List<String> _chapterObjectiveKeywords = [
    '기회비용',
    '분산투자',
    '리스크 관리',
  ];

  String get _chapterObjective =>
      _chapterObjectiveKeywords[(widget.scenario.id - 1) %
          _chapterObjectiveKeywords.length];

  String _bandPrompt(String base) {
    return switch (widget.learnerAgeBand) {
      LearnerAgeBand.younger => '쉽게: $base',
      LearnerAgeBand.middle => '생각: $base',
      LearnerAgeBand.older => '분석: $base',
    };
  }

  String _hintText(Scenario s) {
    return switch (widget.learnerAgeBand) {
      LearnerAgeBand.younger =>
        '힌트: 수혜 "${s.goodIndustries.first}" 👍 / 주의 "${s.badIndustries.first}" ⚠️',
      LearnerAgeBand.middle =>
        '힌트: 수혜 ${s.goodIndustries.join(', ')} · 주의 ${s.badIndustries.join(', ')}',
      LearnerAgeBand.older =>
        '힌트: 수혜 ${s.goodIndustries.join(', ')} / 역풍 ${s.badIndustries.join(', ')}',
    };
  }

  @override
  void initState() {
    super.initState();
    _prepareShuffledChoices();
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    super.dispose();
  }

  void _prepareShuffledChoices() {
    _industryChoices = [...widget.scenario.industryOptions]
      ..shuffle(Random(widget.scenario.id * 997 + DateTime.now().millisecond));
    _quizChoices = [...widget.scenario.quizOptions]
      ..shuffle(Random(widget.scenario.id * 991 + DateTime.now().microsecond));

    _quizType = QuizInteractionType
        .values[widget.scenario.id % QuizInteractionType.values.length];

    final bestOption = _quizChoices.reduce(
      (a, b) => a.score >= b.score ? a : b,
    );
    _oxStatementIsTrue = widget.scenario.id % 2 == 0;
    _oxStatement = _oxStatementIsTrue
        ? '${bestOption.label} 쪽이 이번 뉴스에서 더 유리해요.'
        : '${bestOption.label} 쪽이 이번 뉴스에서 더 불리해요.';

    _orderingIndices = List<int>.generate(_quizChoices.length, (i) => i);
    _matchPrompts = const ['수요가 늘기 쉬운 이슈', '주의가 필요한 이슈'];
    _matchTargets = [
      widget.scenario.goodIndustries.first,
      widget.scenario.badIndustries.first,
    ];
    _matchAnswers = [null, null];
  }

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

  bool get _isQuizAnswered {
    return switch (_quizType) {
      QuizInteractionType.multipleChoice => _quizAnswer != null,
      QuizInteractionType.ox => _oxAnswer != null,
      QuizInteractionType.ordering => true,
      QuizInteractionType.matching => _matchAnswers.every((e) => e != null),
    };
  }

  int _quizInteractionScore() {
    switch (_quizType) {
      case QuizInteractionType.multipleChoice:
        return _quizAnswer == null ? 0 : _quizChoices[_quizAnswer!].score;
      case QuizInteractionType.ox:
        if (_oxAnswer == null) return 0;
        return _oxAnswer == _oxStatementIsTrue ? 100 : 35;
      case QuizInteractionType.ordering:
        final expected = List<int>.generate(_quizChoices.length, (i) => i)
          ..sort(
            (a, b) => _quizChoices[b].score.compareTo(_quizChoices[a].score),
          );
        var matchCount = 0;
        for (var i = 0; i < _orderingIndices.length; i++) {
          if (_orderingIndices[i] == expected[i]) matchCount++;
        }
        if (matchCount == _quizChoices.length) return 100;
        if (matchCount == _quizChoices.length - 1) return 75;
        if (matchCount == 1) return 55;
        return 35;
      case QuizInteractionType.matching:
        var correct = 0;
        for (var i = 0; i < _matchAnswers.length; i++) {
          if (_matchAnswers[i] == i) correct++;
        }
        if (correct == _matchAnswers.length) return 100;
        if (correct == 1) return 60;
        return 30;
    }
  }

  String _quizTypeExplanation() {
    return switch (_quizType) {
      QuizInteractionType.multipleChoice => '객관식: 뉴스와 가장 맞는 선택지를 골랐어요.',
      QuizInteractionType.ox => 'OX: 문장이 맞는지 빠르게 검증했어요.',
      QuizInteractionType.ordering => '순서 배열: 영향이 큰 순서대로 정리했어요.',
      QuizInteractionType.matching => '매칭: 이슈와 산업을 짝지어 연결했어요.',
    };
  }

  Future<void> _playFeedbackSfx(bool isCorrect) async {
    if (widget.soundMuted) return;
    final path = isCorrect
        ? 'audio/correct_beep.wav'
        : 'audio/wrong_beep.wav';
    try {
      await _sfxPlayer.play(AssetSource(path));
    } catch (_) {}
  }

  Widget _stepProgress() {
    const labels = ['질문 1', '질문 2', '질문 3', '투자', '결과'];
    return Row(
      children: List.generate(labels.length, (i) {
        final done = i < _stage;
        final current = i == _stage;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: done || current
                  ? const Color(0xFFEAE8FF)
                  : const Color(0xFFF2F4F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              labels[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: current ? const Color(0xFF4A3FD1) : const Color(0xFF637091),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _confirmCurrentStep() async {
    if (_stage == 0) {
      if (_selectedIndustry == null) return;
      final ok = _industryChoices[_selectedIndustry!].score >= 70;
      await _playFeedbackSfx(ok);
      if (!mounted) return;
      setState(() {
        _stage = 1;
        _mascotSpeech = ok ? '정확해! 이제 이유를 골라보자.' : '괜찮아! 이유를 고르며 다시 정리해보자.';
      });
      return;
    }
    if (_stage == 1) {
      if (_reasoningAnswer == null) return;
      final ok = _reasoningScore() >= 75;
      await _playFeedbackSfx(ok);
      if (!mounted) return;
      setState(() {
        _stage = 2;
        _mascotSpeech = ok ? '좋아! 마지막 질문 카드야.' : '좋은 시도야! 질문 카드에서 만회해보자.';
      });
      return;
    }
    if (_stage == 2) {
      if (!_isQuizAnswered) return;
      final ok = _quizInteractionScore() >= 70;
      await _playFeedbackSfx(ok);
      if (!mounted) return;
      setState(() {
        _stage = 3;
        _mascotSpeech = ok ? '굿! 이제 투자 비중을 정해보자.' : '좋아! 이제 투자 비중으로 균형을 맞춰보자.';
      });
    }
  }

  int get _investedCoins {
    final a = _allocation;
    if (a == null) return 0;
    return (widget.cash * (a / 100)).round().clamp(0, widget.cash);
  }

  ({
    int returnPercent,
    int rawProfit,
    int adjustedProfit,
    int volatilityRisk,
    String formulaLine,
    String coachingLine,
  })
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
    final moodVolatility = widget.chapterCondition.volatilityShift;
    final allocation = _allocation ?? 0;
    final volatilitySeed = (widget.scenario.id * 7 + allocation) % 6;
    final directionalVolatility = volatilitySeed - 2;
    final volatilityEffect =
        directionalVolatility * (baseVolatility + moodVolatility);

    var returnPercent = isGoodDecision
        ? 6 + qualityEdge + stabilityAdj + volatilityEffect
        : -6 - qualityEdge.abs() - stabilityAdj.abs() + volatilityEffect;

    if (widget.difficulty == DifficultyLevel.hard &&
        !isGoodDecision &&
        allocation >= 60) {
      returnPercent -= ((allocation - 50) / 4).round();
    }

    // 교육 UX: '좋은 선택'이면 최소 0% 이상은 보장해 혼란을 줄인다.
    if (isGoodDecision && returnPercent < 0) {
      returnPercent = 0;
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
      DifficultyLevel.easy =>
        adjustedProfit < 0
            ? '좋아요! 쉬움 모드 손실 완충이 적용됐어요. 다음엔 비중을 40~60%로 맞춰보세요.'
            : '좋아요! 다음에도 한 번에 올인하지 않고 비중을 나눠서 수익을 지켜봐요.',
      DifficultyLevel.normal =>
        adjustedProfit < 0
            ? '다음 행동: 근거가 약하면 비중을 줄여 손실 폭을 먼저 관리해요.'
            : '다음 행동: 근거가 강할 때만 비중을 조금씩 늘려보세요.',
      DifficultyLevel.hard =>
        adjustedProfit < 0
            ? '하드 모드 경고: 높은 비중 실수는 손실이 커져요. 다음엔 20~50%부터 검증해요.'
            : '하드 모드 팁: 승률이 높아도 비중 분할로 변동성 충격을 줄여요.',
    };

    final volatilityRisk =
        (100 - riskManagementScore + (baseVolatility + moodVolatility) * 2)
            .clamp(0, 100);
    return (
      returnPercent: returnPercent,
      rawProfit: rawProfit,
      adjustedProfit: adjustedProfit,
      volatilityRisk: volatilityRisk,
      formulaLine: formulaLine,
      coachingLine: coachingLine,
    );
  }

  _ScenarioFeedback _buildScenarioFeedback({
    required int industryScore,
    required int reasoningScore,
    required int allocationPercent,
  }) {
    final explanation = widget.scenario.explanation;
    final selectedIndustryLabel = _selectedIndustry == null
        ? '산업 카드'
        : _industryChoices[_selectedIndustry!].label;
    final selectedReasoningLabel = _reasoningAnswer == null
        ? '근거 선택'
        : _reasoningChoices[_reasoningAnswer!];

    final goodPoint = switch (widget.learnerAgeBand) {
      LearnerAgeBand.younger =>
        industryScore >= 70
            ? '${explanation.short} 네가 고른 "$selectedIndustryLabel"은 뉴스랑 잘 맞았어!'
            : '좋은 점: "$selectedReasoningLabel"처럼 이유를 직접 골라 생각했어.',
      LearnerAgeBand.middle =>
        industryScore >= 70
            ? '${explanation.short} "$selectedIndustryLabel" 선택의 근거 연결이 좋아요.'
            : '좋은 점: "$selectedReasoningLabel"처럼 근거 기반 선택을 시도했어요.',
      LearnerAgeBand.older =>
        industryScore >= 70
            ? '${explanation.short} "$selectedIndustryLabel" 선택은 뉴스-산업 인과 연결이 타당해요.'
            : '좋은 점: "$selectedReasoningLabel"으로 가설을 세우고 판단한 접근이 좋아요.',
    };

    final weakPoint = switch (widget.learnerAgeBand) {
      LearnerAgeBand.younger =>
        reasoningScore >= 75
            ? '${explanation.risk} 비중 $allocationPercent%는 너무 크면 흔들릴 수 있어요.'
            : '${explanation.why} 지금 선택에 "진짜 데이터 1개"를 더해봐요.',
      LearnerAgeBand.middle =>
        reasoningScore >= 75
            ? '${explanation.risk} 비중 $allocationPercent%는 변동 구간에서 손익 폭이 커질 수 있어요.'
            : '${explanation.why} "$selectedReasoningLabel"에 확인 데이터 한 줄을 추가해요.',
      LearnerAgeBand.older =>
        reasoningScore >= 75
            ? '${explanation.risk} 현재 비중 $allocationPercent%는 변동성 대비 포지션 관리가 필요해요.'
            : '${explanation.why} "$selectedReasoningLabel"에 선행지표/지속기간 근거를 보강해요.',
    };

    final nextAction = allocationPercent >= 65
        ? '${explanation.takeaway} 다음 챕터는 40~55%로 시작해 비교해보자.'
        : '${explanation.takeaway} 다음 챕터는 근거를 1줄 적고 ${allocationPercent + 5 > 60 ? 60 : allocationPercent + 5}% 이내에서 테스트해보자.';

    return _ScenarioFeedback(
      goodPoint: goodPoint,
      weakPoint: weakPoint,
      nextAction: nextAction,
    );
  }

  void _submit() {
    if (_selectedIndustry == null ||
        !_isQuizAnswered ||
        _reasoningAnswer == null ||
        _allocation == null ||
        _submitted) {
      return;
    }

    final industryScore = _industryChoices[_selectedIndustry!].score;
    final quizScore = _quizInteractionScore();
    final reasonScore = _reasoningScore();
    final judgementScore =
        ((industryScore * 0.45) + (quizScore * 0.35) + (reasonScore * 0.20))
            .round();

    if (judgementScore < 55 && _wrongAttempts == 0) {
      setState(() {
        _wrongAttempts = 1;
        _hintUnlocked = true;
        _mascotSpeech = '좋은 시도! 힌트 열렸어. 한 번 더 해보자!';
        _resultSnapshot = null;
      });
      return;
    }

    final riskManagementScore = _riskScore();
    final emotionControlScore = _emotionScore(judgementScore);
    final learningScore =
        ((judgementScore + riskManagementScore + emotionControlScore) / 3)
            .round();
    final scenarioFeedback = _buildScenarioFeedback(
      industryScore: industryScore,
      reasoningScore: reasonScore,
      allocationPercent: _allocation!,
    );

    final invested = _investedCoins;
    final outcome = _calculateInvestmentOutcome(
      invested: invested,
      judgementScore: judgementScore,
      riskManagementScore: riskManagementScore,
    );

    final hintPenalty = _hintUsed ? widget.difficulty.hintPenalty : 0;
    final finalProfit = outcome.adjustedProfit - hintPenalty;

    final result = ScenarioResult(
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
      allocationPercent: _allocation!,
    );

    setState(() {
      _submitted = true;
      _stage = 4;
      _mascotSpeech = learningScore >= 80
          ? '멋져! 근거와 비중 둘 다 좋았어!'
          : '좋아! 다음은 비중만 조금 더 다듬자.';
      _resultSnapshot = _PerformanceSnapshot(
        scenarioTitle: widget.scenario.title,
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
        chapterConditionLine: widget.chapterCondition.summary(
          widget.learnerAgeBand,
        ),
        quizTypeLabel: _quizType.label,
        quizTypeExplanation: _quizTypeExplanation(),
        goodPoint: scenarioFeedback.goodPoint,
        weakPoint: scenarioFeedback.weakPoint,
        nextAction: scenarioFeedback.nextAction,
      );
      _pendingResult = result;
    });
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
              color: selected
                  ? const Color(0xFF6C63FF)
                  : const Color(0xFF9DA6BC),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quizInteractionWidget(Scenario s) {
    final title = '3) ${_quizType.label}';
    if (_quizType == QuizInteractionType.multipleChoice) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _bandPrompt('$title · ${s.quizQuestion}'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          ...List.generate(
            _quizChoices.length,
            (i) => _choiceTile(
              text: _quizChoices[i].label,
              selected: _quizAnswer == i,
              onTap: _submitted
                  ? null
                  : () => setState(() {
                      _quizAnswer = i;
                      _mascotSpeech = '좋아! 이제 마지막으로 투자 비중을 선택해보자.';
                    }),
            ),
          ),
        ],
      );
    }

    if (_quizType == QuizInteractionType.ox) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _bandPrompt('$title · 문장이 맞으면 O, 아니면 X!'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            _oxStatement,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('⭕ O'),
                selected: _oxAnswer == true,
                onSelected: _submitted
                    ? null
                    : (_) => setState(() => _oxAnswer = true),
              ),
              ChoiceChip(
                label: const Text('❌ X'),
                selected: _oxAnswer == false,
                onSelected: _submitted
                    ? null
                    : (_) => setState(() => _oxAnswer = false),
              ),
            ],
          ),
        ],
      );
    }

    if (_quizType == QuizInteractionType.ordering) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _bandPrompt('$title · 영향이 큰 순서로 위에서 아래로 정렬해요.'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...List.generate(_orderingIndices.length, (position) {
            final optionIndex = _orderingIndices[position];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '${position + 1}위',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_quizChoices[optionIndex].label)),
                  IconButton(
                    onPressed: _submitted || position == 0
                        ? null
                        : () => setState(() {
                            final temp = _orderingIndices[position - 1];
                            _orderingIndices[position - 1] =
                                _orderingIndices[position];
                            _orderingIndices[position] = temp;
                          }),
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    onPressed:
                        _submitted || position == _orderingIndices.length - 1
                        ? null
                        : () => setState(() {
                            final temp = _orderingIndices[position + 1];
                            _orderingIndices[position + 1] =
                                _orderingIndices[position];
                            _orderingIndices[position] = temp;
                          }),
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _bandPrompt('$title · 이슈와 산업을 연결해요.'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...List.generate(_matchPrompts.length, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _matchPrompts[i],
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: List.generate(_matchTargets.length, (targetIndex) {
                    return ChoiceChip(
                      label: Text(_matchTargets[targetIndex]),
                      selected: _matchAnswers[i] == targetIndex,
                      onSelected: _submitted
                          ? null
                          : (_) =>
                                setState(() => _matchAnswers[i] = targetIndex),
                    );
                  }),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scenario;
    final mobileSafeBottom = MediaQuery.of(context).viewPadding.bottom;

    Widget stepCard;
    if (_stage == 0) {
      stepCard = _gameSection(
        title: '질문 카드 1 · 어떤 산업이 움직일까?',
        child: Column(
          children: [
            ...List.generate(
              _industryChoices.length,
              (i) => _choiceTile(
                text: _industryChoices[i].label,
                selected: _selectedIndustry == i,
                onTap: _submitted ? null : () => setState(() => _selectedIndustry = i),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _selectedIndustry == null || _submitted ? null : _confirmCurrentStep,
              child: const Text('선택 확인하고 다음'),
            ),
          ],
        ),
      );
    } else if (_stage == 1) {
      stepCard = _gameSection(
        title: '질문 카드 2 · 이유를 골라봐!',
        child: Column(
          children: [
            ...List.generate(
              _reasoningChoices.length,
              (i) => _choiceTile(
                text: _reasoningChoices[i],
                selected: _reasoningAnswer == i,
                onTap: _submitted ? null : () => setState(() => _reasoningAnswer = i),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _reasoningAnswer == null || _submitted ? null : _confirmCurrentStep,
              child: const Text('선택 확인하고 다음'),
            ),
          ],
        ),
      );
    } else if (_stage == 2) {
      stepCard = _gameSection(
        title: '질문 카드 3 · 마지막 퀴즈!',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _quizInteractionWidget(s),
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
                child: Text(_hintText(s)),
              ),
            FilledButton(
              onPressed: !_isQuizAnswered || _submitted ? null : _confirmCurrentStep,
              child: const Text('선택 확인하고 다음'),
            ),
          ],
        ),
      );
    } else if (_stage == 3) {
      stepCard = _gameSection(
        title: '투자 카드 · 비중을 선택해요',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('높을수록 많이 오르고, 많이 내려요.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [20, 30, 40, 50, 60, 70, 80].map((v) {
                final selected = _allocation == v;
                return ChoiceChip(
                  label: Text('$v%'),
                  selected: selected,
                  onSelected: _submitted ? null : (_) => setState(() => _allocationPercent = v),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_allocation == null ? '비중을 골라주세요.' : '투자금 $_investedCoins코인'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: (_submitted || _allocation == null) ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              icon: const Icon(Icons.check_circle),
              label: Text(_wrongAttempts == 0 ? '점수 확인' : '재도전 완료'),
            ),
          ],
        ),
      );
    } else {
      stepCard = _gameSection(
        title: '결과 카드',
        child: Column(
          children: [
            if (_resultSnapshot != null) _PerformanceResultCard(snapshot: _resultSnapshot!),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _pendingResult == null ? null : () {
                final next = _pendingResult;
                if (next != null) widget.onDone(next);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF1F8D48),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('다음 챕터로 이동'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: mobileSafeBottom + 120),
      children: [
        _bubbleCard(_mascotSpeech),
        const SizedBox(height: 10),
        _stepProgress(),
        const SizedBox(height: 10),
        _newsCard(s),
        const SizedBox(height: 10),
        stepCard,
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
            child: const Center(
              child: Text('🧸', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                speech,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _newsCard(Scenario s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🗺️ 챕터 ${s.id}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            s.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(
                '🎯 $_chapterObjective',
                const Color(0xFFEFF3FF),
                const Color(0xFF3D4E91),
              ),
              _tag(
                widget.chapterCondition.summary(widget.learnerAgeBand),
                const Color(0xFFE8F7FF),
                const Color(0xFF245E7A),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.news),
          const SizedBox(height: 8),
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
              '💡 스스로 수혜/주의 산업을 찾아보자!',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF4E5B7A),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gameSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
      ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _ScenarioFeedback {
  const _ScenarioFeedback({
    required this.goodPoint,
    required this.weakPoint,
    required this.nextAction,
  });

  final String goodPoint;
  final String weakPoint;
  final String nextAction;
}

class _PerformanceSnapshot {
  const _PerformanceSnapshot({
    required this.scenarioTitle,
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
    required this.chapterConditionLine,
    required this.quizTypeLabel,
    required this.quizTypeExplanation,
    required this.goodPoint,
    required this.weakPoint,
    required this.nextAction,
  });

  final String scenarioTitle;
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
  final String chapterConditionLine;
  final String quizTypeLabel;
  final String quizTypeExplanation;
  final String goodPoint;
  final String weakPoint;
  final String nextAction;
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
          Text(
            '📈 ${snapshot.scenarioTitle} 결과',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
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
          Text(
            '다음 챕터: ${snapshot.chapterConditionLine}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '비중 ${snapshot.allocationPercent}% · 투자금 ${snapshot.invested}코인',
          ),
          if (snapshot.hintPenalty > 0)
            Text(
              '힌트 -${snapshot.hintPenalty}코인',
              style: const TextStyle(fontSize: 12),
            ),
          Text(
            '최종 ${snapshot.finalProfit >= 0 ? '+' : ''}${snapshot.finalProfit}코인',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '질문 타입: ${snapshot.quizTypeLabel} · ${snapshot.quizTypeExplanation}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            '코칭: ${snapshot.nextAction}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            '한 줄 요약: $_overallComment',
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

class _HomeThemePreset {
  const _HomeThemePreset({
    required this.wallGradient,
    required this.floorGradient,
    required this.accent,
    required this.atmosphere,
    required this.name,
  });

  final List<Color> wallGradient;
  final List<Color> floorGradient;
  final Color accent;
  final String atmosphere;
  final String name;

  static _HomeThemePreset fromHomeId(String homeId) {
    return switch (homeId) {
      'home_forest' => const _HomeThemePreset(
        wallGradient: [Color(0xFFDEF5D9), Color(0xFFBDE6AE)],
        floorGradient: [Color(0xFF8A5F3B), Color(0xFF6D472C)],
        accent: Color(0xFF2F8B57),
        atmosphere: '🌲',
        name: 'Forest',
      ),
      'home_city' => const _HomeThemePreset(
        wallGradient: [Color(0xFFDDE8FF), Color(0xFFB6C8F2)],
        floorGradient: [Color(0xFF737C97), Color(0xFF4D556B)],
        accent: Color(0xFF35436E),
        atmosphere: '🏙️',
        name: 'City',
      ),
      'home_space' => const _HomeThemePreset(
        wallGradient: [Color(0xFF221642), Color(0xFF402E7A)],
        floorGradient: [Color(0xFF3B3461), Color(0xFF241E45)],
        accent: Color(0xFF8EA4FF),
        atmosphere: '✨',
        name: 'Space',
      ),
      'home_ocean' => const _HomeThemePreset(
        wallGradient: [Color(0xFFD2F6FF), Color(0xFF9FE8FF)],
        floorGradient: [Color(0xFF4BB8C5), Color(0xFF2D8E9A)],
        accent: Color(0xFF0E6C8A),
        atmosphere: '🌊',
        name: 'Ocean',
      ),
      _ => const _HomeThemePreset(
        wallGradient: [Color(0xFFF3F6FF), Color(0xFFDCE6FF)],
        floorGradient: [Color(0xFFF4DDBA), Color(0xFFDAAF75)],
        accent: Color(0xFF5A6DA5),
        atmosphere: '🏕️',
        name: 'Basic',
      ),
    };
  }
}

class _MyHomeTab extends StatefulWidget {
  const _MyHomeTab({
    required this.state,
    required this.syncMessage,
    required this.session,
    required this.onPlaceDecoration,
  });

  final AppState state;
  final String? syncMessage;
  final StoredSession? session;
  final void Function(DecorationZone zone, String? itemId) onPlaceDecoration;

  @override
  State<_MyHomeTab> createState() => _MyHomeTabState();
}

class _MyHomeTabState extends State<_MyHomeTab> {
  bool _showEquipFx = false;
  String _equipFxLabel = '장착 완료!';

  ShopItem? _itemById(String? id) {
    if (id == null) return null;
    for (final item in kShopItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant _MyHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.equippedHomeId != widget.state.equippedHomeId) {
      _triggerEquipFx('테마 변경!');
      return;
    }
    if (oldWidget.state.equippedCharacterId !=
        widget.state.equippedCharacterId) {
      _triggerEquipFx('캐릭터 장착!');
      return;
    }
    for (final zone in DecorationZone.values) {
      if (oldWidget.state.equippedDecorations[zone] !=
          widget.state.equippedDecorations[zone]) {
        _triggerEquipFx('${zone.label} 적용!');
        return;
      }
    }
  }

  void _triggerEquipFx(String label) {
    setState(() {
      _equipFxLabel = label;
      _showEquipFx = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _showEquipFx = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final solved = state.solvedCount;
    final level = 1 + (state.rewardPoints + state.totalPointsSpent) ~/ 250;
    final chapterProgress = ((state.currentScenario / 10) * 100)
        .clamp(0, 100)
        .round();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            color: const Color(0xFFEFF6FF),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🏠 사이월드 감성 마이홈',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('계정: ${widget.session?.email ?? '게스트'}'),
                  Text('동기화 상태: ${widget.syncMessage ?? '로컬 저장 중'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MyHomeRoomCard(
            state: state,
            itemById: _itemById,
            showEquipFx: _showEquipFx,
            equipFxLabel: _equipFxLabel,
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🪄 슬롯 꾸미기',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  ...DecorationZone.values.map((zone) {
                    final ownedItems = kShopItems
                        .where(
                          (item) =>
                              item.type == CosmeticType.decoration &&
                              item.zone == zone &&
                              state.ownedItemIds.contains(item.id),
                        )
                        .toList();
                    final selected = state.equippedDecorations[zone];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SlotPreviewChip(
                                title: '비우기',
                                selected: selected == null,
                                onTap: () =>
                                    widget.onPlaceDecoration(zone, null),
                              ),
                              ...ownedItems.map(
                                (item) => _SlotPreviewChip(
                                  title: item.name,
                                  selected: selected == item.id,
                                  onTap: () =>
                                      widget.onPlaceDecoration(zone, item.id),
                                  child: _ItemThumbnail(
                                    item: item,
                                    compact: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (ownedItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                '아직 이 슬롯 아이템이 없어요. 상점에서 구매해보세요!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '핵심 프로필 진행',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('레벨: Lv.$level'),
                  Text(
                    '챕터 진행: ${state.currentScenario} / 10 ($chapterProgress%)',
                  ),
                  Text('탐험 포인트: ${state.rewardPoints}P · 완료 시나리오: $solved개'),
                  Text('연속 기록 최고: ${state.bestStreak}회'),
                  Text(
                    '보유 자산: ${state.cash}코인 · 누적 손익 ${state.totalProfit >= 0 ? '+' : ''}${state.totalProfit}코인',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyHomeRoomCard extends StatelessWidget {
  const _MyHomeRoomCard({
    required this.state,
    required this.itemById,
    required this.showEquipFx,
    required this.equipFxLabel,
  });

  final AppState state;
  final ShopItem? Function(String? id) itemById;
  final bool showEquipFx;
  final String equipFxLabel;

  @override
  Widget build(BuildContext context) {
    final theme = _HomeThemePreset.fromHomeId(state.equippedHomeId);
    final wallItem = itemById(state.equippedDecorations[DecorationZone.wall]);
    final floorItem = itemById(state.equippedDecorations[DecorationZone.floor]);
    final deskItem = itemById(state.equippedDecorations[DecorationZone.desk]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎨 마이홈 룸 · ${theme.atmosphere} ${theme.name} 프리셋',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 1.45,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: theme.wallGradient,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(child: _ThemeAtmosphereLayer(theme: theme)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 92,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: theme.floorGradient,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    if (wallItem != null)
                      Positioned(
                        left: 18,
                        top: 16,
                        right: 18,
                        height: 68,
                        child: _DecorationObject(item: wallItem),
                      ),
                    if (floorItem != null)
                      Positioned(
                        left: 14,
                        bottom: 20,
                        width: 112,
                        height: 56,
                        child: _DecorationObject(item: floorItem),
                      ),
                    Positioned(
                      right: 12,
                      bottom: 72,
                      width: 92,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (deskItem != null)
                      Positioned(
                        right: 16,
                        bottom: 74,
                        width: 86,
                        height: 48,
                        child: _DecorationObject(item: deskItem),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.accent.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.equippedCharacter.emoji,
                                style: const TextStyle(fontSize: 40),
                              ),
                              Text(
                                state.equippedCharacter.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: showEquipFx ? 1 : 0,
                      child: Center(
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 260),
                          scale: showEquipFx ? 1 : 0.7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFCE1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFFFE083),
                              ),
                            ),
                            child: Text(
                              '✨ $equipFxLabel',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '현재 홈 테마: ${state.equippedHome.emoji} ${state.equippedHome.name}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeAtmosphereLayer extends StatelessWidget {
  const _ThemeAtmosphereLayer({required this.theme});

  final _HomeThemePreset theme;

  @override
  Widget build(BuildContext context) {
    if (theme.name == 'Forest') {
      return Stack(
        children: const [
          Positioned(
            left: 10,
            bottom: 84,
            child: Text('🌲', style: TextStyle(fontSize: 26)),
          ),
          Positioned(
            left: 44,
            bottom: 88,
            child: Text('🌿', style: TextStyle(fontSize: 20)),
          ),
          Positioned(
            right: 18,
            bottom: 86,
            child: Text('🌲', style: TextStyle(fontSize: 24)),
          ),
        ],
      );
    }
    if (theme.name == 'City') {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 84,
          margin: const EdgeInsets.only(bottom: 92),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, theme.accent.withValues(alpha: 0.2)],
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('🏢', style: TextStyle(fontSize: 18)),
              Text('🏬', style: TextStyle(fontSize: 18)),
              Text('🏙️', style: TextStyle(fontSize: 20)),
              Text('🏢', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }
    if (theme.name == 'Space') {
      return Stack(
        children: const [
          Positioned(
            left: 18,
            top: 18,
            child: Text('⭐', style: TextStyle(fontSize: 14)),
          ),
          Positioned(
            right: 24,
            top: 28,
            child: Text('✨', style: TextStyle(fontSize: 16)),
          ),
          Positioned(
            left: 70,
            top: 40,
            child: Text('🪐', style: TextStyle(fontSize: 20)),
          ),
          Positioned(
            right: 62,
            top: 60,
            child: Text('🌌', style: TextStyle(fontSize: 16)),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _DecorationObject extends StatelessWidget {
  const _DecorationObject({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (item.id == 'deco_wall_chart')
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      height: 5,
                      width: 50,
                      color: const Color(0xFF9AB4FF),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 5,
                      width: 70,
                      color: const Color(0xFF76D39B),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 5,
                      width: 34,
                      color: const Color(0xFFFFB36B),
                    ),
                  ],
                ),
              ),
            )
          else
            Center(
              child: Text(item.emoji, style: const TextStyle(fontSize: 28)),
            ),
          Positioned(
            bottom: 4,
            right: 6,
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemThumbnail extends StatelessWidget {
  const _ItemThumbnail({required this.item, this.compact = false});

  final ShopItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 46.0 : 58.0;
    final isHome = item.type == CosmeticType.home;
    final isDeco = item.type == CosmeticType.decoration;
    final bg = isHome
        ? _HomeThemePreset.fromHomeId(item.id).wallGradient.first
        : isDeco
        ? const Color(0xFFF2F4FA)
        : const Color(0xFFFFF3DD);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
      ),
      child: Center(
        child: Text(item.emoji, style: TextStyle(fontSize: compact ? 22 : 30)),
      ),
    );
  }
}

class _SlotPreviewChip extends StatelessWidget {
  const _SlotPreviewChip({
    required this.title,
    required this.selected,
    required this.onTap,
    this.child,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAEFFF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : const Color(0xFFDCE0EA),
          ),
        ),
        child: Column(
          children: [
            child ??
                const SizedBox(
                  width: 46,
                  height: 46,
                  child: Center(child: Icon(Icons.clear, size: 18)),
                ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopTab extends StatelessWidget {
  const _ShopTab({required this.state, required this.onBuyOrEquip});

  final AppState state;
  final ValueChanged<ShopItem> onBuyOrEquip;

  @override
  Widget build(BuildContext context) {
    final characters = kShopItems
        .where((item) => item.type == CosmeticType.character)
        .toList();
    final homes = kShopItems
        .where((item) => item.type == CosmeticType.home)
        .toList();
    final decorations = kShopItems
        .where((item) => item.type == CosmeticType.decoration)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            color: const Color(0xFFEFF6FF),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🛍️ 포인트 상점',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '현재 포인트: ${state.rewardPoints}P · 누적 사용: ${state.totalPointsSpent}P',
                  ),
                  Text(
                    '장착 중: ${state.equippedCharacter.emoji} ${state.equippedCharacter.name} / ${state.equippedHome.emoji} ${state.equippedHome.name}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _shopSection('캐릭터 꾸미기', characters),
          const SizedBox(height: 8),
          _shopSection('베이스 꾸미기', homes),
          const SizedBox(height: 8),
          _shopSection('마이홈 소품', decorations),
        ],
      ),
    );
  }

  Widget _shopSection(String title, List<ShopItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...items.map((item) {
              final owned = state.ownedItemIds.contains(item.id);
              final equipped = switch (item.type) {
                CosmeticType.character => state.equippedCharacterId == item.id,
                CosmeticType.home => state.equippedHomeId == item.id,
                CosmeticType.decoration =>
                  item.zone != null &&
                      state.equippedDecorations[item.zone!] == item.id,
              };

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: equipped
                      ? const Color(0xFFE8F8EE)
                      : const Color(0xFFF7F8FC),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ItemThumbnail(item: item),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.name}${item.zone == null ? '' : ' (${item.zone!.label})'} · ${item.price}P',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            item.description,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: equipped ? null : () => onBuyOrEquip(item),
                      child: Text(
                        equipped
                            ? '장착중'
                            : owned
                            ? '장착'
                            : '구매',
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _WeeklyReportTab extends StatelessWidget {
  const _WeeklyReportTab({required this.state});

  final AppState state;

  String _decisionInterpretation({
    required int judgement,
    required int risk,
    required int emotion,
  }) {
    final quality = ((judgement + risk + emotion) / 3).round();
    if (quality >= 82) {
      return '의사결정 품질이 매우 좋아요. 근거 확인 → 비중 조절 → 감정 통제가 안정적으로 이어졌어요.';
    }
    if (quality >= 65) {
      return '의사결정 품질이 성장 구간이에요. 방향은 맞고, 비중 조절 일관성만 더해지면 점프할 수 있어요.';
    }
    return '의사결정 품질이 기초 다지기 단계예요. 뉴스 근거를 1개 더 확인하고 작은 비중부터 시작하면 좋아요.';
  }

  List<String> _nextWeekActions({
    required int judgement,
    required int risk,
    required int emotion,
  }) {
    final actions = <String>[];
    if (judgement < 70) {
      actions.add('매 챕터 시작 전 "수혜 1개·피해 1개"를 먼저 말해보기');
    }
    if (risk < 72) {
      actions.add('다음 주는 첫 진입 비중을 40~55%로 제한하고 결과 비교하기');
    }
    if (emotion < 70) {
      actions.add('틀려도 10초 멈춤 후 근거 1줄 다시 읽고 선택하기');
    }
    if (actions.isEmpty) {
      actions.add('좋은 습관 유지: 근거를 확인한 뒤 비중을 5%씩만 조절해보기');
    }
    return actions.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chunks = <List<ScenarioResult>>[];
    for (var i = 0; i < state.results.length; i += 5) {
      chunks.add(state.results.sublist(i, min(i + 5, state.results.length)));
    }
    final totalEarnedPoints = state.rewardPoints + state.totalPointsSpent;
    final spendingRatio = totalEarnedPoints == 0
        ? 0.0
        : (state.totalPointsSpent / totalEarnedPoints) * 100;
    final savingRatio = 100 - spendingRatio;

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
                  const Text(
                    '📊 성장 리포트 (핵심 KPI)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '학습자 프로필: ${state.learnerAgeBand.label} (${state.learnerAgeBand.learningStyle})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _kpiTile('판단 정확도', state.avgJudgementScore, Icons.gps_fixed),
                  const SizedBox(height: 8),
                  _kpiTile(
                    '리스크 관리 점수',
                    state.avgRiskManagementScore,
                    Icons.shield,
                  ),
                  const SizedBox(height: 8),
                  _kpiTile(
                    '감정 통제 점수',
                    state.avgEmotionControlScore,
                    Icons.self_improvement,
                  ),
                  const Divider(height: 24),
                  Text('평균 수익률: ${state.avgReturn.toStringAsFixed(1)}%'),
                  Text(
                    '누적 손익: ${state.totalProfit >= 0 ? '+' : ''}${state.totalProfit}코인',
                  ),
                  Text('힌트 사용: ${state.hintUsedCount}회'),
                  Text('현재 자산: ${state.cash}코인'),
                  Text(
                    '탐험 포인트: ${state.rewardPoints}P (누적 획득 ${totalEarnedPoints}P)',
                  ),
                  Text(
                    '포인트 소비/저축 비율: ${spendingRatio.toStringAsFixed(1)}% / ${savingRatio.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '👨‍👩‍👧 부모 해석',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _decisionInterpretation(
                      judgement: state.avgJudgementScore,
                      risk: state.avgRiskManagementScore,
                      emotion: state.avgEmotionControlScore,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ..._nextWeekActions(
                    judgement: state.avgJudgementScore,
                    risk: state.avgRiskManagementScore,
                    emotion: state.avgEmotionControlScore,
                  ).map(
                    (action) => Text(
                      '• 다음 주 액션: $action',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...chunks.asMap().entries.map((entry) {
            final week = entry.key + 1;
            final list = entry.value;
            final profit = list.fold<int>(0, (sum, e) => sum + e.profit);
            final judge =
                (list.fold<int>(0, (sum, e) => sum + e.judgementScore) /
                        list.length)
                    .round();
            final risk =
                (list.fold<int>(0, (sum, e) => sum + e.riskManagementScore) /
                        list.length)
                    .round();
            final emotion =
                (list.fold<int>(0, (sum, e) => sum + e.emotionControlScore) /
                        list.length)
                    .round();

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
                    const SizedBox(height: 6),
                    Text(
                      '의사결정 해석: ${_decisionInterpretation(judgement: judge, risk: risk, emotion: emotion)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._nextWeekActions(
                      judgement: judge,
                      risk: risk,
                      emotion: emotion,
                    ).map(
                      (action) => Text(
                        '• 다음 주 액션: $action',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '$score점',
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _AuthCard extends StatefulWidget {
  const _AuthCard({
    required this.authService,
    required this.onSessionChanged,
    required this.isSyncing,
    this.session,
  });

  final AuthSyncService authService;
  final Future<void> Function(StoredSession?) onSessionChanged;
  final bool isSyncing;
  final StoredSession? session;

  @override
  State<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<_AuthCard> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _validEmail => RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  ).hasMatch(_emailController.text.trim());

  Future<void> _auth(bool signup) async {
    if (!_validEmail || _passwordController.text.length < 8) {
      setState(() => _message = '이메일 형식과 8자 이상 비밀번호를 확인해 주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final session = signup
          ? await widget.authService.signup(
              email: _emailController.text,
              password: _passwordController.text,
            )
          : await widget.authService.login(
              email: _emailController.text,
              password: _passwordController.text,
            );
      await widget.onSessionChanged(
        StoredSession(
          userId: session.userId,
          email: session.email,
          token: session.token,
        ),
      );
      if (mounted) {
        setState(() => _message = signup ? '회원가입 완료!' : '로그인 성공!');
      }
    } catch (e) {
      if (mounted) setState(() => _message = '인증 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('계정/동기화', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (session != null) ...[
              Text('로그인 계정: ${session.email}'),
              const SizedBox(height: 6),
              FilledButton.tonal(
                onPressed: () => widget.onSessionChanged(null),
                child: const Text('로그아웃 (로컬 모드)'),
              ),
            ] else ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: '이메일(ID)'),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호 (8자 이상)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _loading ? null : () => _auth(true),
                      child: const Text('회원가입'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : () => _auth(false),
                      child: const Text('로그인'),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.isSyncing || _loading) const LinearProgressIndicator(),
            if (_message != null) ...[
              const SizedBox(height: 6),
              Text(_message!, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideTab extends StatelessWidget {
  const _GuideTab({
    required this.state,
    required this.onReset,
    required this.onAgeBandChanged,
    required this.authService,
    required this.onSessionChanged,
    required this.isSyncing,
    this.session,
  });

  final AppState state;
  final VoidCallback onReset;
  final ValueChanged<LearnerAgeBand> onAgeBandChanged;
  final AuthSyncService authService;
  final Future<void> Function(StoredSession?) onSessionChanged;
  final bool isSyncing;
  final StoredSession? session;

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
          _AuthCard(
            authService: authService,
            session: session,
            onSessionChanged: onSessionChanged,
            isSyncing: isSyncing,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '부모 설정 · 학습자 연령대',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '현재: ${state.learnerAgeBand.label} (${state.learnerAgeBand.learningStyle})',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: LearnerAgeBand.values.map((band) {
                      return ChoiceChip(
                        label: Text(band.label),
                        selected: state.learnerAgeBand == band,
                        onSelected: (_) => onAgeBandChanged(band),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '연령대를 바꾸면 질문 표현/힌트 깊이/기본 난이도가 함께 조정됩니다.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
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
                  const Text(
                    '진행 초기화',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: onReset,
                    child: const Text('처음부터 다시 탐험하기'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
