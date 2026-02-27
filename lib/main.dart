import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/auth_sync_service.dart';
import 'data/scenario_repository.dart';
import 'models/scenario.dart';
import 'miniroom_coordinate_mapper.dart';

const kAppUiVersion = 'ui-2026.02.27-r61';

const _kSeoulOffset = Duration(hours: 9);
const _kReviewRoundRewardCoins = 45;
const _kReviewRoundRewardPoints = 18;

String buildSeoulWeekKey(DateTime dateTime) {
  final nowKst = dateTime.toUtc().add(_kSeoulOffset);
  final monday = nowKst.subtract(Duration(days: nowKst.weekday - 1));
  final month = monday.month.toString().padLeft(2, '0');
  final day = monday.day.toString().padLeft(2, '0');
  return '${monday.year}-W$month$day';
}

String buildSeoulDateKey(DateTime dateTime) {
  final nowKst = dateTime.toUtc().add(_kSeoulOffset);
  final month = nowKst.month.toString().padLeft(2, '0');
  final day = nowKst.day.toString().padLeft(2, '0');
  return '${nowKst.year}-$month-$day';
}

bool isDailyMissionResetRequired({
  required String currentDateKey,
  required DateTime now,
}) {
  return currentDateKey != buildSeoulDateKey(now);
}

({int cashDelta, int rewardPointsDelta}) reviewRoundRewardDelta({
  required bool completed,
}) {
  if (!completed) {
    return (cashDelta: 0, rewardPointsDelta: 0);
  }
  return (
    cashDelta: _kReviewRoundRewardCoins,
    rewardPointsDelta: _kReviewRoundRewardPoints,
  );
}

enum DailyMissionType { solveFive, accuracy70, reviewOne }

enum WeeklyMissionType { balancedInvestor }

extension DailyMissionTypeX on DailyMissionType {
  String get key => name;

  String get title => switch (this) {
    DailyMissionType.solveFive => '오늘 문제 5개 풀기',
    DailyMissionType.accuracy70 => '정답률 70% 이상 달성',
    DailyMissionType.reviewOne => '복습 1회 완료',
  };

  String get subtitle => switch (this) {
    DailyMissionType.solveFive => '오늘 5문제를 끝내면 완료!',
    DailyMissionType.accuracy70 => '오늘 기준 정답률 70% 이상이면 완료!',
    DailyMissionType.reviewOne => '오답 복습 라운드 1번 완료하면 완료!',
  };

  int get rewardCoins => switch (this) {
    DailyMissionType.solveFive => 150,
    DailyMissionType.accuracy70 => 110,
    DailyMissionType.reviewOne => 80,
  };

  int get rewardPoints => switch (this) {
    DailyMissionType.solveFive => 52,
    DailyMissionType.accuracy70 => 38,
    DailyMissionType.reviewOne => 30,
  };
}

extension WeeklyMissionTypeX on WeeklyMissionType {
  String get key => name;

  String get title => switch (this) {
    WeeklyMissionType.balancedInvestor => '균형 투자 주간 챌린지',
  };

  String get subtitle => switch (this) {
    WeeklyMissionType.balancedInvestor =>
      '이번 주 6문제 이상 풀고 평균 위험 관리 72점+ 달성! (근거와 비중 균형 미션)',
  };

  int get rewardCoins => switch (this) {
    WeeklyMissionType.balancedInvestor => 320,
  };

  int get rewardPoints => switch (this) {
    WeeklyMissionType.balancedInvestor => 140,
  };
}

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
    LearnerAgeBand.older => '여러 영향을 함께 보고 위험을 차분히 살펴봐요.',
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

class AppDesign {
  // Mid-balanced vivid+calm palette (Duolingo-inspired, slightly toned down).
  static const Color bgTop = Color(0xFFF4FAF6);
  static const Color bgBottom = Color(0xFFE9F4FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF5FAFF);

  static const Color primary = Color(0xFF54BF19);
  static const Color primaryDeep = Color(0xFF3F9A24);
  static const Color primarySoft = Color(0xFFEAF7DF);
  static const Color secondary = Color(0xFF2AA8EA);
  static const Color secondarySoft = Color(0xFFE6F4FF);
  static const Color accent = Color(0xFFFFC65A);
  static const Color warning = Color(0xFFFFA45A);

  static const Color success = Color(0xFF2BB673);
  static const Color danger = Color(0xFFE1565B);

  static const Color textStrong = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF5B6476);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFD7E6EF);

  static const double spaceXs = 6;
  static const double spaceSm = 10;
  static const double spaceMd = 14;
  static const double spaceLg = 18;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(14));

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x120D1632), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const String titleFont = 'Paperlogy';
  static const String bodyFont = 'Pretendard';

  static TextStyle get title => const TextStyle(
    fontFamily: titleFont,
    fontFamilyFallback: [bodyFont, 'Noto Sans KR', 'sans-serif'],
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: textStrong,
    height: 1.2,
  );

  static TextStyle get subtitle => const TextStyle(
    fontFamily: bodyFont,
    fontFamilyFallback: ['Noto Sans KR', 'sans-serif'],
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: textMuted,
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDesign.spaceMd),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppDesign.surface,
        borderRadius: AppDesign.cardRadius,
        boxShadow: AppDesign.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class KidEconMvpApp extends StatelessWidget {
  const KidEconMvpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '경제탐험대',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: AppDesign.bodyFont,
        scaffoldBackgroundColor: AppDesign.bgTop,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppDesign.primary,
          brightness: Brightness.light,
        ),
        textTheme: ThemeData.light().textTheme
            .apply(
              bodyColor: AppDesign.textStrong,
              displayColor: AppDesign.textStrong,
            )
            .copyWith(
              displayLarge: ThemeData.light().textTheme.displayLarge?.copyWith(
                fontFamily: AppDesign.titleFont,
                fontFamilyFallback: const [
                  AppDesign.bodyFont,
                  'Noto Sans KR',
                  'sans-serif',
                ],
              ),
              displayMedium: ThemeData.light().textTheme.displayMedium
                  ?.copyWith(
                    fontFamily: AppDesign.titleFont,
                    fontFamilyFallback: const [
                      AppDesign.bodyFont,
                      'Noto Sans KR',
                      'sans-serif',
                    ],
                  ),
              displaySmall: ThemeData.light().textTheme.displaySmall?.copyWith(
                fontFamily: AppDesign.titleFont,
                fontFamilyFallback: const [
                  AppDesign.bodyFont,
                  'Noto Sans KR',
                  'sans-serif',
                ],
              ),
              headlineLarge: ThemeData.light().textTheme.headlineLarge
                  ?.copyWith(
                    fontFamily: AppDesign.titleFont,
                    fontFamilyFallback: const [
                      AppDesign.bodyFont,
                      'Noto Sans KR',
                      'sans-serif',
                    ],
                  ),
              headlineMedium: ThemeData.light().textTheme.headlineMedium
                  ?.copyWith(
                    fontFamily: AppDesign.titleFont,
                    fontFamilyFallback: const [
                      AppDesign.bodyFont,
                      'Noto Sans KR',
                      'sans-serif',
                    ],
                  ),
              headlineSmall: ThemeData.light().textTheme.headlineSmall
                  ?.copyWith(
                    fontFamily: AppDesign.titleFont,
                    fontFamilyFallback: const [
                      AppDesign.bodyFont,
                      'Noto Sans KR',
                      'sans-serif',
                    ],
                  ),
            ),
        cardTheme: const CardThemeData(
          color: AppDesign.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppDesign.cardRadius),
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppDesign.primary,
            foregroundColor: AppDesign.textStrong,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: const Color(0xFF8A94A6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(
              fontFamily: AppDesign.bodyFont,
              fontFamilyFallback: ['Noto Sans KR', 'sans-serif'],
              fontWeight: FontWeight.w700,
            ),
          ),
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
  int _skippedMalformedScenarioCount = 0;
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
    _skippedMalformedScenarioCount =
        ScenarioRepository.lastSkippedMalformedCount;
    _session = await AppStateStore.loadSession();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _BootstrapLoadingView();
    }
    return GameHomePage(
      initialState: _state,
      scenarios: _scenarios,
      skippedMalformedScenarioCount: _skippedMalformedScenarioCount,
      initialSession: _session,
      authService: _authService,
    );
  }
}

class _BootstrapLoadingView extends StatelessWidget {
  const _BootstrapLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFECF6FF),
      body: Center(
        child: Image(
          image: AssetImage('assets/branding/mascot_icon_transparent.png'),
          width: 96,
          height: 96,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

enum WrongStageType { industry, reasoning, quiz, allocation, finalDecision }

extension WrongStageTypeX on WrongStageType {
  String get label => switch (this) {
    WrongStageType.industry => '산업 고르기',
    WrongStageType.reasoning => '이유 고르기',
    WrongStageType.quiz => '질문 카드',
    WrongStageType.allocation => '투자 비중',
    WrongStageType.finalDecision => '최종 제출',
  };
}

class WrongAnswerNote {
  const WrongAnswerNote({
    required this.id,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.stageType,
    required this.wrongAt,
    this.reviewedAt,
  });

  final String id;
  final int scenarioId;
  final String scenarioTitle;
  final WrongStageType stageType;
  final DateTime wrongAt;
  final DateTime? reviewedAt;

  bool get isCleared => reviewedAt != null;

  WrongAnswerNote copyWith({DateTime? reviewedAt}) {
    return WrongAnswerNote(
      id: id,
      scenarioId: scenarioId,
      scenarioTitle: scenarioTitle,
      stageType: stageType,
      wrongAt: wrongAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  factory WrongAnswerNote.fromJson(Map<String, dynamic> json) {
    return WrongAnswerNote(
      id: json['id'] as String? ?? '',
      scenarioId: (json['scenarioId'] as num?)?.round() ?? 0,
      scenarioTitle: json['scenarioTitle'] as String? ?? '알 수 없는 문제',
      stageType: WrongStageType.values.firstWhere(
        (e) => e.name == json['stageType'],
        orElse: () => WrongStageType.quiz,
      ),
      wrongAt:
          DateTime.tryParse(json['wrongAt'] as String? ?? '') ?? DateTime.now(),
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'scenarioId': scenarioId,
    'scenarioTitle': scenarioTitle,
    'stageType': stageType.name,
    'wrongAt': wrongAt.toIso8601String(),
    'reviewedAt': reviewedAt?.toIso8601String(),
  };
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

enum DecorationZone { wall, floor, desk, shelf, window }

enum MinimiCategory { hair, top, accessory }

class MinimiPresetItem {
  const MinimiPresetItem({
    required this.id,
    required this.label,
    required this.emoji,
    this.shopItemId,
  });

  final String id;
  final String label;
  final String emoji;
  final String? shopItemId;
}

class MinimiCosmeticState {
  const MinimiCosmeticState({required this.selectedByCategory});

  static const Map<MinimiCategory, String> _defaults = {
    MinimiCategory.hair: 'hair_basic_black',
    MinimiCategory.top: 'top_green_hoodie',
    MinimiCategory.accessory: 'acc_none',
  };

  static MinimiCosmeticState initial() =>
      const MinimiCosmeticState(selectedByCategory: _defaults);

  final Map<MinimiCategory, String> selectedByCategory;

  String selectedId(MinimiCategory category) =>
      selectedByCategory[category] ?? _defaults[category]!;

  MinimiCosmeticState copyWithSelection(
    MinimiCategory category,
    String itemId,
  ) {
    final valid =
        kMinimiPresetByCategory[category]?.any((e) => e.id == itemId) == true;
    final normalizedId = valid ? itemId : _defaults[category]!;
    return MinimiCosmeticState(
      selectedByCategory: {...selectedByCategory, category: normalizedId},
    );
  }

  MinimiCosmeticState resetToDefault() => initial();

  factory MinimiCosmeticState.fromJson(Object? raw) {
    final base = {..._defaults};
    if (raw is! Map) return MinimiCosmeticState(selectedByCategory: base);
    final map = raw.cast<Object?, Object?>();
    for (final category in MinimiCategory.values) {
      final value = map[category.name];
      if (value is! String) continue;
      final valid =
          kMinimiPresetByCategory[category]?.any((e) => e.id == value) == true;
      if (valid) {
        base[category] = value;
      }
    }
    return MinimiCosmeticState(selectedByCategory: base);
  }

  Map<String, dynamic> toJson() => {
    for (final category in MinimiCategory.values)
      category.name: selectedId(category),
  };
}

class MinimiCalibration {
  const MinimiCalibration({
    required this.bodyY,
    required this.bodyScale,
    required this.hairY,
    required this.hairScale,
    required this.topY,
    required this.topScale,
    required this.accessoryY,
    required this.accessoryScale,
  });

  static const double minOffset = -120;
  static const double maxOffset = 120;
  static const double minScale = 0.70;
  static const double maxScale = 1.40;

  static const MinimiCalibration defaults = MinimiCalibration(
    bodyY: 0,
    bodyScale: 1,
    hairY: -80,
    hairScale: 1,
    topY: -66,
    topScale: 1.15,
    accessoryY: -80,
    accessoryScale: 1,
  );

  final double bodyY;
  final double bodyScale;
  final double hairY;
  final double hairScale;
  final double topY;
  final double topScale;
  final double accessoryY;
  final double accessoryScale;

  MinimiCalibration copyWith({
    double? bodyY,
    double? bodyScale,
    double? hairY,
    double? hairScale,
    double? topY,
    double? topScale,
    double? accessoryY,
    double? accessoryScale,
  }) {
    return MinimiCalibration(
      bodyY: clampOffset(bodyY ?? this.bodyY),
      bodyScale: clampScale(bodyScale ?? this.bodyScale),
      hairY: clampOffset(hairY ?? this.hairY),
      hairScale: clampScale(hairScale ?? this.hairScale),
      topY: clampOffset(topY ?? this.topY),
      topScale: clampScale(topScale ?? this.topScale),
      accessoryY: clampOffset(accessoryY ?? this.accessoryY),
      accessoryScale: clampScale(accessoryScale ?? this.accessoryScale),
    );
  }

  static double clampOffset(double value) => value.clamp(minOffset, maxOffset);

  static double clampScale(double value) => value.clamp(minScale, maxScale);

  Map<String, dynamic> toJson() => {
    'bodyY': bodyY,
    'bodyScale': bodyScale,
    'hairY': hairY,
    'hairScale': hairScale,
    'topY': topY,
    'topScale': topScale,
    'accessoryY': accessoryY,
    'accessoryScale': accessoryScale,
  };

  factory MinimiCalibration.fromJson(
    Object? raw, {
    MinimiCalibration fallback = defaults,
  }) {
    if (raw is! Map) return fallback;
    final map = raw.cast<Object?, Object?>();
    return MinimiCalibration(
      bodyY: clampOffset((map['bodyY'] as num?)?.toDouble() ?? fallback.bodyY),
      bodyScale: clampScale(
        (map['bodyScale'] as num?)?.toDouble() ?? fallback.bodyScale,
      ),
      hairY: clampOffset((map['hairY'] as num?)?.toDouble() ?? fallback.hairY),
      hairScale: clampScale(
        (map['hairScale'] as num?)?.toDouble() ?? fallback.hairScale,
      ),
      topY: clampOffset((map['topY'] as num?)?.toDouble() ?? fallback.topY),
      topScale: clampScale(
        (map['topScale'] as num?)?.toDouble() ?? fallback.topScale,
      ),
      accessoryY: clampOffset(
        (map['accessoryY'] as num?)?.toDouble() ?? fallback.accessoryY,
      ),
      accessoryScale: clampScale(
        (map['accessoryScale'] as num?)?.toDouble() ?? fallback.accessoryScale,
      ),
    );
  }
}

const Map<String, String> kMinimiAssetById = {
  'base_body': 'assets/minimi/normalized/base_body.png',
  'hair_basic_black': 'assets/minimi/normalized/hair_basic_black.png',
  'hair_brown_wave': 'assets/minimi/normalized/hair_brown_wave.png',
  'hair_pink_bob': 'assets/minimi/normalized/hair_pink_bob.png',
  'hair_blue_short': 'assets/minimi/normalized/hair_blue_short.png',
  'hair_blonde': 'assets/minimi/normalized/hair_blonde.png',
  'top_green_hoodie': 'assets/minimi/normalized/top_green_hoodie.png',
  'top_blue_jersey': 'assets/minimi/normalized/top_blue_jersey.png',
  'top_orange_knit': 'assets/minimi/normalized/top_orange_knit.png',
  'top_purple_zipup': 'assets/minimi/normalized/top_purple_zipup.png',
  'top_white_shirt': 'assets/minimi/normalized/top_white_shirt.png',
  'acc_cap': 'assets/minimi/normalized/acc_cap.png',
  'acc_glass': 'assets/minimi/normalized/acc_glass.png',
  'acc_headphone': 'assets/minimi/normalized/acc_headphone.png',
  'acc_star_pin': 'assets/minimi/normalized/acc_star_pin.png',
};

const Map<MinimiCategory, List<MinimiPresetItem>> kMinimiPresetByCategory = {
  MinimiCategory.hair: [
    MinimiPresetItem(id: 'hair_basic_black', label: '기본 검정', emoji: '🖤'),
    MinimiPresetItem(id: 'hair_brown_wave', label: '브라운 웨이브', emoji: '🤎'),
    MinimiPresetItem(id: 'hair_pink_bob', label: '핑크 보브', emoji: '💗'),
    MinimiPresetItem(id: 'hair_blue_short', label: '블루 숏컷', emoji: '💙'),
    MinimiPresetItem(id: 'hair_blonde', label: '골드', emoji: '💛'),
  ],
  MinimiCategory.top: [
    MinimiPresetItem(id: 'top_green_hoodie', label: '초록 후드', emoji: '🟢'),
    MinimiPresetItem(id: 'top_blue_jersey', label: '블루 저지', emoji: '🔵'),
    MinimiPresetItem(id: 'top_orange_knit', label: '오렌지 니트', emoji: '🟠'),
    MinimiPresetItem(id: 'top_purple_zipup', label: '퍼플 집업', emoji: '🟣'),
    MinimiPresetItem(id: 'top_white_shirt', label: '화이트 셔츠', emoji: '⚪'),
  ],
  MinimiCategory.accessory: [
    MinimiPresetItem(id: 'acc_none', label: '없음', emoji: '➖'),
    MinimiPresetItem(id: 'acc_cap', label: '탐험 캡', emoji: '🧢'),
    MinimiPresetItem(id: 'acc_glass', label: '동글 안경', emoji: '🕶️'),
    MinimiPresetItem(id: 'acc_headphone', label: '헤드폰', emoji: '🎧'),
    MinimiPresetItem(id: 'acc_star_pin', label: '별 배지', emoji: '⭐'),
  ],
};

const bool kEnableMyRoomInlineSection = false;

const Size _kMinimiPreviewCanvasSize = Size(184, 184);

// r50: base_body anchor marker 기반 정렬. 머리/목선 기준점을 고정하고
// 헤어/상의/소품은 해당 marker에 맞춰 배치 + 아이템별 미세 보정(scale/offset) 적용.
const Map<String, Offset> _kMinimiAnchorMarkerById = {
  'base_body': Offset(256, 256),
  'hair_basic_black': Offset(256, 170),
  'hair_brown_wave': Offset(256, 170),
  'hair_pink_bob': Offset(256, 170),
  'hair_blue_short': Offset(256, 170),
  'hair_blonde': Offset(256, 170),
  'top_green_hoodie': Offset(256, 258),
  'top_blue_jersey': Offset(256, 258),
  'top_orange_knit': Offset(256, 258),
  'top_purple_zipup': Offset(256, 258),
  'top_white_shirt': Offset(256, 258),
  'acc_cap': Offset(256, 168),
  'acc_headphone': Offset(256, 174),
  'acc_glass': Offset(256, 206),
  'acc_star_pin': Offset(228, 305),
};

const Map<MinimiCategory, Offset> _kMinimiBaseTargetMarkerByCategory = {
  MinimiCategory.hair: Offset(256, 170),
  MinimiCategory.top: Offset(256, 258),
  MinimiCategory.accessory: Offset(256, 206),
};

const Map<String, double> _kMinimiItemScaleById = {
  'base_body': 1,
  'hair_basic_black': 1.04,
  'hair_brown_wave': 1.05,
  'hair_pink_bob': 1.04,
  'hair_blue_short': 1.04,
  'hair_blonde': 1.05,
  'top_green_hoodie': 1.03,
  'top_blue_jersey': 1.03,
  'top_orange_knit': 1.02,
  'top_purple_zipup': 1.03,
  'top_white_shirt': 1.03,
  'acc_cap': 1.02,
  'acc_headphone': 1.01,
  'acc_glass': 1.0,
  'acc_star_pin': 0.96,
};

const Map<String, Offset> _kMinimiFineTuneOffsetById = {
  'acc_glass': Offset(0, -1.5),
  'acc_star_pin': Offset(2, 0.5),
};

const Map<String, int> _kMinimiLayerZByItem = {
  'base_body': 1,
  'top_green_hoodie': 2,
  'top_blue_jersey': 2,
  'top_orange_knit': 2,
  'top_purple_zipup': 2,
  'top_white_shirt': 2,
  'hair_basic_black': 3,
  'hair_brown_wave': 3,
  'hair_pink_bob': 3,
  'hair_blue_short': 3,
  'hair_blonde': 3,
  'acc_cap': 4,
  'acc_headphone': 4,
  'acc_glass': 5,
  'acc_star_pin': 5,
};

class _MinimiRenderLayer {
  const _MinimiRenderLayer({
    required this.id,
    required this.assetPath,
    required this.z,
    this.offset = Offset.zero,
    this.scale = 1,
  });

  final String id;
  final String assetPath;
  final int z;
  final Offset offset;
  final double scale;
}

Offset _minimiOffsetFor(
  MinimiCategory category,
  String itemId,
  MinimiCalibration calibration,
) {
  final baseTarget =
      _kMinimiBaseTargetMarkerByCategory[category] ?? const Offset(256, 256);
  final itemMarker = _kMinimiAnchorMarkerById[itemId] ?? const Offset(256, 256);
  final tune = _kMinimiFineTuneOffsetById[itemId] ?? Offset.zero;
  final calibrationY = switch (category) {
    MinimiCategory.hair => calibration.hairY,
    MinimiCategory.top => calibration.topY,
    MinimiCategory.accessory => calibration.accessoryY,
  };
  return Offset(
    (baseTarget.dx - itemMarker.dx) + tune.dx,
    (baseTarget.dy - itemMarker.dy) + tune.dy + calibrationY,
  );
}

List<_MinimiRenderLayer> _buildMinimiRenderLayers({
  required String hairId,
  required String topId,
  required String accessoryId,
  required MinimiCalibration calibration,
}) {
  final selected = <(MinimiCategory?, String)>[
    (null, 'base_body'),
    (MinimiCategory.top, topId),
    (MinimiCategory.hair, hairId),
    if (accessoryId != 'acc_none') (MinimiCategory.accessory, accessoryId),
  ];

  final layers = <_MinimiRenderLayer>[];
  for (final (category, id) in selected) {
    final assetPath = kMinimiAssetById[id];
    if (assetPath == null) continue;
    final baseScale = _kMinimiItemScaleById[id] ?? 1;
    final scale = switch (category) {
      null => baseScale * calibration.bodyScale,
      MinimiCategory.hair => baseScale * calibration.hairScale,
      MinimiCategory.top => baseScale * calibration.topScale,
      MinimiCategory.accessory => baseScale * calibration.accessoryScale,
    };
    final offset = category == null
        ? Offset(0, calibration.bodyY)
        : _minimiOffsetFor(category, id, calibration);
    layers.add(
      _MinimiRenderLayer(
        id: id,
        assetPath: assetPath,
        z: _kMinimiLayerZByItem[id] ?? 99,
        offset: offset,
        scale: scale,
      ),
    );
  }
  layers.sort((a, b) => a.z.compareTo(b.z));
  return layers;
}

extension MinimiCategoryX on MinimiCategory {
  String get label => switch (this) {
    MinimiCategory.hair => '헤어',
    MinimiCategory.top => '상의',
    MinimiCategory.accessory => '소품',
  };

  IconData get icon => switch (this) {
    MinimiCategory.hair => Icons.face_retouching_natural_rounded,
    MinimiCategory.top => Icons.checkroom_rounded,
    MinimiCategory.accessory => Icons.stars_rounded,
  };
}

class RoomItemAdjustment {
  const RoomItemAdjustment({
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1,
  });

  static const double minScale = 0.72;
  static const double maxScale = 3.8;

  final double offsetX;
  final double offsetY;
  final double scale;

  static const defaults = RoomItemAdjustment();

  RoomItemAdjustment copyWith({
    double? offsetX,
    double? offsetY,
    double? scale,
  }) {
    return RoomItemAdjustment(
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
    );
  }

  Map<String, dynamic> toJson() => {
    'offsetX': offsetX,
    'offsetY': offsetY,
    'scale': scale,
  };

  factory RoomItemAdjustment.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final map = json.cast<Object?, Object?>();
    final offsetX = (map['offsetX'] as num?)?.toDouble() ?? 0;
    final offsetY = (map['offsetY'] as num?)?.toDouble() ?? 0;
    final scale = (map['scale'] as num?)?.toDouble() ?? 1;
    return RoomItemAdjustment(
      offsetX: offsetX.clamp(-140, 140),
      offsetY: offsetY.clamp(-140, 140),
      scale: scale.clamp(minScale, maxScale),
    );
  }
}

extension DecorationZoneX on DecorationZone {
  String get key => name;

  String get label => switch (this) {
    DecorationZone.wall => '벽 꾸미기',
    DecorationZone.floor => '바닥 꾸미기',
    DecorationZone.desk => '책상',
    DecorationZone.shelf => '선반',
    DecorationZone.window => '창문',
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
    description: '파도처럼 유연하게 위험 줄이기!',
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
    id: 'deco_wall_frame',
    name: '경제 명언 액자',
    type: CosmeticType.decoration,
    zone: DecorationZone.wall,
    price: 90,
    emoji: '🖼️',
    description: '벽 중앙을 채우는 미니 액자 장식!',
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
    id: 'deco_floor_plant',
    name: '힐링 화분',
    type: CosmeticType.decoration,
    zone: DecorationZone.floor,
    price: 95,
    emoji: '🪴',
    description: '방 분위기를 살리는 코너 화분!',
  ),
  ShopItem(
    id: 'deco_desk_globe',
    name: '뉴스 지구본',
    type: CosmeticType.decoration,
    zone: DecorationZone.desk,
    price: 0,
    emoji: '🌍',
    description: '책상 위 글로벌 뉴스 탐험 소품!',
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
  ShopItem(
    id: 'deco_shelf_books',
    name: '경제 도서 세트',
    type: CosmeticType.decoration,
    zone: DecorationZone.shelf,
    price: 0,
    emoji: '📚',
    description: '선반에 꽂아두는 경제 필독서!',
  ),
  ShopItem(
    id: 'deco_shelf_piggy',
    name: '부자 돼지 저금통',
    type: CosmeticType.decoration,
    zone: DecorationZone.shelf,
    price: 115,
    emoji: '🐷',
    description: '선반 위 저축 습관 마스코트!',
  ),
  ShopItem(
    id: 'deco_window_curtain',
    name: '하늘 커튼',
    type: CosmeticType.decoration,
    zone: DecorationZone.window,
    price: 0,
    emoji: '🪟',
    description: '창문을 아늑하게 꾸미는 커튼!',
  ),
  ShopItem(
    id: 'deco_window_cloud',
    name: '구름 모빌',
    type: CosmeticType.decoration,
    zone: DecorationZone.window,
    price: 100,
    emoji: '☁️',
    description: '창가에 달아두는 가벼운 모빌!',
  ),
  ShopItem(
    id: 'deco_wall_planboard',
    name: '미션 계획 보드',
    type: CosmeticType.decoration,
    zone: DecorationZone.wall,
    price: 125,
    emoji: '📌',
    description: '주간 목표를 적어두는 알림 보드!',
  ),
  ShopItem(
    id: 'deco_wall_medal',
    name: '탐험 메달 배지',
    type: CosmeticType.decoration,
    zone: DecorationZone.wall,
    price: 135,
    emoji: '🥇',
    description: '챕터 완주 메달을 벽에 반짝!',
  ),
  ShopItem(
    id: 'deco_floor_cushion',
    name: '안전 투자 쿠션',
    type: CosmeticType.decoration,
    zone: DecorationZone.floor,
    price: 110,
    emoji: '🛋️',
    description: '차분하게 생각할 때 딱 좋은 쿠션!',
  ),
  ShopItem(
    id: 'deco_floor_train',
    name: '경제 기차 장난감',
    type: CosmeticType.decoration,
    zone: DecorationZone.floor,
    price: 145,
    emoji: '🚂',
    description: '수요와 공급을 싣고 달리는 장난감!',
  ),
  ShopItem(
    id: 'deco_desk_calculator',
    name: '꼼꼼 계산기',
    type: CosmeticType.decoration,
    zone: DecorationZone.desk,
    price: 130,
    emoji: '🧮',
    description: '비중 계산할 때 쓰는 책상 친구!',
  ),
  ShopItem(
    id: 'deco_desk_lamp',
    name: '집중 스탠드',
    type: CosmeticType.decoration,
    zone: DecorationZone.desk,
    price: 118,
    emoji: '💡',
    description: '뉴스 읽을 때 반짝 집중등!',
  ),
  ShopItem(
    id: 'deco_shelf_clock',
    name: '루틴 타이머 시계',
    type: CosmeticType.decoration,
    zone: DecorationZone.shelf,
    price: 126,
    emoji: '⏰',
    description: '매일 학습 시간을 지켜주는 시계!',
  ),
  ShopItem(
    id: 'deco_window_sunrain',
    name: '해·비 날씨 모빌',
    type: CosmeticType.decoration,
    zone: DecorationZone.window,
    price: 132,
    emoji: '🌤️',
    description: '시장 날씨를 기억하는 창가 장식!',
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
    required this.tutorialCompleted,
    required this.selectedDifficulty,
    required this.learnerAgeBand,
    required this.ownedItemIds,
    required this.equippedCharacterId,
    required this.equippedHomeId,
    required this.equippedDecorations,
    required this.decorationAdjustments,
    required this.characterAdjustment,
    required this.homeThemeName,
    required this.totalPointsSpent,
    required this.soundMuted,
    required this.wrongAnswerNotes,
    required this.dailyMissionDateKey,
    required this.dailyClaimedMissionIds,
    required this.dailyReviewCompletedCount,
    required this.weeklyMissionWeekKey,
    required this.weeklyClaimedMissionIds,
    required this.minimiCosmetics,
    required this.minimiCalibration,
    required this.mapExpanded,
    required this.scenarioOrder,
  });

  factory AppState.initial() => AppState(
    playerName: '탐험대원',
    cash: 1000,
    rewardPoints: 0,
    currentScenario: 0,
    results: [],
    bestStreak: 0,
    onboarded: false,
    tutorialCompleted: false,
    selectedDifficulty: DifficultyLevel.easy,
    learnerAgeBand: LearnerAgeBand.middle,
    ownedItemIds: {
      'char_default',
      'home_base_default',
      'deco_wall_chart',
      'deco_floor_rug',
      'deco_desk_globe',
      'deco_shelf_books',
      'deco_window_curtain',
    },
    equippedCharacterId: 'char_default',
    equippedHomeId: 'home_base_default',
    equippedDecorations: {
      DecorationZone.wall: 'deco_wall_chart',
      DecorationZone.floor: 'deco_floor_rug',
      DecorationZone.desk: 'deco_desk_globe',
      DecorationZone.shelf: 'deco_shelf_books',
      DecorationZone.window: 'deco_window_curtain',
    },
    decorationAdjustments: {
      DecorationZone.wall: RoomItemAdjustment.defaults,
      DecorationZone.floor: RoomItemAdjustment.defaults,
      DecorationZone.desk: RoomItemAdjustment.defaults,
      DecorationZone.shelf: RoomItemAdjustment.defaults,
      DecorationZone.window: RoomItemAdjustment.defaults,
    },
    characterAdjustment: RoomItemAdjustment.defaults,
    homeThemeName: '나의 미니룸',
    totalPointsSpent: 0,
    soundMuted: false,
    wrongAnswerNotes: [],
    dailyMissionDateKey: '',
    dailyClaimedMissionIds: {},
    dailyReviewCompletedCount: 0,
    weeklyMissionWeekKey: '',
    weeklyClaimedMissionIds: {},
    minimiCosmetics: MinimiCosmeticState.initial(),
    minimiCalibration: MinimiCalibration.defaults,
    mapExpanded: true,
    scenarioOrder: [],
  );

  final String playerName;
  final int cash;
  final int rewardPoints;
  final int currentScenario;
  final List<ScenarioResult> results;
  final int bestStreak;
  final bool onboarded;
  final bool tutorialCompleted;
  final DifficultyLevel selectedDifficulty;
  final LearnerAgeBand learnerAgeBand;
  final Set<String> ownedItemIds;
  final String equippedCharacterId;
  final String equippedHomeId;
  final Map<DecorationZone, String?> equippedDecorations;
  final Map<DecorationZone, RoomItemAdjustment> decorationAdjustments;
  final RoomItemAdjustment characterAdjustment;
  final String homeThemeName;
  final int totalPointsSpent;
  final bool soundMuted;
  final List<WrongAnswerNote> wrongAnswerNotes;
  final String dailyMissionDateKey;
  final Set<String> dailyClaimedMissionIds;
  final int dailyReviewCompletedCount;
  final String weeklyMissionWeekKey;
  final Set<String> weeklyClaimedMissionIds;
  final MinimiCosmeticState minimiCosmetics;
  final MinimiCalibration minimiCalibration;
  final bool mapExpanded;
  final List<int> scenarioOrder;

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
    final rawAdjustments =
        json['decorationAdjustments'] as Map<String, dynamic>? ?? const {};
    final scenarioOrder = (json['scenarioOrder'] as List<dynamic>? ?? const [])
        .map((e) => (e as num?)?.round())
        .whereType<int>()
        .toList();
    final minimiCosmetics = MinimiCosmeticState.fromJson(
      json['minimiCosmetics'],
    );
    final minimiCalibration = MinimiCalibration.fromJson(
      json['minimiCalibration'],
    );

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
      tutorialCompleted: json['tutorialCompleted'] == true,
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
      decorationAdjustments: {
        for (final zone in DecorationZone.values)
          zone: RoomItemAdjustment.fromJson(rawAdjustments[zone.key]),
      },
      characterAdjustment: RoomItemAdjustment.fromJson(
        json['characterAdjustment'],
      ),
      homeThemeName:
          (json['homeThemeName'] as String?)?.trim().isNotEmpty == true
          ? (json['homeThemeName'] as String).trim()
          : initial.homeThemeName,
      totalPointsSpent:
          (json['totalPointsSpent'] as num?)?.round() ??
          initial.totalPointsSpent,
      soundMuted: json['soundMuted'] == true,
      wrongAnswerNotes: (json['wrongAnswerNotes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WrongAnswerNote.fromJson)
          .toList(),
      dailyMissionDateKey: json['dailyMissionDateKey'] as String? ?? '',
      dailyClaimedMissionIds:
          (json['dailyClaimedMissionIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toSet(),
      dailyReviewCompletedCount:
          (json['dailyReviewCompletedCount'] as num?)?.round() ?? 0,
      weeklyMissionWeekKey: json['weeklyMissionWeekKey'] as String? ?? '',
      weeklyClaimedMissionIds:
          (json['weeklyClaimedMissionIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toSet(),
      minimiCosmetics: minimiCosmetics,
      minimiCalibration: minimiCalibration,
      mapExpanded: json['mapExpanded'] != false,
      scenarioOrder: scenarioOrder,
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
    'tutorialCompleted': tutorialCompleted,
    'selectedDifficulty': selectedDifficulty.name,
    'learnerAgeBand': learnerAgeBand.name,
    'ownedItemIds': ownedItemIds.toList(),
    'equippedCharacterId': equippedCharacterId,
    'equippedHomeId': equippedHomeId,
    'equippedDecorations': {
      for (final entry in equippedDecorations.entries)
        entry.key.key: entry.value,
    },
    'decorationAdjustments': {
      for (final entry in decorationAdjustments.entries)
        entry.key.key: entry.value.toJson(),
    },
    'characterAdjustment': characterAdjustment.toJson(),
    'homeThemeName': homeThemeName,
    'totalPointsSpent': totalPointsSpent,
    'soundMuted': soundMuted,
    'wrongAnswerNotes': wrongAnswerNotes.map((e) => e.toJson()).toList(),
    'dailyMissionDateKey': dailyMissionDateKey,
    'dailyClaimedMissionIds': dailyClaimedMissionIds.toList(),
    'dailyReviewCompletedCount': dailyReviewCompletedCount,
    'weeklyMissionWeekKey': weeklyMissionWeekKey,
    'weeklyClaimedMissionIds': weeklyClaimedMissionIds.toList(),
    'minimiCosmetics': minimiCosmetics.toJson(),
    'minimiCalibration': minimiCalibration.toJson(),
    'mapExpanded': mapExpanded,
    'scenarioOrder': scenarioOrder,
  };

  AppState copyWith({
    String? playerName,
    int? cash,
    int? rewardPoints,
    int? currentScenario,
    List<ScenarioResult>? results,
    int? bestStreak,
    bool? onboarded,
    bool? tutorialCompleted,
    DifficultyLevel? selectedDifficulty,
    LearnerAgeBand? learnerAgeBand,
    Set<String>? ownedItemIds,
    String? equippedCharacterId,
    String? equippedHomeId,
    Map<DecorationZone, String?>? equippedDecorations,
    Map<DecorationZone, RoomItemAdjustment>? decorationAdjustments,
    RoomItemAdjustment? characterAdjustment,
    String? homeThemeName,
    int? totalPointsSpent,
    bool? soundMuted,
    List<WrongAnswerNote>? wrongAnswerNotes,
    String? dailyMissionDateKey,
    Set<String>? dailyClaimedMissionIds,
    int? dailyReviewCompletedCount,
    String? weeklyMissionWeekKey,
    Set<String>? weeklyClaimedMissionIds,
    MinimiCosmeticState? minimiCosmetics,
    MinimiCalibration? minimiCalibration,
    bool? mapExpanded,
    List<int>? scenarioOrder,
  }) {
    return AppState(
      playerName: playerName ?? this.playerName,
      cash: cash ?? this.cash,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      currentScenario: currentScenario ?? this.currentScenario,
      results: results ?? this.results,
      bestStreak: bestStreak ?? this.bestStreak,
      onboarded: onboarded ?? this.onboarded,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
      learnerAgeBand: learnerAgeBand ?? this.learnerAgeBand,
      ownedItemIds: ownedItemIds ?? this.ownedItemIds,
      equippedCharacterId: equippedCharacterId ?? this.equippedCharacterId,
      equippedHomeId: equippedHomeId ?? this.equippedHomeId,
      equippedDecorations: equippedDecorations ?? this.equippedDecorations,
      decorationAdjustments:
          decorationAdjustments ?? this.decorationAdjustments,
      characterAdjustment: characterAdjustment ?? this.characterAdjustment,
      homeThemeName: homeThemeName ?? this.homeThemeName,
      totalPointsSpent: totalPointsSpent ?? this.totalPointsSpent,
      soundMuted: soundMuted ?? this.soundMuted,
      wrongAnswerNotes: wrongAnswerNotes ?? this.wrongAnswerNotes,
      dailyMissionDateKey: dailyMissionDateKey ?? this.dailyMissionDateKey,
      dailyClaimedMissionIds:
          dailyClaimedMissionIds ?? this.dailyClaimedMissionIds,
      dailyReviewCompletedCount:
          dailyReviewCompletedCount ?? this.dailyReviewCompletedCount,
      weeklyMissionWeekKey: weeklyMissionWeekKey ?? this.weeklyMissionWeekKey,
      weeklyClaimedMissionIds:
          weeklyClaimedMissionIds ?? this.weeklyClaimedMissionIds,
      minimiCosmetics: minimiCosmetics ?? this.minimiCosmetics,
      minimiCalibration: minimiCalibration ?? this.minimiCalibration,
      mapExpanded: mapExpanded ?? this.mapExpanded,
      scenarioOrder: scenarioOrder ?? this.scenarioOrder,
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
  static const _kTutorialCompleted = 'tutorialCompleted';
  static const _kDifficulty = 'difficulty';
  static const _kLearnerAgeBand = 'learnerAgeBand';
  static const _kRewardPoints = 'rewardPoints';
  static const _kOwnedItemIds = 'ownedItemIds';
  static const _kEquippedCharacterId = 'equippedCharacterId';
  static const _kEquippedHomeId = 'equippedHomeId';
  static const _kEquippedDecorations = 'equippedDecorations';
  static const _kDecorationAdjustments = 'decorationAdjustments';
  static const _kCharacterAdjustment = 'characterAdjustment';
  static const _kTotalPointsSpent = 'totalPointsSpent';
  static const _kAuthSession = 'authSession';
  static const _kSoundMuted = 'soundMuted';
  static const _kHomeThemeName = 'homeThemeName';
  static const _kWrongAnswerNotes = 'wrongAnswerNotes';
  static const _kDailyMissionDateKey = 'dailyMissionDateKey';
  static const _kDailyClaimedMissionIds = 'dailyClaimedMissionIds';
  static const _kDailyReviewCompletedCount = 'dailyReviewCompletedCount';
  static const _kWeeklyMissionWeekKey = 'weeklyMissionWeekKey';
  static const _kWeeklyClaimedMissionIds = 'weeklyClaimedMissionIds';
  static const _kMinimiCosmetics = 'minimiCosmetics';
  static const _kMinimiCalibration = 'minimiCalibration';
  static const _kMinimiCalibrationDefault = 'minimiCalibrationDefault';
  static const _kMapExpanded = 'mapExpanded';
  static const _kScenarioOrder = 'scenarioOrder';

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

    Map<String, dynamic> adjustmentRaw = const {};
    final adjustmentJson = prefs.getString(_kDecorationAdjustments);
    Map<String, dynamic> characterAdjustmentRaw = const {};
    final characterAdjustmentJson = prefs.getString(_kCharacterAdjustment);
    var wrongNotes = <WrongAnswerNote>[];
    final wrongNotesJson = prefs.getString(_kWrongAnswerNotes);
    if (wrongNotesJson != null && wrongNotesJson.isNotEmpty) {
      try {
        final list = jsonDecode(wrongNotesJson) as List<dynamic>;
        wrongNotes = list
            .whereType<Map<String, dynamic>>()
            .map(WrongAnswerNote.fromJson)
            .toList();
      } catch (_) {
        wrongNotes = const [];
      }
    }
    if (characterAdjustmentJson != null && characterAdjustmentJson.isNotEmpty) {
      try {
        characterAdjustmentRaw =
            jsonDecode(characterAdjustmentJson) as Map<String, dynamic>;
      } catch (_) {
        characterAdjustmentRaw = const {};
      }
    }
    Map<String, dynamic> minimiRaw = const {};
    final minimiJson = prefs.getString(_kMinimiCosmetics);
    if (minimiJson != null && minimiJson.isNotEmpty) {
      try {
        minimiRaw = jsonDecode(minimiJson) as Map<String, dynamic>;
      } catch (_) {
        minimiRaw = const {};
      }
    }
    Map<String, dynamic> minimiCalibrationRaw = const {};
    final minimiCalibrationJson = prefs.getString(_kMinimiCalibration);
    if (minimiCalibrationJson != null && minimiCalibrationJson.isNotEmpty) {
      try {
        minimiCalibrationRaw =
            jsonDecode(minimiCalibrationJson) as Map<String, dynamic>;
      } catch (_) {
        minimiCalibrationRaw = const {};
      }
    }
    Map<String, dynamic> minimiCalibrationDefaultRaw = const {};
    final minimiCalibrationDefaultJson = prefs.getString(
      _kMinimiCalibrationDefault,
    );
    if (minimiCalibrationDefaultJson != null &&
        minimiCalibrationDefaultJson.isNotEmpty) {
      try {
        minimiCalibrationDefaultRaw =
            jsonDecode(minimiCalibrationDefaultJson) as Map<String, dynamic>;
      } catch (_) {
        minimiCalibrationDefaultRaw = const {};
      }
    }
    final minimiCalibrationDefault = MinimiCalibration.fromJson(
      minimiCalibrationDefaultRaw,
    );

    if (adjustmentJson != null && adjustmentJson.isNotEmpty) {
      try {
        adjustmentRaw = jsonDecode(adjustmentJson) as Map<String, dynamic>;
      } catch (_) {
        adjustmentRaw = const {};
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
      tutorialCompleted:
          prefs.getBool(_kTutorialCompleted) ?? initial.tutorialCompleted,
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
      decorationAdjustments: {
        for (final zone in DecorationZone.values)
          zone: RoomItemAdjustment.fromJson(adjustmentRaw[zone.key]),
      },
      characterAdjustment: RoomItemAdjustment.fromJson(characterAdjustmentRaw),
      homeThemeName: (prefs.getString(_kHomeThemeName) ?? '').trim().isNotEmpty
          ? (prefs.getString(_kHomeThemeName) ?? '').trim()
          : initial.homeThemeName,
      totalPointsSpent:
          prefs.getInt(_kTotalPointsSpent) ?? initial.totalPointsSpent,
      soundMuted: prefs.getBool(_kSoundMuted) ?? initial.soundMuted,
      wrongAnswerNotes: wrongNotes,
      dailyMissionDateKey: prefs.getString(_kDailyMissionDateKey) ?? '',
      dailyClaimedMissionIds:
          (prefs.getStringList(_kDailyClaimedMissionIds) ?? const []).toSet(),
      dailyReviewCompletedCount: prefs.getInt(_kDailyReviewCompletedCount) ?? 0,
      weeklyMissionWeekKey: prefs.getString(_kWeeklyMissionWeekKey) ?? '',
      weeklyClaimedMissionIds:
          (prefs.getStringList(_kWeeklyClaimedMissionIds) ?? const []).toSet(),
      minimiCosmetics: MinimiCosmeticState.fromJson(minimiRaw),
      minimiCalibration: MinimiCalibration.fromJson(
        minimiCalibrationRaw,
        fallback: minimiCalibrationDefault,
      ),
      mapExpanded: prefs.getBool(_kMapExpanded) ?? true,
      scenarioOrder: (prefs.getStringList(_kScenarioOrder) ?? const [])
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toList(),
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
    await prefs.setBool(_kTutorialCompleted, state.tutorialCompleted);
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
    await prefs.setString(
      _kDecorationAdjustments,
      jsonEncode({
        for (final entry in state.decorationAdjustments.entries)
          entry.key.key: entry.value.toJson(),
      }),
    );
    await prefs.setString(
      _kCharacterAdjustment,
      jsonEncode(state.characterAdjustment.toJson()),
    );
    await prefs.setInt(_kTotalPointsSpent, state.totalPointsSpent);
    await prefs.setBool(_kSoundMuted, state.soundMuted);
    await prefs.setString(_kHomeThemeName, state.homeThemeName);
    await prefs.setString(
      _kWrongAnswerNotes,
      jsonEncode(state.wrongAnswerNotes.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(_kDailyMissionDateKey, state.dailyMissionDateKey);
    await prefs.setStringList(
      _kDailyClaimedMissionIds,
      state.dailyClaimedMissionIds.toList(),
    );
    await prefs.setInt(
      _kDailyReviewCompletedCount,
      state.dailyReviewCompletedCount,
    );
    await prefs.setString(_kWeeklyMissionWeekKey, state.weeklyMissionWeekKey);
    await prefs.setStringList(
      _kWeeklyClaimedMissionIds,
      state.weeklyClaimedMissionIds.toList(),
    );
    await prefs.setString(
      _kMinimiCosmetics,
      jsonEncode(state.minimiCosmetics.toJson()),
    );
    await prefs.setString(
      _kMinimiCalibration,
      jsonEncode(state.minimiCalibration.toJson()),
    );
    await prefs.setBool(_kMapExpanded, state.mapExpanded);
    await prefs.setStringList(
      _kScenarioOrder,
      state.scenarioOrder.map((e) => '$e').toList(),
    );

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

  static Future<MinimiCalibration> loadMinimiCalibrationDefault() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMinimiCalibrationDefault);
    if (raw == null || raw.isEmpty) return MinimiCalibration.defaults;
    try {
      return MinimiCalibration.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return MinimiCalibration.defaults;
    }
  }

  static Future<void> saveMinimiCalibrationDefault(
    MinimiCalibration calibration,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kMinimiCalibrationDefault,
      jsonEncode(calibration.toJson()),
    );
  }
}

class GameHomePage extends StatefulWidget {
  const GameHomePage({
    super.key,
    required this.initialState,
    required this.scenarios,
    required this.skippedMalformedScenarioCount,
    required this.authService,
    this.initialSession,
  });

  final AppState initialState;
  final List<Scenario> scenarios;
  final int skippedMalformedScenarioCount;
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
  int? _previewScenarioIndex;
  bool _showPracticeNudge = false;
  List<WrongAnswerNote> _reviewQueue = const [];
  int _reviewRoundIndex = 0;
  MinimiCalibration _minimiDefaultCalibration = MinimiCalibration.defaults;

  List<int> _normalizedScenarioOrder({required AppState baseState}) {
    final ids = widget.scenarios.map((e) => e.id).toList();
    if (ids.isEmpty) return const [];
    final current = baseState.scenarioOrder;
    if (current.length == ids.length && current.toSet().containsAll(ids)) {
      return current;
    }
    final shuffled = [...ids]..shuffle();
    return shuffled;
  }

  int _scenarioIndexByChapter(int chapterIndex) {
    final order = _state.scenarioOrder;
    if (widget.scenarios.isEmpty) return 0;
    if (order.isEmpty) {
      return chapterIndex.clamp(0, widget.scenarios.length - 1);
    }
    final clamped = chapterIndex.clamp(0, order.length - 1);
    final scenarioId = order[clamped];
    final index = widget.scenarios.indexWhere((e) => e.id == scenarioId);
    return index >= 0 ? index : clamped.clamp(0, widget.scenarios.length - 1);
  }

  int _scenarioIndexById(int scenarioId) {
    final index = widget.scenarios.indexWhere((e) => e.id == scenarioId);
    return index >= 0 ? index : 0;
  }

  bool get _isPreviewingScenario => _previewScenarioIndex != null;

  bool get _isLoggedIn => _session != null;
  bool get _isReviewMode => _reviewQueue.isNotEmpty;

  String _seoulDateKey([DateTime? dateTime]) {
    return buildSeoulDateKey(dateTime ?? DateTime.now());
  }

  AppState _stateWithDailyResetIfNeeded(AppState source) {
    final now = DateTime.now();
    var next = source;

    if (isDailyMissionResetRequired(
      currentDateKey: source.dailyMissionDateKey,
      now: now,
    )) {
      next = next.copyWith(
        dailyMissionDateKey: buildSeoulDateKey(now),
        dailyClaimedMissionIds: <String>{},
        dailyReviewCompletedCount: 0,
      );
    }

    final currentWeek = buildSeoulWeekKey(now);
    if (next.weeklyMissionWeekKey != currentWeek) {
      next = next.copyWith(
        weeklyMissionWeekKey: currentWeek,
        weeklyClaimedMissionIds: <String>{},
      );
    }

    return next;
  }

  ({int solved, int correct, int reviewDone}) _todayMissionProgress() {
    final today = _seoulDateKey();
    final todayResults = _state.results
        .where((e) => _seoulDateKey(e.timestamp) == today)
        .toList();
    final correctCount = todayResults
        .where((e) => e.judgementScore >= 70)
        .length;
    return (
      solved: todayResults.length,
      correct: correctCount,
      reviewDone: _state.dailyReviewCompletedCount,
    );
  }

  bool _isMissionComplete(DailyMissionType type) {
    final progress = _todayMissionProgress();
    return switch (type) {
      DailyMissionType.solveFive => progress.solved >= 5,
      DailyMissionType.accuracy70 =>
        progress.solved > 0 &&
            ((progress.correct / progress.solved) * 100) >= 70,
      DailyMissionType.reviewOne => progress.reviewDone >= 1,
    };
  }

  ({int solved, int avgRisk, int balancedCount}) _thisWeekMissionProgress() {
    final currentWeek = buildSeoulWeekKey(DateTime.now());
    final weekResults = _state.results
        .where((e) => buildSeoulWeekKey(e.timestamp) == currentWeek)
        .toList();
    final solved = weekResults.length;
    final avgRisk = solved == 0
        ? 0
        : (weekResults.fold<int>(0, (sum, e) => sum + e.riskManagementScore) /
                  solved)
              .round();
    final balancedCount = weekResults
        .where((e) => e.allocationPercent >= 35 && e.allocationPercent <= 65)
        .length;
    return (solved: solved, avgRisk: avgRisk, balancedCount: balancedCount);
  }

  bool _isWeeklyMissionComplete(WeeklyMissionType type) {
    final progress = _thisWeekMissionProgress();
    return switch (type) {
      WeeklyMissionType.balancedInvestor =>
        progress.solved >= 6 &&
            progress.avgRisk >= 72 &&
            progress.balancedCount >= 4,
    };
  }

  void _showRewardSnackBar({
    required String title,
    required String message,
    Color color = const Color(0xFF0EA35A),
    IconData icon = Icons.celebration_rounded,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(message, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _claimDailyMission(DailyMissionType type) {
    if (_state.dailyClaimedMissionIds.contains(type.key)) {
      _showRewardSnackBar(
        title: '이미 수령 완료!',
        message: '이 미션 보상은 오늘 이미 받았어. 정말 잘했어! 👏',
        color: const Color(0xFF5A6575),
        icon: Icons.check_circle_rounded,
      );
      return;
    }
    if (!_isMissionComplete(type)) {
      _showRewardSnackBar(
        title: '조금만 더 하면 돼!',
        message: '미션 조건을 먼저 채우면 반짝 보상을 받을 수 있어 ✨',
        color: const Color(0xFF3A7BDA),
        icon: Icons.flag_rounded,
      );
      return;
    }

    final nextClaims = {..._state.dailyClaimedMissionIds, type.key};
    setState(() {
      _state = _state.copyWith(
        cash: _state.cash + type.rewardCoins,
        rewardPoints: _state.rewardPoints + type.rewardPoints,
        dailyClaimedMissionIds: nextClaims,
      );
    });
    _persist();
    _showRewardSnackBar(
      title: '데일리 미션 성공!',
      message:
          '${type.title} 완료! +${type.rewardCoins}코인 · +${type.rewardPoints}P 획득!',
    );
  }

  void _claimWeeklyMission(WeeklyMissionType type) {
    if (_state.weeklyClaimedMissionIds.contains(type.key)) {
      _showRewardSnackBar(
        title: '주간 보상 수령 완료!',
        message: '이번 주 미션 보상은 이미 받았어. 정말 대단해! 🌈',
        color: const Color(0xFF5A6575),
        icon: Icons.check_circle_rounded,
      );
      return;
    }
    if (!_isWeeklyMissionComplete(type)) {
      _showRewardSnackBar(
        title: '주간 미션 진행 중!',
        message: '이번 주 목표를 조금만 더 채우면 특별 보상을 받을 수 있어 ✨',
        color: const Color(0xFF3A7BDA),
        icon: Icons.event_note_rounded,
      );
      return;
    }

    final nextClaims = {..._state.weeklyClaimedMissionIds, type.key};
    setState(() {
      _state = _state.copyWith(
        cash: _state.cash + type.rewardCoins,
        rewardPoints: _state.rewardPoints + type.rewardPoints,
        weeklyClaimedMissionIds: nextClaims,
      );
    });
    _persist();
    _showRewardSnackBar(
      title: '주간 미션 성공!',
      message:
          '${type.title} 달성! +${type.rewardCoins}코인 · +${type.rewardPoints}P 획득!',
      color: const Color(0xFF6A4DFF),
      icon: Icons.workspace_premium_rounded,
    );
  }

  void _recordWrongAnswer(Scenario scenario, WrongStageType stageType) {
    final now = DateTime.now();
    final note = WrongAnswerNote(
      id: '${scenario.id}-${stageType.name}-${now.millisecondsSinceEpoch}',
      scenarioId: scenario.id,
      scenarioTitle: scenario.title,
      stageType: stageType,
      wrongAt: now,
    );
    final next = [note, ..._state.wrongAnswerNotes].take(60).toList();
    setState(() {
      _state = _state.copyWith(wrongAnswerNotes: next);
    });
    _persist();
  }

  void _startReviewRound() {
    final targets = _state.wrongAnswerNotes.where((e) => !e.isCleared).toList()
      ..sort((a, b) => b.wrongAt.compareTo(a.wrongAt));
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지금은 복습할 문제가 없어요. 탐험을 먼저 해볼까?')),
      );
      return;
    }
    setState(() {
      _reviewQueue = targets.take(3).toList();
      _reviewRoundIndex = 0;
      _tabIndex = 0;
      _previewScenarioIndex = null;
      _showPracticeNudge = false;
    });
  }

  void _endReviewRound({bool completed = true}) {
    final reward = reviewRoundRewardDelta(completed: completed);
    setState(() {
      _reviewQueue = const [];
      _reviewRoundIndex = 0;
      if (completed) {
        _state = _state.copyWith(
          cash: _state.cash + reward.cashDelta,
          rewardPoints: _state.rewardPoints + reward.rewardPointsDelta,
          dailyReviewCompletedCount: _state.dailyReviewCompletedCount + 1,
        );
      }
    });
    if (completed) {
      _persist();
      _showRewardSnackBar(
        title: '복습 미션 클리어!',
        message:
            '집중 복습 완료! +$_kReviewRoundRewardCoins코인 · +${_kReviewRoundRewardPoints}P 받았어. 계속 가보자 🚀',
        color: const Color(0xFF6A4DFF),
        icon: Icons.auto_awesome_rounded,
      );
    }
  }

  void _handleReviewDone(ScenarioResult result) {
    final note = _reviewQueue[_reviewRoundIndex];
    if (result.judgementScore >= 70) {
      final nextNotes = _state.wrongAnswerNotes.map((e) {
        if (e.id == note.id && !e.isCleared) {
          return e.copyWith(reviewedAt: DateTime.now());
        }
        return e;
      }).toList();
      _state = _state.copyWith(wrongAnswerNotes: nextNotes);
      _persist();
    }

    if (_reviewRoundIndex >= _reviewQueue.length - 1) {
      _endReviewRound();
      return;
    }
    setState(() => _reviewRoundIndex += 1);
  }

  @override
  void initState() {
    super.initState();
    _state = _stateWithDailyResetIfNeeded(widget.initialState);
    final normalizedOrder = _normalizedScenarioOrder(baseState: _state);
    final orderChanged = !listEquals(normalizedOrder, _state.scenarioOrder);
    if (orderChanged) {
      _state = _state.copyWith(scenarioOrder: normalizedOrder);
    }
    _session = widget.initialSession;
    AppStateStore.loadMinimiCalibrationDefault().then((value) {
      if (!mounted) return;
      setState(() => _minimiDefaultCalibration = value);
    });
    if (_state.dailyMissionDateKey != widget.initialState.dailyMissionDateKey ||
        orderChanged) {
      _persist();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_state.onboarded) {
        await _showOnboarding();
      }
      if (_state.onboarded && !_state.tutorialCompleted && mounted) {
        await _showGameFlowTutorial();
      }
    });
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
                              ? AppDesign.secondary
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

  Future<void> _showGameFlowTutorial() async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _GameFlowTutorialDialog(),
    );
    if (done == true && mounted) {
      setState(() {
        _state = _state.copyWith(tutorialCompleted: true);
        _tabIndex = 0;
        _showPracticeNudge = true;
      });
      _persist();
    }
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
        var loaded = _stateWithDailyResetIfNeeded(AppState.fromJson(cloud));
        loaded = loaded.copyWith(
          scenarioOrder: _normalizedScenarioOrder(baseState: loaded),
        );
        _state = loaded;
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
      _previewScenarioIndex = null;
      _tabIndex = 0;
      _showPracticeNudge = false;
    });
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🎁 탐험 포인트 +$earnedPoints! 상점에서 꾸미기를 열어보세요.')),
    );
  }

  void _jumpToDifferentScenarioForTesting() {
    final total = widget.scenarios.length;
    if (total == 0) return;

    final currentPlayIndex = _scenarioIndexByChapter(_state.currentScenario);
    final candidates = List<int>.generate(total, (i) => i)
      ..remove(currentPlayIndex);
    if (candidates.isEmpty) return;

    final nextScenario = candidates[Random().nextInt(candidates.length)];
    setState(() {
      _previewScenarioIndex = nextScenario;
      _tabIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '미리보기 문제 ${nextScenario + 1}번을 열었어요. 실제 챕터 진행은 ${_state.currentScenario + 1}번에서 유지돼요.',
        ),
      ),
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

  void _updateDecorationAdjustment(
    DecorationZone zone,
    RoomItemAdjustment adjustment,
  ) {
    final next = {..._state.decorationAdjustments, zone: adjustment};
    setState(() {
      _state = _state.copyWith(decorationAdjustments: next);
    });
    _persist();
  }

  void _updateCharacterAdjustment(RoomItemAdjustment adjustment) {
    setState(() {
      _state = _state.copyWith(characterAdjustment: adjustment);
    });
    _persist();
  }

  void _updateHomeThemeName(String value) {
    final normalized = value.trim();
    final next = normalized.isEmpty ? '나의 미니룸' : normalized;
    if (next == _state.homeThemeName) return;
    setState(() {
      _state = _state.copyWith(homeThemeName: next);
    });
    _persist();
  }

  void _selectMinimiPreset(MinimiCategory category, String itemId) {
    setState(() {
      _state = _state.copyWith(
        minimiCosmetics: _state.minimiCosmetics.copyWithSelection(
          category,
          itemId,
        ),
      );
    });
    _persist();
  }

  void _updateMinimiCalibration(MinimiCalibration calibration) {
    setState(() {
      _state = _state.copyWith(minimiCalibration: calibration);
    });
  }

  void _saveMinimiCalibration(MinimiCalibration calibration) {
    setState(() {
      _state = _state.copyWith(minimiCalibration: calibration);
    });
    _persist();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('현재 정렬 값을 저장했어요.')));
  }

  Future<void> _setMinimiCalibrationAsDefault(
    MinimiCalibration calibration,
  ) async {
    final previous = _minimiDefaultCalibration;
    try {
      await AppStateStore.saveMinimiCalibrationDefault(calibration);
      if (!mounted) return;
      setState(() => _minimiDefaultCalibration = calibration);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 값을 기준값으로 고정했어요. 다음 실행부터 자동 반영돼요.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _minimiDefaultCalibration = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기준값 저장에 실패했어요.')));
    }
  }

  void _resetMinimiToDefault() {
    setState(() {
      _state = _state.copyWith(
        minimiCosmetics: MinimiCosmeticState.initial(),
        minimiCalibration: MinimiCalibration.defaults,
      );
    });
    _persist();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('미니미를 기본값으로 되돌렸어요.')));
  }

  void _resetMinimiCalibrationToDefault() {
    _updateMinimiCalibration(_minimiDefaultCalibration);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('기준값으로 복원했어요.')));
  }

  void _resetProgress() {
    setState(() {
      _state = AppState.initial().copyWith(
        playerName: _state.playerName,
        onboarded: true,
        tutorialCompleted: false,
        selectedDifficulty: _state.selectedDifficulty,
        learnerAgeBand: _state.learnerAgeBand,
        mapExpanded: _state.mapExpanded,
        scenarioOrder: _normalizedScenarioOrder(baseState: _state),
      );
      _tabIndex = 0;
      _showPracticeNudge = false;
    });
    _persist();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showGameFlowTutorial();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final normalizedState = _stateWithDailyResetIfNeeded(_state);
    if (normalizedState.dailyMissionDateKey != _state.dailyMissionDateKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _state = normalizedState);
        _persist();
      });
    }

    final pages = [
      _PlayTab(
        state: _state,
        scenarios: widget.scenarios,
        scenarioIndexByChapter: _scenarioIndexByChapter,
        scenarioIndexById: _scenarioIndexById,
        previewScenarioIndex: _previewScenarioIndex,
        reviewQueue: _reviewQueue,
        reviewRoundIndex: _reviewRoundIndex,
        isReviewMode: _isReviewMode,
        isPreviewMode: _isPreviewingScenario,
        onDifficultyChanged: (d) {
          setState(() => _state = _state.copyWith(selectedDifficulty: d));
          _persist();
        },
        onDone: (result) {
          if (_isReviewMode) {
            _handleReviewDone(result);
            return;
          }
          if (_isPreviewingScenario) {
            setState(() => _previewScenarioIndex = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('미리보기 완료! 실제 챕터 진행에는 반영되지 않았어요.')),
            );
            return;
          }
          _applyScenarioResult(result);
        },
        onJumpToDifferentScenario: _jumpToDifferentScenarioForTesting,
        onSoundMutedChanged: (muted) {
          setState(() => _state = _state.copyWith(soundMuted: muted));
          _persist();
        },
        onMapExpandedChanged: (expanded) {
          setState(() => _state = _state.copyWith(mapExpanded: expanded));
          _persist();
        },
        showPracticeNudge: _showPracticeNudge,
        onPracticeNudgeDismissed: () {
          if (_showPracticeNudge) {
            setState(() => _showPracticeNudge = false);
          }
        },
        onWrongAnswer: _recordWrongAnswer,
        onStopReview: _endReviewRound,
      ),
      _MyHomeTab(
        state: _state,
        syncMessage: _syncMessage,
        session: _session,
        onPlaceDecoration: _placeDecoration,
        onDecorationAdjusted: _updateDecorationAdjustment,
        onCharacterAdjusted: _updateCharacterAdjustment,
        onThemeNameChanged: _updateHomeThemeName,
        onEquipHome: _equipItem,
        onSelectMinimiPreset: _selectMinimiPreset,
        onResetMinimi: _resetMinimiToDefault,
        onMinimiCalibrationChanged: _updateMinimiCalibration,
        onSaveMinimiCalibration: _saveMinimiCalibration,
        onResetMinimiCalibration: _resetMinimiCalibrationToDefault,
        onSetMinimiCalibrationDefault: _setMinimiCalibrationAsDefault,
      ),
      _ShopTab(state: _state, onBuyOrEquip: _buyAndEquipItem),
      _WeeklyReportTab(
        state: _state,
        onStartReview: _startReviewRound,
        isReviewRunning: _isReviewMode,
        onClaimMission: _claimDailyMission,
        onClaimWeeklyMission: _claimWeeklyMission,
        seoulDateKey: _seoulDateKey(),
        skippedMalformedScenarioCount: widget.skippedMalformedScenarioCount,
      ),
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
      appBar: AppBar(
        title: Image.asset(
          'assets/branding/mascot_icon_transparent.png',
          height: 42,
          fit: BoxFit.contain,
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFDDE3F2)),
            ),
            child: const Text(
              kAppUiVersion,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(child: pages[_tabIndex]),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A293F6B),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppDesign.primarySoft,
          selectedIndex: _tabIndex,
          onDestinationSelected: (v) => setState(() => _tabIndex = v),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.explore), label: '탐험 맵'),
            NavigationDestination(icon: Icon(Icons.cottage), label: '마이홈'),
            NavigationDestination(icon: Icon(Icons.storefront), label: '상점'),
            NavigationDestination(icon: Icon(Icons.insights), label: '미션/리포트'),
            NavigationDestination(icon: Icon(Icons.menu_book), label: '가이드'),
          ],
        ),
      ),
    );
  }
}

class _PlayTab extends StatelessWidget {
  const _PlayTab({
    required this.state,
    required this.scenarios,
    required this.scenarioIndexByChapter,
    required this.scenarioIndexById,
    required this.previewScenarioIndex,
    required this.reviewQueue,
    required this.reviewRoundIndex,
    required this.isReviewMode,
    required this.isPreviewMode,
    required this.onDone,
    required this.onJumpToDifferentScenario,
    required this.onDifficultyChanged,
    required this.onSoundMutedChanged,
    required this.onMapExpandedChanged,
    required this.showPracticeNudge,
    required this.onPracticeNudgeDismissed,
    required this.onWrongAnswer,
    required this.onStopReview,
  });

  final AppState state;
  final List<Scenario> scenarios;
  final int Function(int chapterIndex) scenarioIndexByChapter;
  final int Function(int scenarioId) scenarioIndexById;
  final int? previewScenarioIndex;
  final List<WrongAnswerNote> reviewQueue;
  final int reviewRoundIndex;
  final bool isReviewMode;
  final bool isPreviewMode;
  final ValueChanged<ScenarioResult> onDone;
  final VoidCallback onJumpToDifferentScenario;
  final ValueChanged<DifficultyLevel> onDifficultyChanged;
  final ValueChanged<bool> onSoundMutedChanged;
  final ValueChanged<bool> onMapExpandedChanged;
  final bool showPracticeNudge;
  final VoidCallback onPracticeNudgeDismissed;
  final void Function(Scenario scenario, WrongStageType stageType)
  onWrongAnswer;
  final VoidCallback onStopReview;

  static const List<String> _chapterObjectives = [
    '기회비용: 여러 선택지 중 가장 좋은 선택을 찾아요.',
    '분산투자: 수혜와 피해를 함께 보며 균형을 맞춰요.',
    '위험 관리: 투자 비율을 조절해 흔들림을 줄여요.',
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
    final done =
        state.currentScenario >= scenarios.length &&
        !isPreviewMode &&
        !isReviewMode;
    final realChapter = state.currentScenario >= scenarios.length
        ? scenarios.length
        : (state.currentScenario + 1).clamp(1, scenarios.length);
    final reviewScenarioIndex = isReviewMode
        ? scenarioIndexById(reviewQueue[reviewRoundIndex].scenarioId)
        : null;
    final playScenarioIndex = isReviewMode
        ? (reviewScenarioIndex ?? 0).clamp(0, scenarios.length - 1)
        : isPreviewMode
        ? (previewScenarioIndex ??
                  scenarioIndexByChapter(state.currentScenario))
              .clamp(0, scenarios.length - 1)
        : scenarioIndexByChapter(state.currentScenario);
    final chapterObjective = isReviewMode
        ? '복습 라운드 ${reviewRoundIndex + 1}/${reviewQueue.length}: 틀렸던 부분을 다시 연습해요.'
        : _objectiveForChapter(realChapter);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppDesign.bgTop, AppDesign.secondarySoft, Colors.white],
        ),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(14, 10, 14, media.padding.bottom + 14),
        children: [
          _MascotMapHeader(
            state: state,
            total: scenarios.length,
            mascotEmoji: state.equippedCharacter.emoji,
            homeEmoji: state.equippedHome.emoji,
            isPreviewMode: isPreviewMode,
          ),
          const SizedBox(height: 10),
          _ChapterObjectiveBanner(
            chapter: realChapter,
            objective: chapterObjective,
          ),
          const SizedBox(height: 10),
          if (showPracticeNudge)
            _PracticeStartNudgeBanner(onClose: onPracticeNudgeDismissed),
          if (showPracticeNudge) const SizedBox(height: 10),
          if (isReviewMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '📝 복습 중! 맞히면 오답 노트가 정리돼요.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onStopReview,
                    child: const Text('복습 종료'),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _DifficultySelector(
                  current: state.selectedDifficulty,
                  onChanged: onDifficultyChanged,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A304566),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Tooltip(
                  message: state.soundMuted ? '효과음 켜기' : '효과음 끄기',
                  child: IconButton(
                    onPressed: () => onSoundMutedChanged(!state.soundMuted),
                    icon: Icon(
                      state.soundMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                '탐험 지도',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => onMapExpandedChanged(!state.mapExpanded),
                icon: Icon(
                  state.mapExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                label: Text(state.mapExpanded ? '지도 접기' : '지도 펼치기'),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: _AdventureMapCard(
              state: state,
              totalScenarios: scenarios.length,
              homeEmoji: state.equippedHome.emoji,
              previewScenarioIndex: isPreviewMode ? playScenarioIndex : null,
            ),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDE5F6)),
              ),
              child: const Text(
                '지도를 접었어요. 문제 카드에 집중해볼까? 🧠',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            crossFadeState: state.mapExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
          ),
          const SizedBox(height: 10),
          if (!isReviewMode)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onJumpToDifferentScenario,
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('다른 문제 보기'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppDesign.primarySoft),
                  foregroundColor: AppDesign.primaryDeep,
                ),
              ),
            ),
          if (isPreviewMode)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '🔍 미리보기 모드: 풀이 결과는 실제 챕터 진행/포인트에 반영되지 않아요.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 12),
          if (done)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFFE7FFF2),
                border: Border.all(color: const Color(0xFFB6F1CF)),
              ),
              child: const Text(
                '🏆 모든 챕터를 완주했어요! 리포트 탭에서 핵심 점수 3가지를 확인해보세요.',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            )
          else
            SizedBox(
              height: media.size.height * 0.66,
              child: ScenarioPlayCard(
                key: ValueKey(
                  'scenario-$playScenarioIndex-${state.selectedDifficulty.index}-preview-$isPreviewMode',
                ),
                scenario: scenarios[playScenarioIndex],
                cash: state.cash,
                difficulty: state.selectedDifficulty,
                learnerAgeBand: state.learnerAgeBand,
                chapterCondition: _conditionForNextChapter(),
                soundMuted: state.soundMuted,
                onDone: onDone,
                onWrongAnswer: (stage) =>
                    onWrongAnswer(scenarios[playScenarioIndex], stage),
              ),
            ),
        ],
      ),
    );
  }
}

class _GameFlowTutorialDialog extends StatefulWidget {
  const _GameFlowTutorialDialog();

  @override
  State<_GameFlowTutorialDialog> createState() =>
      _GameFlowTutorialDialogState();
}

class _GameFlowTutorialDialogState extends State<_GameFlowTutorialDialog> {
  int _step = 0;
  int? _sampleIndustry;
  int? _sampleReason;

  static const _steps = [
    ('1/5', '📰 뉴스 보기', '짧은 뉴스를 읽고 어떤 일이 생겼는지 먼저 파악해요.'),
    ('2/5', '✅ 선택하기', '영향 받는 산업을 고르고, 왜 그런지 이유도 골라요.'),
    ('3/5', '🧠 근거 확인', '힌트 버튼으로 다시 생각하고, 근거를 고쳐도 괜찮아요.'),
    ('4/5', '💰 비중 정하기', '20~80% 중에서 투자 비중을 정해요. 너무 크게 넣지 않아도 좋아요.'),
    ('5/5', '🎮 미니 연습문제', '마지막은 실제로 눌러보는 연습문제예요!'),
  ];

  bool get _isLast => _step == _steps.length - 1;
  bool get _sampleDone => _sampleIndustry != null && _sampleReason != null;

  Widget _sampleChoice({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? const Color(0xFFE8F4FF) : Colors.white,
          border: Border.all(
            color: selected ? AppDesign.secondary : const Color(0xFFDCE4F2),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }

  Widget _samplePracticeCard() {
    final industryHint = _sampleIndustry == null
        ? '👉 먼저 아래 산업 버튼 하나 눌러봐!'
        : '좋아! 이제 아래 이유 버튼도 눌러보자.';
    final reasonHint = _sampleReason == null
        ? '👉 이유 버튼을 고르면 연습 완료!'
        : '완료! 이렇게 실제 게임도 같은 흐름이야.';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '연습 뉴스: 날씨가 갑자기 추워져서 난방을 많이 켰어요.',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            'Q1. 어디가 도움을 받을까?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          _sampleChoice(
            text: '난방 기계 파는 곳',
            selected: _sampleIndustry == 0,
            onTap: () => setState(() => _sampleIndustry = 0),
          ),
          _sampleChoice(
            text: '아이스크림 가게',
            selected: _sampleIndustry == 1,
            onTap: () => setState(() => _sampleIndustry = 1),
          ),
          const SizedBox(height: 4),
          Text(
            industryHint,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4C5B77),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Q2. 그렇게 생각한 이유는?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          _sampleChoice(
            text: '추우면 난방을 더 많이 써서 관련 물건을 더 살 수 있어요.',
            selected: _sampleReason == 0,
            onTap: () => setState(() => _sampleReason = 0),
          ),
          _sampleChoice(
            text: '친구가 그냥 좋다고 해서요.',
            selected: _sampleReason == 1,
            onTap: () => setState(() => _sampleReason = 1),
          ),
          const SizedBox(height: 4),
          Text(
            reasonHint,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4C5B77),
            ),
          ),
          if (_sampleDone)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9FFF1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFECD1)),
              ),
              child: Text(
                _sampleIndustry == 0 && _sampleReason == 0
                    ? '정확해! 뉴스 → 산업 → 이유 순서로 잘 골랐어.'
                    : '좋은 시도야! 실제 게임에선 정답보다 근거가 얼마나 맞는지가 점수가 돼.',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _steps[_step];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              current.$1,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppDesign.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              current.$2,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              current.$3,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_isLast) _samplePracticeCard(),
            if (!_isLast)
              const Text(
                '처음 한 번만 보여요. 바로 시작하고 싶으면 건너뛰기를 눌러도 돼요.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: (_step + 1) / _steps.length,
                backgroundColor: const Color(0xFFE8EEFB),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('건너뛰기'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    if (_isLast) {
                      if (!_sampleDone) return;
                      Navigator.pop(context, true);
                      return;
                    }
                    setState(() => _step += 1);
                  },
                  child: Text(
                    _isLast
                        ? (_sampleDone ? '연습 완료!' : '버튼 눌러서 연습 완료하기')
                        : '다음',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeStartNudgeBanner extends StatelessWidget {
  const _PracticeStartNudgeBanner({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5D6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDF8A)),
      ),
      child: Row(
        children: [
          const Text('👉', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '여기서 첫 연습문제를 시작해요! 아래 카드에서 차근차근 풀어보세요.',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
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
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFFFF4D9),
        border: Border.all(color: const Color(0xFFFFE18A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '챕터 $chapter 핵심 목표\n$objective',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xFF4A3D1B),
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
    required this.isPreviewMode,
  });

  final AppState state;
  final int total;
  final String mascotEmoji;
  final String homeEmoji;
  final bool isPreviewMode;

  @override
  Widget build(BuildContext context) {
    final chapter = state.currentScenario + 1 > total
        ? total
        : state.currentScenario + 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [AppDesign.primaryDeep, AppDesign.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40426DFF),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
            ),
            child: Center(
              child: Image.asset(
                'assets/branding/mascot_icon_transparent.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Text(mascotEmoji, style: const TextStyle(fontSize: 29)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPreviewMode
                      ? '탐험맵 챕터 $chapter / $total · 미리보기 중'
                      : '탐험맵 챕터 $chapter / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$homeEmoji 베이스 · ${state.cash}코인 · ${state.rewardPoints}P',
                  style: const TextStyle(
                    color: Color(0xFFE8EDFF),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14304566),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: DifficultyLevel.values
            .map(
              (d) => Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: current == d
                          ? const LinearGradient(
                              colors: [
                                AppDesign.primaryDeep,
                                AppDesign.secondary,
                              ],
                            )
                          : null,
                      color: current == d ? null : const Color(0xFFF2F5FB),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${d.icon} ${d.label}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: current == d
                                ? Colors.white
                                : const Color(0xFF3F496A),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.questName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: current == d
                                ? const Color(0xFFE5E9FF)
                                : const Color(0xFF7C86A3),
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
    required this.previewScenarioIndex,
  });

  final AppState state;
  final int totalScenarios;
  final String homeEmoji;
  final int? previewScenarioIndex;

  static const List<String> _chapterThemes = [
    '기회비용 기초',
    '수혜·피해 찾기',
    '분산 투자 연습',
    '위험 조절',
    '흔들림 대응',
  ];

  @override
  Widget build(BuildContext context) {
    final points = List.generate(totalScenarios, (i) {
      final x = (i % 5) / 4;
      final y = i < 5 ? 0.25 : 0.75;
      return Offset(i < 5 ? x : 1 - x, y);
    });
    final completedCount = state.currentScenario.clamp(0, totalScenarios);
    final remainingCount = (totalScenarios - completedCount).clamp(
      0,
      totalScenarios,
    );
    final currentNodeIndex =
        previewScenarioIndex ??
        state.currentScenario.clamp(0, totalScenarios - 1);
    final currentTheme =
        _chapterThemes[currentNodeIndex % _chapterThemes.length];

    return Container(
      height: 178,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFF5EEFF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F314566),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, c) {
            return Stack(
              children: [
                Positioned(
                  right: 2,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '현재 위치 $homeEmoji',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  size: Size(c.maxWidth, c.maxHeight),
                  painter: _MapPathPainter(
                    points: points,
                    completedCount: completedCount,
                  ),
                ),
                ...List.generate(points.length, (i) {
                  final p = points[i];
                  final status = i < completedCount
                      ? _NodeState.done
                      : i == currentNodeIndex
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
                    left: p.dx * (c.maxWidth - 34),
                    top: p.dy * (c.maxHeight - 34),
                    child: _MapNode(
                      index: i + 1,
                      state: status,
                      icon: zoneIcons[i % zoneIcons.length],
                      theme: _chapterThemes[i % _chapterThemes.length],
                    ),
                  );
                }),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 6,
                    spacing: 6,
                    children: [
                      _MapInfoPill(
                        label: '완료 $completedCount개',
                        color: const Color(0xFFE7FFF0),
                      ),
                      _MapInfoPill(
                        label: '남음 $remainingCount개',
                        color: const Color(0xFFF2F5FF),
                      ),
                      _MapInfoPill(
                        label: '지금 학습: $currentTheme',
                        color: const Color(0xFFFFF4E3),
                      ),
                    ],
                  ),
                ),
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
    required this.theme,
  });

  final int index;
  final _NodeState state;
  final String icon;
  final String theme;

  @override
  Widget build(BuildContext context) {
    final bg = switch (state) {
      _NodeState.done => AppDesign.success,
      _NodeState.current => AppDesign.secondary,
      _NodeState.locked => const Color(0xFFC8D4E2),
    };

    return Tooltip(
      message: '챕터 $index · $theme',
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: state == _NodeState.current
                ? const Color(0xFFFFD44A)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: state == _NodeState.done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
              : Text(icon, style: const TextStyle(fontSize: 15)),
        ),
      ),
    );
  }
}

class _MapInfoPill extends StatelessWidget {
  const _MapInfoPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
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
      ..color = const Color(0xFF43C97C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final todoPaint = Paint()
      ..color = const Color(0x809DB2C6)
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
    required this.onWrongAnswer,
  });

  final Scenario scenario;
  final int cash;
  final DifficultyLevel difficulty;
  final LearnerAgeBand learnerAgeBand;
  final ChapterCondition chapterCondition;
  final bool soundMuted;
  final ValueChanged<ScenarioResult> onDone;
  final ValueChanged<WrongStageType> onWrongAnswer;

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
    '도움+피해를 함께 보고 나눠서 계획 세우기',
  ];

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
        '힌트: 도움 ${s.goodIndustries.join(', ')} / 주의 ${s.badIndustries.join(', ')}',
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

  List<String> _webAudioCandidates(String assetRelativePath) {
    final mp3Path = assetRelativePath.endsWith('.wav')
        ? assetRelativePath.replaceFirst('.wav', '.mp3')
        : assetRelativePath;
    return [assetRelativePath, mp3Path];
  }

  Future<void> _playSfxAsset(
    String assetRelativePath, {
    double volume = 1,
  }) async {
    if (widget.soundMuted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔇 효과음이 꺼져 있어요 (우상단 스피커 버튼)')),
        );
      }
      return;
    }

    final player = kIsWeb ? AudioPlayer() : _sfxPlayer;

    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      if (kIsWeb) {
        for (final path in _webAudioCandidates(assetRelativePath)) {
          for (final prefix in const ['assets/assets/', 'assets/']) {
            try {
              final webAssetUrl = Uri.base.resolve('$prefix$path').toString();
              await player.play(UrlSource(webAssetUrl));
              if (kIsWeb) {
                await player.dispose();
              }
              return;
            } catch (_) {}
          }
        }
      } else {
        try {
          await player.play(AssetSource(assetRelativePath));
          return;
        } catch (_) {
          await player.play(AssetSource('assets/$assetRelativePath'));
          return;
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ 효과음 재생 실패 (기기 무음/브라우저 정책 확인)')),
        );
      }
    } finally {
      if (kIsWeb) {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
  }

  Future<void> _playSelectSfx() =>
      _playSfxAsset('audio/correct_beep.wav', volume: 0.45);

  Future<void> _playFeedbackSfx(bool isCorrect) => _playSfxAsset(
    isCorrect ? 'audio/correct_beep.wav' : 'audio/wrong_beep.wav',
  );

  Widget _stepProgress() {
    const totalSteps = 5;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppDesign.primaryDeep, AppDesign.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B4F68FF),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '진행 단계 ${_stage + 1}/$totalSteps',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (_stage + 1) / totalSteps,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _mascotSpeech,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8EDFF),
            ),
          ),
        ],
      ),
    );
  }

  void _selectWithSfx(VoidCallback updater) {
    if (_submitted) return;
    _playSelectSfx();
    setState(updater);
  }

  Future<void> _confirmCurrentStep() async {
    if (_stage == 0) {
      if (_selectedIndustry == null) return;
      final ok = _industryChoices[_selectedIndustry!].score >= 70;
      await _playFeedbackSfx(ok);
      if (!mounted) return;
      if (!ok) {
        widget.onWrongAnswer(WrongStageType.industry);
      }
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
      if (!ok) {
        widget.onWrongAnswer(WrongStageType.reasoning);
      }
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
      if (!ok) {
        widget.onWrongAnswer(WrongStageType.quiz);
      }
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
            : '하드 모드 팁: 잘 맞아도 비율을 나눠 흔들림 충격을 줄여요.',
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
            ? '${explanation.short} "$selectedIndustryLabel" 선택은 뉴스와 산업의 연결이 알맞아요.'
            : '좋은 점: "$selectedReasoningLabel"으로 예상 그림을 세우고 생각한 점이 좋아요.',
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
            ? '${explanation.risk} 현재 비중 $allocationPercent%는 흔들림을 생각해 조절이 필요해요.'
            : '${explanation.why} "$selectedReasoningLabel"에 먼저 보이는 자료/지속 기간 근거를 더해요.',
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
      widget.onWrongAnswer(WrongStageType.finalDecision);
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
        duration: const Duration(milliseconds: 170),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? const LinearGradient(
                  colors: [AppDesign.secondarySoft, Color(0xFFE9FBFF)],
                )
              : null,
          color: selected ? null : Colors.white,
          border: Border.all(
            color: selected ? AppDesign.secondary : AppDesign.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1F4A67D3),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected
                  ? const Color(0xFF675EFF)
                  : const Color(0xFFA2ABC1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
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
                  : () => _selectWithSfx(() {
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
                    : (_) => _selectWithSfx(() => _oxAnswer = true),
              ),
              ChoiceChip(
                label: const Text('❌ X'),
                selected: _oxAnswer == false,
                onSelected: _submitted
                    ? null
                    : (_) => _selectWithSfx(() => _oxAnswer = false),
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
                        : () => _selectWithSfx(() {
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
                        : () => _selectWithSfx(() {
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
                          : (_) => _selectWithSfx(
                              () => _matchAnswers[i] = targetIndex,
                            ),
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
        title: '문제 1',
        child: Column(
          children: [
            _scenarioHeadline(s),
            ...List.generate(
              _industryChoices.length,
              (i) => _choiceTile(
                text: _industryChoices[i].label,
                selected: _selectedIndustry == i,
                onTap: _submitted
                    ? null
                    : () => _selectWithSfx(() => _selectedIndustry = i),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _selectedIndustry == null || _submitted
                  ? null
                  : _confirmCurrentStep,
              child: const Text('다음'),
            ),
          ],
        ),
      );
    } else if (_stage == 1) {
      stepCard = _gameSection(
        title: '문제 2',
        child: Column(
          children: [
            _scenarioHeadline(s),
            ...List.generate(
              _reasoningChoices.length,
              (i) => _choiceTile(
                text: _reasoningChoices[i],
                selected: _reasoningAnswer == i,
                onTap: _submitted
                    ? null
                    : () => _selectWithSfx(() => _reasoningAnswer = i),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _reasoningAnswer == null || _submitted
                  ? null
                  : _confirmCurrentStep,
              child: const Text('다음'),
            ),
          ],
        ),
      );
    } else if (_stage == 2) {
      stepCard = _gameSection(
        title: '문제 3',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _scenarioHeadline(s),
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
              onPressed: !_isQuizAnswered || _submitted
                  ? null
                  : _confirmCurrentStep,
              child: const Text('다음'),
            ),
          ],
        ),
      );
    } else if (_stage == 3) {
      stepCard = _gameSection(
        title: '투자 비중',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _scenarioHeadline(s),
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
                  onSelected: _submitted
                      ? null
                      : (_) => _selectWithSfx(() => _allocationPercent = v),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _allocation == null ? '비중을 골라주세요.' : '투자금 $_investedCoins코인',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: (_submitted || _allocation == null) ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.check_circle),
              label: Text('제출'),
            ),
          ],
        ),
      );
    } else {
      stepCard = _gameSection(
        title: '결과 카드',
        child: Column(
          children: [
            if (_resultSnapshot != null)
              _PerformanceResultCard(snapshot: _resultSnapshot!),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _pendingResult == null
                  ? null
                  : () {
                      final next = _pendingResult;
                      if (next != null) widget.onDone(next);
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppDesign.primaryDeep,
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
      children: [_stepProgress(), const SizedBox(height: 10), stepCard],
    );
  }

  Widget _scenarioHeadline(Scenario s) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3F7FF), Color(0xFFF7F2FF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '챕터 ${s.id}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5B688F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _gameSection({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17304066),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5A62E8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
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
      return '좋아! 다음엔 위험 관리만 조금 더 다듬으면 더 탄탄해져.';
    }
    return '괜찮아, 탐험은 연습이야! 투자 비율을 조절하면 더 안정적으로 갈 수 있어.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppDesign.surfaceSoft, AppDesign.secondarySoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppDesign.border),
        boxShadow: AppDesign.cardShadow,
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
              _metricChip('흔들림/위험', '${snapshot.volatilityRisk}'),
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
        wallGradient: [AppDesign.bgTop, Color(0xFFDCE6FF)],
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
    required this.onDecorationAdjusted,
    required this.onCharacterAdjusted,
    required this.onThemeNameChanged,
    required this.onEquipHome,
    required this.onSelectMinimiPreset,
    required this.onResetMinimi,
    required this.onMinimiCalibrationChanged,
    required this.onSaveMinimiCalibration,
    required this.onResetMinimiCalibration,
    required this.onSetMinimiCalibrationDefault,
  });

  final AppState state;
  final String? syncMessage;
  final StoredSession? session;
  final void Function(DecorationZone zone, String? itemId) onPlaceDecoration;
  final void Function(DecorationZone zone, RoomItemAdjustment adjustment)
  onDecorationAdjusted;
  final ValueChanged<RoomItemAdjustment> onCharacterAdjusted;
  final ValueChanged<String> onThemeNameChanged;
  final ValueChanged<ShopItem> onEquipHome;
  final void Function(MinimiCategory category, String itemId)
  onSelectMinimiPreset;
  final VoidCallback onResetMinimi;
  final ValueChanged<MinimiCalibration> onMinimiCalibrationChanged;
  final ValueChanged<MinimiCalibration> onSaveMinimiCalibration;
  final VoidCallback onResetMinimiCalibration;
  final ValueChanged<MinimiCalibration> onSetMinimiCalibrationDefault;

  @override
  State<_MyHomeTab> createState() => _MyHomeTabState();
}

class _MyHomeTabState extends State<_MyHomeTab> {
  bool _showEquipFx = false;
  bool _lockMyHomeScroll = false;
  String _equipFxLabel = '장착 완료!';
  late final TextEditingController _themeNameController;

  @override
  void initState() {
    super.initState();
    _themeNameController = TextEditingController(
      text: widget.state.homeThemeName,
    );
  }

  @override
  void dispose() {
    _themeNameController.dispose();
    super.dispose();
  }

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
    if (_themeNameController.text != widget.state.homeThemeName) {
      _themeNameController.text = widget.state.homeThemeName;
    }
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          _MinimiMvpCard(
            cosmetics: state.minimiCosmetics,
            calibration: state.minimiCalibration,
            onSelectPreset: widget.onSelectMinimiPreset,
            onReset: widget.onResetMinimi,
            onCalibrationChanged: widget.onMinimiCalibrationChanged,
            onCalibrationSave: widget.onSaveMinimiCalibration,
            onCalibrationReset: widget.onResetMinimiCalibration,
            onCalibrationSetDefault: widget.onSetMinimiCalibrationDefault,
          ),
        ],
      ),
    );
  }
}

class _MinimiMvpCard extends StatefulWidget {
  const _MinimiMvpCard({
    required this.cosmetics,
    required this.calibration,
    required this.onSelectPreset,
    required this.onReset,
    required this.onCalibrationChanged,
    required this.onCalibrationSave,
    required this.onCalibrationReset,
    required this.onCalibrationSetDefault,
  });

  final MinimiCosmeticState cosmetics;
  final MinimiCalibration calibration;
  final void Function(MinimiCategory category, String itemId) onSelectPreset;
  final VoidCallback onReset;
  final ValueChanged<MinimiCalibration> onCalibrationChanged;
  final ValueChanged<MinimiCalibration> onCalibrationSave;
  final VoidCallback onCalibrationReset;
  final ValueChanged<MinimiCalibration> onCalibrationSetDefault;

  @override
  State<_MinimiMvpCard> createState() => _MinimiMvpCardState();
}

class _MinimiMvpCardState extends State<_MinimiMvpCard> {
  MinimiCategory _category = MinimiCategory.hair;
  MinimiCategory _calibrationSection = MinimiCategory.hair;
  bool _calibrationMode = true;
  bool _mobileCalibrationPanelCollapsed = false;
  late final TextEditingController _jsonController;
  String? _jsonMessage;

  MinimiCalibration get _calibration => widget.calibration;

  @override
  void initState() {
    super.initState();
    _jsonController = TextEditingController();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  void _changeCalibration(MinimiCalibration next) {
    widget.onCalibrationChanged(next);
  }

  Future<void> _exportCalibrationJson() async {
    final jsonText = const JsonEncoder.withIndent(
      '  ',
    ).convert(_calibration.toJson());
    await Clipboard.setData(ClipboardData(text: jsonText));
    if (!mounted) return;
    setState(() {
      _jsonController.text = jsonText;
      _jsonMessage = '현재 calibration JSON을 복사했어요.';
    });
  }

  void _importCalibrationJson() {
    final raw = _jsonController.text.trim();
    if (raw.isEmpty) {
      setState(() => _jsonMessage = 'JSON을 입력해 주세요.');
      return;
    }
    final backup = _calibration;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        setState(() => _jsonMessage = 'JSON 형식이 올바르지 않아요.');
        return;
      }
      final next = MinimiCalibration.fromJson(
        decoded.cast<String, dynamic>(),
        fallback: backup,
      );
      final hadClamp = jsonEncode(next.toJson()) != jsonEncode(decoded);
      widget.onCalibrationChanged(next);
      setState(() {
        _jsonMessage = hadClamp ? '적용 완료(일부 값은 허용 범위로 자동 보정됨).' : 'JSON 적용 완료.';
      });
    } catch (_) {
      widget.onCalibrationChanged(backup);
      setState(() => _jsonMessage = 'JSON 파싱 실패: 형식을 확인해 주세요.');
    }
  }

  Widget _buildCalibrationRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    final text = suffix == 'x'
        ? value.toStringAsFixed(2)
        : value.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label ($text$suffix)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => onChanged((value - step).clamp(min, max)),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            IconButton(
              onPressed: () => onChanged((value + step).clamp(min, max)),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<Widget> _buildSectionCalibrationControls() {
    switch (_calibrationSection) {
      case MinimiCategory.hair:
        return [
          _buildCalibrationRow(
            label: 'hairY',
            value: _calibration.hairY,
            min: MinimiCalibration.minOffset,
            max: MinimiCalibration.maxOffset,
            step: 1,
            suffix: 'px',
            onChanged: (v) =>
                _changeCalibration(_calibration.copyWith(hairY: v)),
          ),
          _buildCalibrationRow(
            label: 'hairScale',
            value: _calibration.hairScale,
            min: MinimiCalibration.minScale,
            max: MinimiCalibration.maxScale,
            step: 0.01,
            suffix: 'x',
            onChanged: (v) =>
                _changeCalibration(_calibration.copyWith(hairScale: v)),
          ),
        ];
      case MinimiCategory.top:
        return [
          _buildCalibrationRow(
            label: 'topY',
            value: _calibration.topY,
            min: MinimiCalibration.minOffset,
            max: MinimiCalibration.maxOffset,
            step: 1,
            suffix: 'px',
            onChanged: (v) =>
                _changeCalibration(_calibration.copyWith(topY: v)),
          ),
          _buildCalibrationRow(
            label: 'topScale',
            value: _calibration.topScale,
            min: MinimiCalibration.minScale,
            max: MinimiCalibration.maxScale,
            step: 0.01,
            suffix: 'x',
            onChanged: (v) =>
                _changeCalibration(_calibration.copyWith(topScale: v)),
          ),
        ];
      case MinimiCategory.accessory:
        return [
          _buildCalibrationRow(
            label: 'accessoryY',
            value: _calibration.accessoryY,
            min: MinimiCalibration.minOffset,
            max: MinimiCalibration.maxOffset,
            step: 1,
            suffix: 'px',
            onChanged: (v) =>
                _changeCalibration(_calibration.copyWith(accessoryY: v)),
          ),
          _buildCalibrationRow(
            label: 'accessoryScale',
            value: _calibration.accessoryScale,
            min: MinimiCalibration.minScale,
            max: MinimiCalibration.maxScale,
            step: 0.01,
            suffix: 'x',
            onChanged: (v) =>
                _changeCalibration(_calibration.copyWith(accessoryScale: v)),
          ),
        ];
    }
  }

  Widget _buildCalibrationPanel({required bool isMobile}) {
    final sectionControls = _buildSectionCalibrationControls();
    final controls = [
      const Text(
        '조정 섹션 (Body는 항상 표시)',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: MinimiCategory.values.map((category) {
          return ChoiceChip(
            label: Text(category.label),
            selected: _calibrationSection == category,
            onSelected: (_) => setState(() => _calibrationSection = category),
          );
        }).toList(),
      ),
      const SizedBox(height: 8),
      _buildCalibrationRow(
        label: 'bodyY',
        value: _calibration.bodyY,
        min: MinimiCalibration.minOffset,
        max: MinimiCalibration.maxOffset,
        step: 1,
        suffix: 'px',
        onChanged: (v) => _changeCalibration(_calibration.copyWith(bodyY: v)),
      ),
      _buildCalibrationRow(
        label: 'bodyScale',
        value: _calibration.bodyScale,
        min: MinimiCalibration.minScale,
        max: MinimiCalibration.maxScale,
        step: 0.01,
        suffix: 'x',
        onChanged: (v) =>
            _changeCalibration(_calibration.copyWith(bodyScale: v)),
      ),
      ...sectionControls,
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onCalibrationReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('기본값 복원'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => widget.onCalibrationSave(_calibration),
              icon: const Icon(Icons.save_rounded),
              label: const Text('현재값 저장'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exportCalibrationJson,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('내보내기(JSON)'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => widget.onCalibrationSetDefault(_calibration),
              icon: const Icon(Icons.push_pin_rounded),
              label: const Text('이 값을 기준값으로 사용'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _jsonController,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: '가져오기 JSON',
          hintText: '{"bodyY":0,"bodyScale":1.0,...}',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _importCalibrationJson,
              icon: const Icon(Icons.download_rounded),
              label: const Text('가져오기 적용'),
            ),
          ),
        ],
      ),
      if (_jsonMessage != null) ...[
        const SizedBox(height: 4),
        Text(
          _jsonMessage!,
          style: TextStyle(
            fontSize: 12,
            color:
                _jsonMessage!.contains('실패') || _jsonMessage!.contains('올바르지')
                ? Colors.red.shade700
                : Colors.blueGrey.shade700,
          ),
        ),
      ],
    ];

    if (!isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: controls,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: const Color(0x66F7FAFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x66DDE8F8)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controls,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    final presets = kMinimiPresetByCategory[_category] ?? const [];
    final selectedId = widget.cosmetics.selectedId(_category);
    final hair = (kMinimiPresetByCategory[MinimiCategory.hair] ?? const [])
        .firstWhere(
          (e) => e.id == widget.cosmetics.selectedId(MinimiCategory.hair),
        );
    final top = (kMinimiPresetByCategory[MinimiCategory.top] ?? const [])
        .firstWhere(
          (e) => e.id == widget.cosmetics.selectedId(MinimiCategory.top),
        );
    final accessory =
        (kMinimiPresetByCategory[MinimiCategory.accessory] ?? const [])
            .firstWhere(
              (e) =>
                  e.id == widget.cosmetics.selectedId(MinimiCategory.accessory),
            );
    final previewCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE8F8)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 170,
            child: _MinimiPreviewComposite(
              hairId: hair.id,
              topId: top.id,
              accessoryId: accessory.id,
              calibration: _calibration,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${hair.label} · ${top.label} · ${accessory.label}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.face_6_rounded, color: AppDesign.secondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '미니미 꾸미기',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onReset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('기본값'),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('정렬 조정 모드'),
            subtitle: const Text('body/hair/top/accessory 위치·스케일 조정'),
            value: _calibrationMode,
            onChanged: (v) => setState(() => _calibrationMode = v),
          ),
          const SizedBox(height: 8),
          if (isMobile && _calibrationMode)
            Stack(
              children: [
                previewCard,
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState: _mobileCalibrationPanelCollapsed
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0x59FFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x66DDE8F8)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                ),
                                title: const Text(
                                  '정렬 오버레이 패널',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: const Text(
                                  '프리뷰는 항상 보이고, 값은 실시간 반영돼요.',
                                  style: TextStyle(fontSize: 11),
                                ),
                                trailing: IconButton(
                                  onPressed: () => setState(
                                    () =>
                                        _mobileCalibrationPanelCollapsed = true,
                                  ),
                                  icon: const Icon(Icons.expand_more_rounded),
                                  tooltip: '패널 접기',
                                ),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: _buildCalibrationPanel(isMobile: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    secondChild: Align(
                      alignment: Alignment.bottomRight,
                      child: FilledButton.icon(
                        onPressed: () => setState(
                          () => _mobileCalibrationPanelCollapsed = false,
                        ),
                        icon: const Icon(Icons.expand_less_rounded, size: 18),
                        label: const Text('조정 패널 펼치기'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xD91E3A8A),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            previewCard,
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: MinimiCategory.values.map((category) {
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(category.icon, size: 16),
                    const SizedBox(width: 4),
                    Text(category.label),
                  ],
                ),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((preset) {
              return ChoiceChip(
                label: Text('${preset.emoji} ${preset.label}'),
                selected: selectedId == preset.id,
                onSelected: (_) => widget.onSelectPreset(_category, preset.id),
              );
            }).toList(),
          ),
          if (_calibrationMode && !isMobile) ...[
            const SizedBox(height: 12),
            _buildCalibrationPanel(isMobile: false),
          ],
        ],
      ),
    );
  }
}

class _MinimiPreviewComposite extends StatelessWidget {
  const _MinimiPreviewComposite({
    required this.hairId,
    required this.topId,
    required this.accessoryId,
    required this.calibration,
  });

  final String hairId;
  final String topId;
  final String accessoryId;
  final MinimiCalibration calibration;

  @override
  Widget build(BuildContext context) {
    final layers = _buildMinimiRenderLayers(
      hairId: hairId,
      topId: topId,
      accessoryId: accessoryId,
      calibration: calibration,
    );

    return SizedBox(
      width: _kMinimiPreviewCanvasSize.width,
      height: _kMinimiPreviewCanvasSize.height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          for (final layer in layers)
            Transform.translate(
              offset: layer.offset,
              child: Transform.scale(
                scale: layer.scale,
                alignment: Alignment.center,
                child: Image.asset(
                  layer.assetPath,
                  fit: BoxFit.contain,
                  width: _kMinimiPreviewCanvasSize.width,
                  height: _kMinimiPreviewCanvasSize.height,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomAnchor {
  const _RoomAnchor(
    this.alignment,
    this.size,
    this.depth, {
    this.translationPivot = const Offset(0.5, 0.5),
  });

  final Alignment alignment;
  final Size size;
  final int depth;
  final Offset translationPivot;

  bool get isFootpointBased => translationPivot.dy >= 0.9;
}

class _RoomPlacedItem {
  const _RoomPlacedItem({
    required this.item,
    required this.anchor,
    required this.zone,
    required this.adjustment,
  });

  final ShopItem item;
  final _RoomAnchor anchor;
  final DecorationZone zone;
  final RoomItemAdjustment adjustment;
}

class _RoomObjectTransform {
  const _RoomObjectTransform({
    required this.anchor,
    required this.adjustment,
    required this.canvasSize,
  });

  final _RoomAnchor anchor;
  final RoomItemAdjustment adjustment;
  final Size canvasSize;

  double get width => anchor.size.width * adjustment.scale;
  double get height => anchor.size.height * adjustment.scale;

  double get left {
    if (anchor.isFootpointBased) {
      final targetX = canvasSize.width * ((anchor.alignment.x + 1) / 2);
      return targetX -
          (width * anchor.translationPivot.dx) +
          adjustment.offsetX;
    }
    return (canvasSize.width - width) * ((anchor.alignment.x + 1) / 2) +
        adjustment.offsetX;
  }

  double get top {
    if (anchor.isFootpointBased) {
      final targetY = canvasSize.height * ((anchor.alignment.y + 1) / 2);
      return targetY -
          (height * anchor.translationPivot.dy) +
          adjustment.offsetY;
    }
    return (canvasSize.height - height) * ((anchor.alignment.y + 1) / 2) +
        adjustment.offsetY;
  }

  Offset get worldFootPoint => Offset(
    left + (width * anchor.translationPivot.dx),
    top + (height * anchor.translationPivot.dy),
  );

  Rect get worldRect => Rect.fromLTWH(left, top, width, height);

  Matrix4 get objectToWorld => Matrix4.identity()
    ..translateByDouble(left, top, 0, 1)
    ..scaleByDouble(width, height, 1, 1);

  Matrix4? get worldToObject {
    final inverted = Matrix4.copy(objectToWorld);
    final ok = inverted.invert();
    return ok != 0 ? inverted : null;
  }

  Offset objectToWorldPoint(Offset objectPoint) {
    return MatrixUtils.transformPoint(objectToWorld, objectPoint);
  }

  Offset? worldToObjectPoint(Offset worldPoint) {
    final inverse = worldToObject;
    if (inverse == null) return null;
    return MatrixUtils.transformPoint(inverse, worldPoint);
  }

  _RoomObjectTransform copyWithAdjustment(RoomItemAdjustment nextAdjustment) {
    return _RoomObjectTransform(
      anchor: anchor,
      adjustment: nextAdjustment,
      canvasSize: canvasSize,
    );
  }
}

class _RoomTarget {
  const _RoomTarget.decoration(this.zone)
    : isCharacter = false,
      rect = Rect.zero;

  const _RoomTarget.character()
    : zone = null,
      isCharacter = true,
      rect = Rect.zero;

  final DecorationZone? zone;
  final bool isCharacter;
  final Rect rect;

  _RoomTarget withRect(Rect nextRect) =>
      _RoomTarget._(zone, isCharacter, nextRect);

  const _RoomTarget._(this.zone, this.isCharacter, this.rect);

  String get key => isCharacter ? 'character' : 'zone:${zone!.name}';
}

class _AlphaMaskData {
  const _AlphaMaskData({
    required this.width,
    required this.height,
    required this.alpha,
  });

  final int width;
  final int height;
  final Uint8List alpha;

  MiniRoomMappedPoint? mapWorldPointToPixel(
    Offset worldPoint,
    _RoomObjectTransform transform,
  ) {
    return MiniRoomImageMapper.mapWorldPointToPixelWithTransform(
      worldPoint: worldPoint,
      worldToObject: transform.worldToObject,
      imageWidth: width,
      imageHeight: height,
    );
  }

  bool hitTest(
    Offset worldPoint,
    _RoomObjectTransform transform, {
    required int threshold,
  }) {
    final mapped = mapWorldPointToPixel(worldPoint, transform);
    if (mapped == null) return false;
    final px = mapped.pixel.dx.toInt();
    final py = mapped.pixel.dy.toInt();
    final alphaValue = alpha[(py * width) + px];
    return alphaValue > threshold;
  }
}

class _MyHomeRoomCard extends StatelessWidget {
  const _MyHomeRoomCard({
    required this.state,
    required this.itemById,
    required this.showEquipFx,
    required this.equipFxLabel,
    required this.onDecorationAdjusted,
    required this.onCharacterAdjusted,
    required this.onInteractionLockChanged,
  });

  final AppState state;
  final ShopItem? Function(String? id) itemById;
  final bool showEquipFx;
  final String equipFxLabel;
  final void Function(DecorationZone zone, RoomItemAdjustment adjustment)
  onDecorationAdjusted;
  final ValueChanged<RoomItemAdjustment> onCharacterAdjusted;
  final ValueChanged<bool> onInteractionLockChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '마이룸 인라인 편집',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '오브젝트를 직접 터치해 위치/크기를 조절해요.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 1.32,
              child: _MiniRoomInlineEditor(
                state: state,
                itemById: itemById,
                showEquipFx: showEquipFx,
                equipFxLabel: equipFxLabel,
                onDecorationAdjusted: onDecorationAdjusted,
                onCharacterAdjusted: onCharacterAdjusted,
                onInteractionLockChanged: onInteractionLockChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniRoomInlineEditor extends StatefulWidget {
  const _MiniRoomInlineEditor({
    required this.state,
    required this.itemById,
    required this.showEquipFx,
    required this.equipFxLabel,
    required this.onDecorationAdjusted,
    required this.onCharacterAdjusted,
    required this.onInteractionLockChanged,
  });

  final AppState state;
  final ShopItem? Function(String? id) itemById;
  final bool showEquipFx;
  final String equipFxLabel;
  final void Function(DecorationZone zone, RoomItemAdjustment adjustment)
  onDecorationAdjusted;
  final ValueChanged<RoomItemAdjustment> onCharacterAdjusted;
  final ValueChanged<bool> onInteractionLockChanged;

  @override
  State<_MiniRoomInlineEditor> createState() => _MiniRoomInlineEditorState();
}

class _MiniRoomInlineEditorState extends State<_MiniRoomInlineEditor>
    with SingleTickerProviderStateMixin {
  static const Map<DecorationZone, _RoomAnchor> _anchors = {
    DecorationZone.wall: _RoomAnchor(Alignment(-0.06, -0.60), Size(72, 46), 1),
    DecorationZone.window: _RoomAnchor(Alignment(0.66, -0.42), Size(64, 46), 2),
    DecorationZone.shelf: _RoomAnchor(Alignment(-0.70, -0.02), Size(72, 61), 3),
    DecorationZone.desk: _RoomAnchor(Alignment(0.44, 0.28), Size(102, 71), 4),
    DecorationZone.floor: _RoomAnchor(Alignment(-0.18, 0.70), Size(124, 67), 5),
  };
  static const _characterAnchor = _RoomAnchor(
    Alignment(0.03, 0.72),
    Size(68, 68),
    4,
    translationPivot: Offset(0.5, 0.96),
  );
  static const int _alphaHitThreshold = 40;
  static const Set<String> _edgeCleanupItemIds = {
    'char_default',
    'deco_wall_frame',
    'deco_wall_chart',
    'deco_floor_coinbox',
    'deco_window_curtain',
  };

  final Map<String, _AlphaMaskData?> _alphaMaskCache =
      <String, _AlphaMaskData?>{};
  final Set<String> _alphaMaskLoading = <String>{};
  final GlobalKey _miniRoomCanvasKey = GlobalKey();
  _RoomTarget? _selectedTarget;
  _TouchSession? _touchSession;
  late Map<DecorationZone, RoomItemAdjustment> _draftDecorationAdjustments;
  late RoomItemAdjustment _draftCharacterAdjustment;
  late final AnimationController _selectionPulseController;
  bool _debugHitOverlayVisible = false;
  Offset? _debugWorldTouchPoint;
  Offset? _debugRawTouchPoint;
  Offset? _debugLocalPoint;
  Rect? _debugVisualRect;
  String? _debugCalibrationSummary;
  final List<String> _touchTraceLines = <String>[];

  @override
  void initState() {
    super.initState();
    _draftDecorationAdjustments = {
      for (final zone in DecorationZone.values)
        zone:
            widget.state.decorationAdjustments[zone] ??
            RoomItemAdjustment.defaults,
    };
    _draftCharacterAdjustment = widget.state.characterAdjustment;
    _selectionPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..repeat(reverse: true);
    unawaited(_warmupAlphaMasks());
  }

  @override
  void dispose() {
    widget.onInteractionLockChanged(false);
    _selectionPulseController.dispose();
    super.dispose();
  }

  Future<void> _warmupAlphaMasks() async {
    final warmupItems = <ShopItem>{widget.state.equippedCharacter};
    for (final zone in DecorationZone.values) {
      final id = widget.state.equippedDecorations[zone];
      final item = widget.itemById(id);
      if (item != null) warmupItems.add(item);
    }
    for (final item in warmupItems) {
      await _ensureAlphaMask(item);
    }
  }

  Future<void> _ensureAlphaMask(ShopItem item) async {
    final id = item.id;
    if (_alphaMaskCache.containsKey(id) || _alphaMaskLoading.contains(id)) {
      return;
    }
    final assetPath = _miniroomSpecForItem(item).assetPath;
    if (assetPath == null) {
      _alphaMaskCache[id] = null;
      return;
    }
    _alphaMaskLoading.add(id);
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) {
        _alphaMaskCache[id] = null;
        return;
      }
      final rgba = raw.buffer.asUint8List();
      final alpha = Uint8List(image.width * image.height);
      var o = 0;
      for (var i = 0; i < alpha.length; i++) {
        alpha[i] = rgba[o + 3];
        o += 4;
      }
      if (_edgeCleanupItemIds.contains(id)) {
        _applyEdgeCleanup(alpha, image.width, image.height);
      }
      _alphaMaskCache[id] = _AlphaMaskData(
        width: image.width,
        height: image.height,
        alpha: alpha,
      );
    } catch (_) {
      _alphaMaskCache[id] = null;
    } finally {
      _alphaMaskLoading.remove(id);
    }
  }

  void _applyEdgeCleanup(Uint8List alpha, int width, int height) {
    final source = Uint8List.fromList(alpha);
    if (width < 3 || height < 3) return;
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final idx = (y * width) + x;
        if (source[idx] <= _alphaHitThreshold) continue;
        var neighbors = 0;
        for (var ny = -1; ny <= 1; ny++) {
          for (var nx = -1; nx <= 1; nx++) {
            if (nx == 0 && ny == 0) continue;
            if (source[((y + ny) * width) + (x + nx)] > _alphaHitThreshold) {
              neighbors++;
            }
          }
        }
        if (neighbors <= 2) alpha[idx] = 0;
      }
    }
  }

  List<_RoomPlacedItem> _buildItems() {
    return DecorationZone.values
        .map((zone) {
          final item = widget.itemById(widget.state.equippedDecorations[zone]);
          final anchor = _anchors[zone];
          if (item == null || anchor == null) return null;
          return _RoomPlacedItem(
            item: item,
            anchor: anchor,
            zone: zone,
            adjustment:
                _draftDecorationAdjustments[zone] ??
                RoomItemAdjustment.defaults,
          );
        })
        .whereType<_RoomPlacedItem>()
        .toList()
      ..sort((a, b) => a.anchor.depth.compareTo(b.anchor.depth));
  }

  _RoomObjectTransform _transformFor({
    required _RoomAnchor anchor,
    required RoomItemAdjustment adjustment,
    required Size canvasSize,
  }) {
    return _RoomObjectTransform(
      anchor: anchor,
      adjustment: adjustment,
      canvasSize: canvasSize,
    );
  }

  RoomItemAdjustment _adjustmentFromTransform({
    required _RoomAnchor anchor,
    required RoomItemAdjustment current,
    required Size canvasSize,
    required double scale,
    required double left,
    required double top,
  }) {
    final width = anchor.size.width * scale;
    final height = anchor.size.height * scale;

    if (anchor.isFootpointBased) {
      final baseFootX = canvasSize.width * ((anchor.alignment.x + 1) / 2);
      final baseFootY = canvasSize.height * ((anchor.alignment.y + 1) / 2);
      final footX = left + (width * anchor.translationPivot.dx);
      final footY = top + (height * anchor.translationPivot.dy);
      final clampedFootX = footX.clamp(
        -width * 0.12,
        canvasSize.width + width * 0.12,
      );
      final clampedFootY = footY.clamp(
        canvasSize.height * 0.42,
        canvasSize.height,
      );

      return current.copyWith(
        offsetX: (clampedFootX - baseFootX).clamp(-140, 140),
        offsetY: (clampedFootY - baseFootY).clamp(-140, 140),
        scale: scale.clamp(
          RoomItemAdjustment.minScale,
          RoomItemAdjustment.maxScale,
        ),
      );
    }

    final baseLeft =
        (canvasSize.width - anchor.size.width) * ((anchor.alignment.x + 1) / 2);
    final baseTop =
        (canvasSize.height - anchor.size.height) *
        ((anchor.alignment.y + 1) / 2);

    final minLeft = -width * 0.6;
    final maxLeft = canvasSize.width - width * 0.4;
    final minTop = -height * 0.6;
    final maxTop = canvasSize.height - height * 0.3;

    return current.copyWith(
      offsetX: (left.clamp(minLeft, maxLeft) - baseLeft).clamp(-140, 140),
      offsetY: (top.clamp(minTop, maxTop) - baseTop).clamp(-140, 140),
      scale: scale.clamp(
        RoomItemAdjustment.minScale,
        RoomItemAdjustment.maxScale,
      ),
    );
  }

  _RoomTarget? _hitTestTarget(
    Offset point,
    List<_RoomPlacedItem> items,
    double maxWidth,
    double maxHeight,
  ) {
    final topItems = items
        .where(
          (e) =>
              e.zone == DecorationZone.wall ||
              e.zone == DecorationZone.window ||
              e.zone == DecorationZone.shelf,
        )
        .toList();
    final bottomItems = items
        .where(
          (e) =>
              e.zone == DecorationZone.desk || e.zone == DecorationZone.floor,
        )
        .toList();

    final canvasSize = Size(maxWidth, maxHeight);
    final candidates =
        <
          ({
            _RoomTarget target,
            ShopItem item,
            Rect visualRect,
            _RoomObjectTransform transform,
          })
        >[
          for (final placed in topItems)
            (
              target: _RoomTarget.decoration(placed.zone),
              item: placed.item,
              transform: _transformFor(
                anchor: placed.anchor,
                adjustment: placed.adjustment,
                canvasSize: canvasSize,
              ),
              visualRect: _transformFor(
                anchor: placed.anchor,
                adjustment: placed.adjustment,
                canvasSize: canvasSize,
              ).worldRect,
            ),
          (
            target: const _RoomTarget.character(),
            item: widget.state.equippedCharacter,
            transform: _transformFor(
              anchor: _characterAnchor,
              adjustment: _draftCharacterAdjustment,
              canvasSize: canvasSize,
            ),
            visualRect: _transformFor(
              anchor: _characterAnchor,
              adjustment: _draftCharacterAdjustment,
              canvasSize: canvasSize,
            ).worldRect,
          ),
          for (final placed in bottomItems)
            (
              target: _RoomTarget.decoration(placed.zone),
              item: placed.item,
              transform: _transformFor(
                anchor: placed.anchor,
                adjustment: placed.adjustment,
                canvasSize: canvasSize,
              ),
              visualRect: _transformFor(
                anchor: placed.anchor,
                adjustment: placed.adjustment,
                canvasSize: canvasSize,
              ).worldRect,
            ),
        ];

    for (var i = candidates.length - 1; i >= 0; i--) {
      final c = candidates[i];
      final mask = _alphaMaskCache[c.item.id];
      if (mask != null &&
          mask.hitTest(point, c.transform, threshold: _alphaHitThreshold)) {
        return c.target.withRect(c.visualRect);
      }
      if (!_alphaMaskCache.containsKey(c.item.id) &&
          !_alphaMaskLoading.contains(c.item.id)) {
        unawaited(_ensureAlphaMask(c.item));
      }
    }
    return null;
  }

  _RoomAnchor _anchorFor(_RoomTarget target) =>
      target.isCharacter ? _characterAnchor : _anchors[target.zone]!;

  RoomItemAdjustment _currentAdjustment(_RoomTarget target) =>
      target.isCharacter
      ? _draftCharacterAdjustment
      : (_draftDecorationAdjustments[target.zone] ??
            RoomItemAdjustment.defaults);

  void _applyDraftAdjustment(
    _RoomTarget target,
    RoomItemAdjustment adjustment,
  ) {
    if (target.isCharacter) {
      _draftCharacterAdjustment = adjustment;
      return;
    }
    _draftDecorationAdjustments[target.zone!] = adjustment;
  }

  void _commitAdjustment(_RoomTarget target, RoomItemAdjustment adjustment) {
    if (target.isCharacter) {
      widget.onCharacterAdjusted(adjustment);
      return;
    }
    widget.onDecorationAdjusted(target.zone!, adjustment);
  }

  double _maxScaleForTarget(_RoomTarget target) {
    final item = target.isCharacter
        ? widget.state.equippedCharacter
        : widget.itemById(widget.state.equippedDecorations[target.zone]);
    if (item == null) return RoomItemAdjustment.maxScale;
    return _miniroomSpecForItem(
      item,
    ).maxScale.clamp(RoomItemAdjustment.minScale, RoomItemAdjustment.maxScale);
  }

  RenderBox? _miniRoomCanvasRenderBox() {
    final context = _miniRoomCanvasKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject;
  }

  Size _canvasSize(BoxConstraints c) {
    final box = _miniRoomCanvasRenderBox();
    return box?.size ?? Size(c.maxWidth, c.maxHeight);
  }

  // r44: keep single-path calibration, plus a tiny final iOS real-device bias trim.
  Offset _applyTouchCalibration(Offset globalPoint, BoxConstraints c) {
    const double kFinalIosTouchBiasX = -1.0;
    const double kFinalIosTouchBiasY = -2.0;

    final canvasBox = _miniRoomCanvasRenderBox();
    final canvasSize = _canvasSize(c);
    final local = canvasBox?.globalToLocal(globalPoint) ?? globalPoint;

    final corrected = defaultTargetPlatform == TargetPlatform.iOS
        ? Offset(local.dx + kFinalIosTouchBiasX, local.dy + kFinalIosTouchBiasY)
        : local;

    if (kDebugMode && canvasBox != null) {
      final origin = canvasBox.localToGlobal(Offset.zero);
      _debugCalibrationSummary =
          'single-layer origin=${origin.dx.toStringAsFixed(1)},${origin.dy.toStringAsFixed(1)} '
          'size=${canvasSize.width.toStringAsFixed(1)}x${canvasSize.height.toStringAsFixed(1)} '
          'bias=(${kFinalIosTouchBiasX.toStringAsFixed(1)},${kFinalIosTouchBiasY.toStringAsFixed(1)})';
    }

    return Offset(
      corrected.dx.clamp(0.0, canvasSize.width),
      corrected.dy.clamp(0.0, canvasSize.height),
    );
  }

  void _appendTouchTrace({
    required String phase,
    required Offset rawGlobal,
    required Offset local,
    _RoomTarget? hitTarget,
    _RoomObjectTransform? transform,
  }) {
    final hit = hitTarget?.key ?? 'none';
    final rect = transform?.worldRect;
    final transformSummary = rect == null
        ? 'n/a'
        : 'left=${rect.left.toStringAsFixed(1)},top=${rect.top.toStringAsFixed(1)},w=${rect.width.toStringAsFixed(1)},h=${rect.height.toStringAsFixed(1)}';
    _touchTraceLines.add(
      '$phase | global(${rawGlobal.dx.toStringAsFixed(1)},${rawGlobal.dy.toStringAsFixed(1)}) '
      '| local(${local.dx.toStringAsFixed(1)},${local.dy.toStringAsFixed(1)}) '
      '| hit=$hit | transform=$transformSummary',
    );
    if (_touchTraceLines.length > 80) {
      _touchTraceLines.removeRange(0, _touchTraceLines.length - 80);
    }
    if (kDebugMode) {
      debugPrint('[r44-touch-trace] ${_touchTraceLines.last}');
    }
  }

  _RoomObjectTransform? _transformForTarget(
    _RoomTarget? target,
    Size canvasSize,
  ) {
    if (target == null) return null;
    if (target.isCharacter) {
      return _transformFor(
        anchor: _characterAnchor,
        adjustment: _draftCharacterAdjustment,
        canvasSize: canvasSize,
      );
    }
    final zone = target.zone;
    final anchor = zone == null ? null : _anchors[zone];
    if (anchor == null) return null;
    return _transformFor(
      anchor: anchor,
      adjustment:
          _draftDecorationAdjustments[zone] ?? RoomItemAdjustment.defaults,
      canvasSize: canvasSize,
    );
  }

  static const double _dragDeadZonePx = 5.0;
  static const double _dragHysteresisPx = 8.0;
  static const double _pinchDeadZonePx = 3.0;
  static const double _pinchHysteresisPx = 6.0;

  void _onPointerDown(PointerDownEvent event, BoxConstraints c) {
    final canvasSize = _canvasSize(c);
    final point = _applyTouchCalibration(event.position, c);

    final prev = _touchSession;
    if (prev == null) {
      final items = _buildItems();
      final target = _hitTestTarget(
        point,
        items,
        canvasSize.width,
        canvasSize.height,
      );

      if (kDebugMode) {
        _debugRawTouchPoint = event.position;
        _captureDebugTouch(
          point,
          items,
          canvasSize.width,
          canvasSize.height,
          target: target,
        );
      }
      _appendTouchTrace(
        phase: 'down',
        rawGlobal: event.position,
        local: point,
        hitTarget: target,
        transform: _transformForTarget(target, canvasSize),
      );

      if (target == null) return;

      final anchor = _anchorFor(target);
      final adjustment = _currentAdjustment(target);
      setState(() {
        _selectedTarget = target;
        _touchSession = _TouchSession(
          target: target,
          anchor: anchor,
          initialAdjustment: adjustment,
          adjustmentAtModeStart: adjustment,
          maxScale: _maxScaleForTarget(target),
          pointers: {event.pointer: point},
          baseLocalFocal: point,
          currentLocalFocal: point,
          mode: _TouchMode.pending,
        );
      });
      widget.onInteractionLockChanged(true);
      return;
    }

    final nextPointers = {...prev.pointers, event.pointer: point};
    _appendTouchTrace(
      phase: 'down+',
      rawGlobal: event.position,
      local: point,
      hitTarget: prev.target,
      transform: _transformForTarget(prev.target, canvasSize),
    );
    final nextFocal = _focalPoint(nextPointers.values);
    final next = prev.copyWith(
      pointers: nextPointers,
      baseLocalFocal: nextFocal,
      currentLocalFocal: nextFocal,
      adjustmentAtModeStart: _currentAdjustment(prev.target),
      basePinchDistance: _pinchDistance(nextPointers),
      mode: nextPointers.length >= 2 ? _TouchMode.pendingPinch : prev.mode,
    );
    setState(() => _touchSession = next);
    widget.onInteractionLockChanged(true);
  }

  void _onPointerMove(PointerMoveEvent event, BoxConstraints c) {
    final session = _touchSession;
    if (session == null || !session.pointers.containsKey(event.pointer)) return;

    if (kDebugMode) _debugRawTouchPoint = event.position;
    final local = _applyTouchCalibration(event.position, c);
    final nextPointers = {...session.pointers, event.pointer: local};
    final focal = _focalPoint(nextPointers.values);
    final travel = (focal - session.baseLocalFocal).distance;
    final activeCount = nextPointers.length;

    var nextMode = session.mode;
    var modeSwitches = session.modeSwitchCount;
    var cancels = session.cancelCount;
    var baseFocal = session.baseLocalFocal;
    var basePinch = session.basePinchDistance;
    var adjustmentAtModeStart = session.adjustmentAtModeStart;

    if (activeCount >= 2) {
      final pinch = _pinchDistance(nextPointers);
      final pinchDelta = (pinch - basePinch).abs();
      if (nextMode == _TouchMode.dragging) {
        if (pinchDelta >= _pinchHysteresisPx) {
          nextMode = _TouchMode.pinching;
          modeSwitches += 1;
          baseFocal = focal;
          basePinch = pinch;
          adjustmentAtModeStart = _currentAdjustment(session.target);
        }
      } else if (nextMode == _TouchMode.pendingPinch ||
          nextMode == _TouchMode.pending) {
        if (pinchDelta >= _pinchDeadZonePx) {
          nextMode = _TouchMode.pinching;
          modeSwitches += 1;
          baseFocal = focal;
          basePinch = pinch;
          adjustmentAtModeStart = _currentAdjustment(session.target);
        }
      }
    } else {
      if (nextMode == _TouchMode.pinching && travel >= _dragHysteresisPx) {
        nextMode = _TouchMode.dragging;
        modeSwitches += 1;
        baseFocal = focal;
        adjustmentAtModeStart = _currentAdjustment(session.target);
      } else if ((nextMode == _TouchMode.pending ||
              nextMode == _TouchMode.pendingPinch) &&
          travel >= _dragDeadZonePx) {
        nextMode = _TouchMode.dragging;
        modeSwitches += 1;
        baseFocal = focal;
        adjustmentAtModeStart = _currentAdjustment(session.target);
      }
    }

    final updated = session.copyWith(
      pointers: nextPointers,
      currentLocalFocal: focal,
      baseLocalFocal: baseFocal,
      basePinchDistance: basePinch,
      adjustmentAtModeStart: adjustmentAtModeStart,
      mode: nextMode,
      modeSwitchCount: modeSwitches,
      cancelCount: cancels,
    );

    final canvasSize = _canvasSize(c);
    final nextAdjustment = _nextAdjustmentFromSession(updated, canvasSize);
    if (nextAdjustment != null) {
      _applyDraftAdjustment(updated.target, nextAdjustment);
    }
    _appendTouchTrace(
      phase: 'move:${updated.mode.name}',
      rawGlobal: event.position,
      local: local,
      hitTarget: updated.target,
      transform: _transformForTarget(updated.target, canvasSize),
    );

    setState(() {
      _touchSession = updated;
    });
  }

  void _onPointerUpOrCancel(
    PointerEvent event,
    BoxConstraints c, {
    required bool canceled,
  }) {
    final session = _touchSession;
    if (session == null || !session.pointers.containsKey(event.pointer)) {
      if (_touchSession == null) widget.onInteractionLockChanged(false);
      return;
    }

    final nextPointers = {...session.pointers}..remove(event.pointer);
    final local = _applyTouchCalibration(event.position, c);
    final canvasSize = _canvasSize(c);
    _appendTouchTrace(
      phase: canceled ? 'cancel' : 'up',
      rawGlobal: event.position,
      local: local,
      hitTarget: session.target,
      transform: _transformForTarget(session.target, canvasSize),
    );
    if (nextPointers.isEmpty) {
      final finalAdjustment = _currentAdjustment(session.target);
      _commitAdjustment(session.target, finalAdjustment);
      if (kDebugMode) {
        debugPrint(
          '[miniroom-touch] target=${session.target.key} modeSwitches=${session.modeSwitchCount} cancels=${session.cancelCount + (canceled ? 1 : 0)}',
        );
      }
      setState(() {
        _touchSession = null;
      });
      widget.onInteractionLockChanged(false);
      return;
    }

    final focal = _focalPoint(nextPointers.values);
    final reduced = session.copyWith(
      pointers: nextPointers,
      baseLocalFocal: focal,
      currentLocalFocal: focal,
      basePinchDistance: _pinchDistance(nextPointers),
      adjustmentAtModeStart: _currentAdjustment(session.target),
      mode: nextPointers.length >= 2
          ? _TouchMode.pendingPinch
          : _TouchMode.pending,
      cancelCount: session.cancelCount + (canceled ? 1 : 0),
    );
    setState(() => _touchSession = reduced);
  }

  RoomItemAdjustment? _nextAdjustmentFromSession(
    _TouchSession session,
    Size canvasSize,
  ) {
    final current = _currentAdjustment(session.target);
    if (session.mode == _TouchMode.dragging) {
      final delta = session.currentLocalFocal - session.baseLocalFocal;
      final base = session.adjustmentAtModeStart;
      final transform = _transformFor(
        anchor: session.anchor,
        adjustment: base,
        canvasSize: canvasSize,
      );
      return _adjustmentFromTransform(
        anchor: session.anchor,
        current: current,
        canvasSize: canvasSize,
        scale: base.scale,
        left: transform.left + delta.dx,
        top: transform.top + delta.dy,
      );
    }

    if (session.mode == _TouchMode.pinching && session.pointers.length >= 2) {
      final pinch = _pinchDistance(session.pointers);
      if (session.basePinchDistance <= 0.0 || pinch <= 0.0) return null;
      final scaleRatio = pinch / session.basePinchDistance;
      final base = session.adjustmentAtModeStart;
      final nextScale = (base.scale * scaleRatio).clamp(
        RoomItemAdjustment.minScale,
        session.maxScale,
      );

      // r41: scale origin is always object center to prevent offset amplification.
      final baseTransform = _transformFor(
        anchor: session.anchor,
        adjustment: base,
        canvasSize: canvasSize,
      );
      final center = baseTransform.worldRect.center;
      final width = session.anchor.size.width * nextScale;
      final height = session.anchor.size.height * nextScale;
      final left = center.dx - (width / 2);
      final top = center.dy - (height / 2);

      return _adjustmentFromTransform(
        anchor: session.anchor,
        current: current,
        canvasSize: canvasSize,
        scale: nextScale,
        left: left,
        top: top,
      );
    }
    return null;
  }

  Offset _focalPoint(Iterable<Offset> points) {
    var count = 0;
    var dx = 0.0;
    var dy = 0.0;
    for (final p in points) {
      count += 1;
      dx += p.dx;
      dy += p.dy;
    }
    if (count == 0) return Offset.zero;
    return Offset(dx / count, dy / count);
  }

  double _pinchDistance(Map<int, Offset> pointers) {
    if (pointers.length < 2) return 0.0;
    final values = pointers.values.take(2).toList(growable: false);
    return (values[0] - values[1]).distance;
  }

  void _captureDebugTouch(
    Offset point,
    List<_RoomPlacedItem> items,
    double maxWidth,
    double maxHeight, {
    _RoomTarget? target,
  }) {
    if (!kDebugMode) return;

    Rect? visualRect;
    _RoomObjectTransform? targetTransform;
    _AlphaMaskData? mask;

    if (target != null) {
      if (target.isCharacter) {
        targetTransform = _transformFor(
          anchor: _characterAnchor,
          adjustment: _draftCharacterAdjustment,
          canvasSize: Size(maxWidth, maxHeight),
        );
        visualRect = targetTransform.worldRect;
        mask = _alphaMaskCache[widget.state.equippedCharacter.id];
      } else {
        _RoomPlacedItem? placed;
        for (final candidate in items) {
          if (candidate.zone == target.zone) {
            placed = candidate;
            break;
          }
        }
        if (placed != null) {
          targetTransform = _transformFor(
            anchor: placed.anchor,
            adjustment: placed.adjustment,
            canvasSize: Size(maxWidth, maxHeight),
          );
          visualRect = targetTransform.worldRect;
          mask = _alphaMaskCache[placed.item.id];
        }
      }
    }

    final mapped = (mask != null && targetTransform != null)
        ? mask.mapWorldPointToPixel(point, targetTransform)
        : null;

    setState(() {
      _debugRawTouchPoint = point;
      _debugWorldTouchPoint = point;
      _debugVisualRect = visualRect;
      _debugLocalPoint = mapped?.normalized;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        Widget content = ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: _MiniRoomVisual(
                  state: widget.state.copyWith(
                    decorationAdjustments: {..._draftDecorationAdjustments},
                    characterAdjustment: _draftCharacterAdjustment,
                  ),
                  itemById: widget.itemById,
                  showEquipFx: widget.showEquipFx,
                  equipFxLabel: widget.equipFxLabel,
                  selectedTarget: _selectedTarget,
                  selectionPulse: _selectionPulseController,
                  debugOverlayEnabled: kDebugMode && _debugHitOverlayVisible,
                  debugWorldTouchPoint: _debugWorldTouchPoint,
                  debugRawTouchPoint: _debugRawTouchPoint,
                  debugLocalPoint: _debugLocalPoint,
                  debugVisualRect: _debugVisualRect,
                  debugCalibrationSummary: _debugCalibrationSummary,
                ),
              ),
              Listener(
                key: _miniRoomCanvasKey,
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => _onPointerDown(event, c),
                onPointerMove: (event) => _onPointerMove(event, c),
                onPointerUp: (event) =>
                    _onPointerUpOrCancel(event, c, canceled: false),
                onPointerCancel: (event) =>
                    _onPointerUpOrCancel(event, c, canceled: true),
                child: const SizedBox.expand(),
              ),
            ],
          ),
        );

        if (kDebugMode) {
          content = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: () {
              setState(() {
                _debugHitOverlayVisible = !_debugHitOverlayVisible;
              });
            },
            child: content,
          );
        }

        return content;
      },
    );
  }
}

enum _TouchMode { pending, pendingPinch, dragging, pinching }

class _TouchSession {
  const _TouchSession({
    required this.target,
    required this.anchor,
    required this.initialAdjustment,
    required this.adjustmentAtModeStart,
    required this.maxScale,
    required this.pointers,
    required this.baseLocalFocal,
    required this.currentLocalFocal,
    required this.mode,
    this.basePinchDistance = 0,
    this.modeSwitchCount = 0,
    this.cancelCount = 0,
  });

  final _RoomTarget target;
  final _RoomAnchor anchor;
  final RoomItemAdjustment initialAdjustment;
  final RoomItemAdjustment adjustmentAtModeStart;
  final double maxScale;
  final Map<int, Offset> pointers;
  final Offset baseLocalFocal;
  final Offset currentLocalFocal;
  final _TouchMode mode;
  final double basePinchDistance;
  final int modeSwitchCount;
  final int cancelCount;

  _TouchSession copyWith({
    RoomItemAdjustment? adjustmentAtModeStart,
    Map<int, Offset>? pointers,
    Offset? baseLocalFocal,
    Offset? currentLocalFocal,
    _TouchMode? mode,
    double? basePinchDistance,
    int? modeSwitchCount,
    int? cancelCount,
  }) {
    return _TouchSession(
      target: target,
      anchor: anchor,
      initialAdjustment: initialAdjustment,
      adjustmentAtModeStart:
          adjustmentAtModeStart ?? this.adjustmentAtModeStart,
      maxScale: maxScale,
      pointers: pointers ?? this.pointers,
      baseLocalFocal: baseLocalFocal ?? this.baseLocalFocal,
      currentLocalFocal: currentLocalFocal ?? this.currentLocalFocal,
      mode: mode ?? this.mode,
      basePinchDistance: basePinchDistance ?? this.basePinchDistance,
      modeSwitchCount: modeSwitchCount ?? this.modeSwitchCount,
      cancelCount: cancelCount ?? this.cancelCount,
    );
  }
}

class _MiniRoomVisual extends StatelessWidget {
  const _MiniRoomVisual({
    required this.state,
    required this.itemById,
    required this.showEquipFx,
    required this.equipFxLabel,
    this.selectedTarget,
    this.selectionPulse,
    this.debugOverlayEnabled = false,
    this.debugWorldTouchPoint,
    this.debugRawTouchPoint,
    this.debugLocalPoint,
    this.debugVisualRect,
    this.debugCalibrationSummary,
  });

  final AppState state;
  final ShopItem? Function(String? id) itemById;
  final bool showEquipFx;
  final String equipFxLabel;
  final _RoomTarget? selectedTarget;
  final Animation<double>? selectionPulse;
  final bool debugOverlayEnabled;
  final Offset? debugWorldTouchPoint;
  final Offset? debugRawTouchPoint;
  final Offset? debugLocalPoint;
  final Rect? debugVisualRect;
  final String? debugCalibrationSummary;

  static const Map<DecorationZone, _RoomAnchor> _anchors = {
    DecorationZone.wall: _RoomAnchor(Alignment(-0.06, -0.60), Size(72, 46), 1),
    DecorationZone.window: _RoomAnchor(Alignment(0.66, -0.42), Size(64, 46), 2),
    DecorationZone.shelf: _RoomAnchor(Alignment(-0.70, -0.02), Size(72, 61), 3),
    DecorationZone.desk: _RoomAnchor(Alignment(0.44, 0.28), Size(102, 71), 4),
    DecorationZone.floor: _RoomAnchor(Alignment(-0.18, 0.70), Size(124, 67), 5),
  };
  static const _characterAnchor = _RoomAnchor(
    Alignment(0.03, 0.72),
    Size(68, 68),
    4,
    translationPivot: Offset(0.5, 0.96),
  );

  List<_RoomPlacedItem> _buildItems() {
    return DecorationZone.values
        .map((zone) {
          final item = itemById(state.equippedDecorations[zone]);
          final anchor = _anchors[zone];
          if (item == null || anchor == null) return null;
          return _RoomPlacedItem(
            item: item,
            anchor: anchor,
            zone: zone,
            adjustment:
                state.decorationAdjustments[zone] ??
                RoomItemAdjustment.defaults,
          );
        })
        .whereType<_RoomPlacedItem>()
        .toList()
      ..sort((a, b) => a.anchor.depth.compareTo(b.anchor.depth));
  }

  Rect _visualRectFromAdjustment({
    required _RoomAnchor anchor,
    required RoomItemAdjustment adjustment,
    required double maxWidth,
    required double maxHeight,
  }) {
    return _RoomObjectTransform(
      anchor: anchor,
      adjustment: adjustment,
      canvasSize: Size(maxWidth, maxHeight),
    ).worldRect;
  }

  @override
  Widget build(BuildContext context) {
    final theme = _HomeThemePreset.fromHomeId(state.equippedHomeId);
    final items = _buildItems();
    final homeVisual = _miniroomSpecForItem(state.equippedHome);
    final topItems = items
        .where(
          (e) =>
              e.zone == DecorationZone.wall ||
              e.zone == DecorationZone.window ||
              e.zone == DecorationZone.shelf,
        )
        .toList();
    final bottomItems = items
        .where(
          (e) =>
              e.zone == DecorationZone.desk || e.zone == DecorationZone.floor,
        )
        .toList();

    return LayoutBuilder(
      builder: (context, c) {
        Widget buildPlaced(_RoomPlacedItem placed) {
          final rect = _visualRectFromAdjustment(
            anchor: placed.anchor,
            adjustment: placed.adjustment,
            maxWidth: c.maxWidth,
            maxHeight: c.maxHeight,
          );
          final selected =
              selectedTarget?.zone == placed.zone &&
              selectedTarget?.isCharacter == false;
          return Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: _SelectionGlow(
              selected: selected,
              pulse: selectionPulse,
              child: _DecorationObject(item: placed.item),
            ),
          );
        }

        final characterRect = _visualRectFromAdjustment(
          anchor: _characterAnchor,
          adjustment: state.characterAdjustment,
          maxWidth: c.maxWidth,
          maxHeight: c.maxHeight,
        );

        return SizedBox.expand(
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _MiniRoomShellPainter()),
                ),
              ),
              if (homeVisual.assetPath != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Image.asset(
                      homeVisual.assetPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.wallGradient.first,
                                theme.floorGradient.last,
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ...topItems.map(buildPlaced),
              Positioned(
                left: characterRect.left,
                top: characterRect.top,
                width: characterRect.width,
                height: characterRect.height,
                child: _SelectionGlow(
                  selected: selectedTarget?.isCharacter == true,
                  pulse: selectionPulse,
                  child: _DecorationObject(item: state.equippedCharacter),
                ),
              ),
              ...bottomItems.map(buildPlaced),
              if (debugOverlayEnabled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _MiniRoomHitDebugPainter(
                        worldPoint: debugWorldTouchPoint,
                        rawPoint: debugRawTouchPoint,
                        localPoint: debugLocalPoint,
                        visualRect: debugVisualRect,
                        calibrationSummary: debugCalibrationSummary,
                      ),
                    ),
                  ),
                ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: showEquipFx ? 1 : 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCE1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFFE083)),
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
            ],
          ),
        );
      },
    );
  }
}

class _SelectionGlow extends StatelessWidget {
  const _SelectionGlow({
    required this.selected,
    required this.pulse,
    required this.child,
  });

  final bool selected;
  final Animation<double>? pulse;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected || pulse == null) return child;
    return AnimatedBuilder(
      animation: pulse!,
      child: child,
      builder: (context, childWidget) {
        final t = pulse!.value;
        final scale = 1 + (0.006 * t);
        final brighten = 1.06 + (0.03 * t);

        final matrix = <double>[
          brighten,
          0,
          0,
          0,
          3,
          0,
          brighten,
          0,
          0,
          3,
          0,
          0,
          brighten,
          0,
          3,
          0,
          0,
          0,
          1,
          0,
        ];

        return Transform.scale(
          scale: scale,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(matrix),
            child: childWidget,
          ),
        );
      },
    );
  }
}

class _MiniRoomHitDebugPainter extends CustomPainter {
  const _MiniRoomHitDebugPainter({
    required this.worldPoint,
    required this.rawPoint,
    required this.localPoint,
    required this.visualRect,
    required this.calibrationSummary,
  });

  final Offset? worldPoint;
  final Offset? rawPoint;
  final Offset? localPoint;
  final Rect? visualRect;
  final String? calibrationSummary;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = visualRect;
    final touch = worldPoint;
    if (touch == null) return;

    if (rect != null) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF4FC3F7);
      canvas.drawRect(rect, outline);

      final local = localPoint;
      if (local != null) {
        final px = rect.left + (local.dx.clamp(0.0, 1.0) * rect.width);
        final py = rect.top + (local.dy.clamp(0.0, 1.0) * rect.height);
        final lp = Offset(px, py);
        canvas.drawCircle(
          lp,
          5,
          Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.85),
        );
      }
    }

    final raw = rawPoint;
    if (raw != null) {
      canvas.drawCircle(
        raw,
        4,
        Paint()..color = const Color(0xFF26A69A).withValues(alpha: 0.9),
      );
      canvas.drawLine(
        raw,
        touch,
        Paint()
          ..color = const Color(0xFF26A69A).withValues(alpha: 0.55)
          ..strokeWidth = 1.1,
      );
    }

    canvas.drawCircle(
      touch,
      6,
      Paint()..color = const Color(0xFFE91E63).withValues(alpha: 0.9),
    );

    final summary = calibrationSummary;
    if (summary != null && summary.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: summary,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: max(80, size.width - 14));
      final bg = Rect.fromLTWH(6, 6, tp.width + 10, tp.height + 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.78),
      );
      tp.paint(canvas, const Offset(11, 9));
    }
  }

  @override
  bool shouldRepaint(covariant _MiniRoomHitDebugPainter oldDelegate) {
    return oldDelegate.worldPoint != worldPoint ||
        oldDelegate.rawPoint != rawPoint ||
        oldDelegate.localPoint != localPoint ||
        oldDelegate.visualRect != visualRect ||
        oldDelegate.calibrationSummary != calibrationSummary;
  }
}

class _MiniRoomShellPainter extends CustomPainter {
  const _MiniRoomShellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wallRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.62);
    final wallPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFF6F8FC)],
      ).createShader(wallRect);
    canvas.drawRect(wallRect, wallPaint);

    final sideShadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFFDDE4EF).withValues(alpha: 0.55),
          Colors.transparent,
          const Color(0xFFDDE4EF).withValues(alpha: 0.42),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.62));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.62),
      sideShadow,
    );

    final floorPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.62)
      ..lineTo(size.width * 0.92, size.height * 0.62)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final floorPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F3F8), Color(0xFFE2E7EF)],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.62,
              size.width,
              size.height * 0.38,
            ),
          );
    canvas.drawPath(floorPath, floorPaint);

    final seamPaint = Paint()
      ..color = const Color(0xFFCFD7E3)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.62),
      Offset(size.width * 0.92, size.height * 0.62),
      seamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniRoomShellPainter oldDelegate) => false;
}

class _MiniroomVisualSpec {
  const _MiniroomVisualSpec({
    required this.icon,
    required this.gradient,
    this.iconColor,
    this.assetPath,
    this.hitTestInsetFraction = const EdgeInsets.fromLTRB(
      0.18,
      0.18,
      0.18,
      0.18,
    ),
    this.maxScale = RoomItemAdjustment.maxScale,
  });

  final IconData icon;
  final List<Color> gradient;
  final Color? iconColor;
  final String? assetPath;
  final EdgeInsets hitTestInsetFraction;
  final double maxScale;
}

_MiniroomVisualSpec _miniroomSpecForItem(ShopItem item) {
  switch (item.id) {
    case 'char_default':
      return const _MiniroomVisualSpec(
        icon: Icons.pets,
        gradient: [Color(0xFFFFE6C9), Color(0xFFFFCFA1)],
        assetPath: 'assets/miniroom/generated/item_teddy_bear.png',
        hitTestInsetFraction: EdgeInsets.fromLTRB(0.14, 0.12, 0.14, 0.08),
      );
    case 'char_fox':
      return const _MiniroomVisualSpec(
        icon: Icons.pets,
        gradient: [Color(0xFFFFE0BF), Color(0xFFFFC58F)],
        assetPath: 'assets/miniroom/generated/item_char_fox.png',
      );
    case 'char_penguin':
      return const _MiniroomVisualSpec(
        icon: Icons.flutter_dash,
        gradient: [Color(0xFFDDEAFF), Color(0xFFBAD2FF)],
        assetPath: 'assets/miniroom/generated/item_char_penguin.png',
      );
    case 'char_tiger':
      return const _MiniroomVisualSpec(
        icon: Icons.cruelty_free,
        gradient: [Color(0xFFFFD6B3), Color(0xFFFFB27A)],
        assetPath: 'assets/miniroom/generated/item_char_tiger.png',
      );
    case 'char_robot':
      return const _MiniroomVisualSpec(
        icon: Icons.smart_toy,
        gradient: [Color(0xFFE2E7F0), Color(0xFFB7C2D4)],
        assetPath: 'assets/miniroom/generated/item_char_robot.png',
        hitTestInsetFraction: EdgeInsets.fromLTRB(0.16, 0.10, 0.16, 0.08),
      );
    case 'char_unicorn':
      return const _MiniroomVisualSpec(
        icon: Icons.auto_awesome,
        gradient: [Color(0xFFF3DCFF), Color(0xFFD7BEFF)],
        assetPath: 'assets/miniroom/generated/item_char_dream_boy.png',
      );
    case 'home_base_default':
      return const _MiniroomVisualSpec(
        icon: Icons.home_filled,
        gradient: [Color(0xFFE9EEFF), Color(0xFFD3DCFF)],
        assetPath: 'assets/miniroom/generated/room_base_default.png',
      );
    case 'home_forest':
      return const _MiniroomVisualSpec(
        icon: Icons.park,
        gradient: [Color(0xFFDEF5D9), Color(0xFFBDE6AE)],
        assetPath: 'assets/miniroom/generated/room_base_forest.png',
      );
    case 'home_city':
      return const _MiniroomVisualSpec(
        icon: Icons.location_city,
        gradient: [Color(0xFFDDE8FF), Color(0xFFB6C8F2)],
        assetPath: 'assets/miniroom/generated/room_base_city.png',
      );
    case 'home_ocean':
      return const _MiniroomVisualSpec(
        icon: Icons.water,
        gradient: [Color(0xFFD2F6FF), Color(0xFF9FE8FF)],
        assetPath: 'assets/miniroom/generated/room_base_ocean.png',
      );
    case 'home_space':
      return const _MiniroomVisualSpec(
        icon: Icons.rocket_launch,
        gradient: [Color(0xFF2E2254), Color(0xFF503C96)],
        iconColor: Colors.white,
        assetPath: 'assets/miniroom/generated/room_base_space.png',
      );
    case 'home_castle':
      return const _MiniroomVisualSpec(
        icon: Icons.castle,
        gradient: [Color(0xFFE7DFFF), Color(0xFFCCB8FF)],
        assetPath: 'assets/miniroom/generated/room_base_warm.png',
      );
    case 'deco_wall_chart':
      return const _MiniroomVisualSpec(
        icon: Icons.show_chart,
        gradient: [Color(0xFFE0EBFF), Color(0xFFC7D8FF)],
        assetPath: 'assets/miniroom/generated/item_wall_chart_poster.png',
      );
    case 'deco_wall_star':
      return const _MiniroomVisualSpec(
        icon: Icons.star_border,
        gradient: [Color(0xFFFFF2C7), Color(0xFFFFE6A1)],
        assetPath: 'assets/miniroom/generated/item_wall_star_sticker.png',
        hitTestInsetFraction: EdgeInsets.fromLTRB(0.22, 0.18, 0.22, 0.18),
      );
    case 'deco_wall_frame':
      return const _MiniroomVisualSpec(
        icon: Icons.filter_frames,
        gradient: [Color(0xFFEFE8DA), Color(0xFFDED0B8)],
        assetPath: 'assets/miniroom/generated/item_wall_frame.png',
      );
    case 'deco_floor_rug':
      return const _MiniroomVisualSpec(
        icon: Icons.texture,
        gradient: [Color(0xFFE9E3F9), Color(0xFFD8CFF2)],
        assetPath: 'assets/miniroom/generated/item_round_rug.png',
        hitTestInsetFraction: EdgeInsets.fromLTRB(0.14, 0.28, 0.14, 0.10),
        maxScale: 3.6,
      );
    case 'deco_floor_coinbox':
      return const _MiniroomVisualSpec(
        icon: Icons.savings,
        gradient: [Color(0xFFFFE8BF), Color(0xFFFFD78F)],
        assetPath: 'assets/miniroom/generated/item_storage_box.png',
      );
    case 'deco_floor_plant':
      return const _MiniroomVisualSpec(
        icon: Icons.local_florist,
        gradient: [Color(0xFFD8F3D5), Color(0xFFB7E8B2)],
        assetPath: 'assets/miniroom/generated/item_potted_plant_small.png',
      );
    case 'deco_desk_globe':
      return const _MiniroomVisualSpec(
        icon: Icons.public,
        gradient: [Color(0xFFD9EEFF), Color(0xFFB9D8FF)],
        assetPath: 'assets/miniroom/generated/item_globe.png',
      );
    case 'deco_desk_trophy':
      return const _MiniroomVisualSpec(
        icon: Icons.emoji_events,
        gradient: [Color(0xFFFFEDC2), Color(0xFFFFD892)],
        assetPath: 'assets/miniroom/generated/item_mini_table.png',
      );
    case 'deco_shelf_books':
      return const _MiniroomVisualSpec(
        icon: Icons.menu_book,
        gradient: [Color(0xFFE3E9F8), Color(0xFFC7D4F2)],
        assetPath: 'assets/miniroom/generated/item_bookshelf.png',
      );
    case 'deco_shelf_piggy':
      return const _MiniroomVisualSpec(
        icon: Icons.account_balance_wallet,
        gradient: [Color(0xFFFEE0E7), Color(0xFFF8C3CF)],
        assetPath: 'assets/miniroom/generated/item_toy_shelf.png',
      );
    case 'deco_window_curtain':
      return const _MiniroomVisualSpec(
        icon: Icons.blinds,
        gradient: [Color(0xFFE8EEFF), Color(0xFFC9D6FF)],
        assetPath: 'assets/miniroom/generated/item_window_curtain.png',
        hitTestInsetFraction: EdgeInsets.fromLTRB(0.18, 0.08, 0.18, 0.14),
      );
    case 'deco_window_cloud':
      return const _MiniroomVisualSpec(
        icon: Icons.cloud,
        gradient: [Color(0xFFE5F0FF), Color(0xFFC8E0FF)],
        assetPath: 'assets/miniroom/generated/item_window_sun_rain_mobile.png',
      );
    case 'deco_wall_planboard':
      return const _MiniroomVisualSpec(
        icon: Icons.checklist_rounded,
        gradient: [Color(0xFFFFF0D3), Color(0xFFFFDFB0)],
        assetPath: 'assets/miniroom/generated/item_wall_mission_board.png',
      );
    case 'deco_wall_medal':
      return const _MiniroomVisualSpec(
        icon: Icons.workspace_premium_rounded,
        gradient: [Color(0xFFFFEBC1), Color(0xFFFFD78F)],
        assetPath: 'assets/miniroom/generated/item_wall_explorer_medal.png',
      );
    case 'deco_floor_cushion':
      return const _MiniroomVisualSpec(
        icon: Icons.weekend_rounded,
        gradient: [Color(0xFFE8E7FF), Color(0xFFD0CEFF)],
        assetPath:
            'assets/miniroom/generated/item_floor_safe_invest_cushion.png',
      );
    case 'deco_floor_train':
      return const _MiniroomVisualSpec(
        icon: Icons.train_rounded,
        gradient: [Color(0xFFD9F3FF), Color(0xFFBCE7FF)],
        assetPath: 'assets/miniroom/generated/item_floor_econ_toy_train.png',
      );
    case 'deco_desk_calculator':
      return const _MiniroomVisualSpec(
        icon: Icons.calculate_rounded,
        gradient: [Color(0xFFE8F0FF), Color(0xFFC7D9FF)],
        assetPath: 'assets/miniroom/generated/item_desk_calculator.png',
      );
    case 'deco_desk_lamp':
      return const _MiniroomVisualSpec(
        icon: Icons.lightbulb_rounded,
        gradient: [Color(0xFFFFF3C9), Color(0xFFFFE39E)],
        assetPath: 'assets/miniroom/generated/item_desk_focus_lamp.png',
      );
    case 'deco_shelf_clock':
      return const _MiniroomVisualSpec(
        icon: Icons.schedule_rounded,
        gradient: [Color(0xFFEDEDF8), Color(0xFFD5D8EB)],
        assetPath: 'assets/miniroom/generated/item_wall_clock.png',
      );
    case 'deco_window_sunrain':
      return const _MiniroomVisualSpec(
        icon: Icons.wb_cloudy_rounded,
        gradient: [Color(0xFFE4F5FF), Color(0xFFCBEAFF)],
        assetPath: 'assets/miniroom/generated/item_window_sun_rain_mobile.png',
      );
    default:
      return const _MiniroomVisualSpec(
        icon: Icons.home_filled,
        gradient: [Color(0xFFE9EEFF), Color(0xFFD3DCFF)],
      );
  }
}

class _DecorationObject extends StatelessWidget {
  const _DecorationObject({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final visual = _miniroomSpecForItem(item);
    return Center(
      child: visual.assetPath != null
          ? Image.asset(
              visual.assetPath!,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stackTrace) => Icon(
                visual.icon,
                size: 42,
                color: visual.iconColor ?? const Color(0xFF34415F),
              ),
            )
          : Icon(
              visual.icon,
              size: 42,
              color: visual.iconColor ?? const Color(0xFF34415F),
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
    final visual = _miniroomSpecForItem(item);
    final size = compact ? 60.0 : 112.0;

    return SizedBox(
      width: size,
      height: size,
      child: visual.assetPath != null
          ? Image.asset(
              visual.assetPath!,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stackTrace) => Icon(
                visual.icon,
                size: compact ? 30 : 48,
                color: visual.iconColor ?? const Color(0xFF34415F),
              ),
            )
          : Icon(
              visual.icon,
              size: compact ? 30 : 48,
              color: visual.iconColor ?? const Color(0xFF34415F),
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
        width: 88,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? AppDesign.secondarySoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppDesign.secondary : AppDesign.border,
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
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppDesign.secondarySoft, AppDesign.primarySoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppDesign.cardRadius,
              boxShadow: AppDesign.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🛍️ 포인트 상점', style: AppDesign.title),
                  const SizedBox(height: 6),
                  Text(
                    '현재 포인트: ${state.rewardPoints}P · 누적 사용: ${state.totalPointsSpent}P',
                    style: AppDesign.subtitle,
                  ),
                  Text(
                    '장착 중: ${state.equippedCharacter.name} / ${state.equippedHome.name}',
                    style: AppDesign.subtitle,
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
    return AppCard(
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
                    ? AppDesign.primarySoft
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
    );
  }
}

class _WeeklyReportTab extends StatelessWidget {
  const _WeeklyReportTab({
    required this.state,
    required this.onStartReview,
    required this.isReviewRunning,
    required this.onClaimMission,
    required this.onClaimWeeklyMission,
    required this.seoulDateKey,
    required this.skippedMalformedScenarioCount,
  });

  final AppState state;
  final VoidCallback onStartReview;
  final bool isReviewRunning;
  final ValueChanged<DailyMissionType> onClaimMission;
  final ValueChanged<WeeklyMissionType> onClaimWeeklyMission;
  final String seoulDateKey;
  final int skippedMalformedScenarioCount;

  String _dateKeySeoul(DateTime dateTime) {
    final kst = dateTime.toUtc().add(_kSeoulOffset);
    final month = kst.month.toString().padLeft(2, '0');
    final day = kst.day.toString().padLeft(2, '0');
    return '${kst.year}-$month-$day';
  }

  ({int solved, int correct, int reviewDone}) _todayProgress() {
    final todayResults = state.results
        .where((e) => _dateKeySeoul(e.timestamp) == seoulDateKey)
        .toList();
    return (
      solved: todayResults.length,
      correct: todayResults.where((e) => e.judgementScore >= 70).length,
      reviewDone: state.dailyReviewCompletedCount,
    );
  }

  ({String weekKey, int solved, int avgRisk, int balancedCount})
  _thisWeekProgress() {
    final weekKey = buildSeoulWeekKey(DateTime.now());
    final weekResults = state.results
        .where((e) => buildSeoulWeekKey(e.timestamp) == weekKey)
        .toList();
    final solved = weekResults.length;
    final avgRisk = solved == 0
        ? 0
        : (weekResults.fold<int>(0, (sum, e) => sum + e.riskManagementScore) /
                  solved)
              .round();
    final balancedCount = weekResults
        .where((e) => e.allocationPercent >= 35 && e.allocationPercent <= 65)
        .length;
    return (
      weekKey: weekKey,
      solved: solved,
      avgRisk: avgRisk,
      balancedCount: balancedCount,
    );
  }

  bool _isComplete(
    DailyMissionType type,
    ({int solved, int correct, int reviewDone}) progress,
  ) {
    return switch (type) {
      DailyMissionType.solveFive => progress.solved >= 5,
      DailyMissionType.accuracy70 =>
        progress.solved > 0 &&
            ((progress.correct / progress.solved) * 100) >= 70,
      DailyMissionType.reviewOne => progress.reviewDone >= 1,
    };
  }

  String _progressLabel(
    DailyMissionType type,
    ({int solved, int correct, int reviewDone}) progress,
  ) {
    return switch (type) {
      DailyMissionType.solveFive => '${progress.solved}/5',
      DailyMissionType.accuracy70 =>
        progress.solved == 0
            ? '0% (0/0)'
            : '${((progress.correct / progress.solved) * 100).round()}% (${progress.correct}/${progress.solved})',
      DailyMissionType.reviewOne => '${progress.reviewDone}/1',
    };
  }

  bool _isWeeklyComplete(
    WeeklyMissionType type,
    ({String weekKey, int solved, int avgRisk, int balancedCount}) progress,
  ) {
    return switch (type) {
      WeeklyMissionType.balancedInvestor =>
        progress.solved >= 6 &&
            progress.avgRisk >= 72 &&
            progress.balancedCount >= 4,
    };
  }

  String _weeklyProgressLabel(
    WeeklyMissionType type,
    ({String weekKey, int solved, int avgRisk, int balancedCount}) progress,
  ) {
    return switch (type) {
      WeeklyMissionType.balancedInvestor =>
        '풀이 ${progress.solved}/6 · 평균 위험관리 ${progress.avgRisk}/72 · 균형 비중 ${progress.balancedCount}/4',
    };
  }

  String _decisionInterpretation({
    required int judgement,
    required int risk,
    required int emotion,
  }) {
    final quality = ((judgement + risk + emotion) / 3).round();
    if (quality >= 82) {
      return '결정의 질이 매우 좋아요. 근거 확인 → 비중 조절 → 감정 통제가 안정적으로 이어졌어요.';
    }
    if (quality >= 65) {
      return '결정의 질이 성장 구간이에요. 방향은 맞고, 비중 조절 일관성만 더해지면 점프할 수 있어요.';
    }
    return '결정의 질이 기초 다지기 단계예요. 뉴스 근거를 1개 더 확인하고 작은 비중부터 시작하면 좋아요.';
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
    final recentWrong = state.wrongAnswerNotes.toList()
      ..sort((a, b) => b.wrongAt.compareTo(a.wrongAt));
    final pendingWrong = recentWrong.where((e) => !e.isCleared).toList();
    final progress = _todayProgress();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            color: const Color(0xFFF2EEFF),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Builder(
                builder: (context) {
                  final weekly = _thisWeekProgress();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🗓️ 주간 미션 센터',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text('이번 주 코드: ${weekly.weekKey}'),
                      const SizedBox(height: 8),
                      ...WeeklyMissionType.values.map((type) {
                        final completed = _isWeeklyComplete(type, weekly);
                        final claimed = state.weeklyClaimedMissionIds.contains(
                          type.key,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDCD4FF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${type.subtitle}\n${_weeklyProgressLabel(type, weekly)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '보상 +${type.rewardCoins}코인 +${type.rewardPoints}P',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  FilledButton.tonal(
                                    onPressed: claimed || !completed
                                        ? null
                                        : () => onClaimWeeklyMission(type),
                                    child: Text(
                                      claimed
                                          ? '수령완료'
                                          : completed
                                          ? '보상받기'
                                          : '진행중',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFFEFFAF1),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎯 데일리 미션',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text('기준일: $seoulDateKey (Asia/Seoul)'),
                  const SizedBox(height: 8),
                  Text(
                    'debug · 스킵된 malformed 시나리오: $skippedMalformedScenarioCount',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...DailyMissionType.values.map((type) {
                    final completed = _isComplete(type, progress);
                    final claimed = state.dailyClaimedMissionIds.contains(
                      type.key,
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD7E6EF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${type.subtitle} · 진행 ${_progressLabel(type, progress)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '보상 +${type.rewardCoins}코인 +${type.rewardPoints}P',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              FilledButton.tonal(
                                onPressed: claimed || !completed
                                    ? null
                                    : () => onClaimMission(type),
                                child: Text(
                                  claimed
                                      ? '수령완료'
                                      : completed
                                      ? '보상받기'
                                      : '진행중',
                                ),
                              ),
                            ],
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
            color: const Color(0xFFFFF7E8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📝 오답 노트',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '남은 복습 ${pendingWrong.length}개 · 최근 기록 ${recentWrong.length}개',
                  ),
                  const SizedBox(height: 8),
                  if (recentWrong.isEmpty)
                    const Text('아직 오답 노트가 없어요. 탐험에서 틀린 문제가 여기에 쌓여요!')
                  else
                    ...recentWrong
                        .take(6)
                        .map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${note.scenarioTitle} · ${note.stageType.label} · ${note.isCleared ? '복습 완료' : '복습 필요'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: isReviewRunning ? null : onStartReview,
                    icon: const Icon(Icons.replay_circle_filled_rounded),
                    label: Text(isReviewRunning ? '복습 진행 중' : '복습 시작 (3문제)'),
                  ),
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
                    '📊 성장 리포트 (핵심 점수)',
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
                    '위험 관리 점수',
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
                    Text('판단 정확도: $judge점 · 위험 관리: $risk점 · 감정 통제: $emotion점'),
                    const SizedBox(height: 6),
                    Text(
                      '결정 해석: ${_decisionInterpretation(judgement: judge, risk: risk, emotion: emotion)}',
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

  String _friendlyAuthError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('invalid_credentials')) {
      return '이메일 또는 비밀번호가 맞지 않아요. 기존 계정이면 로그인, 처음이면 회원가입을 눌러줘.';
    }
    if (raw.contains('user_exists') || raw.contains('already')) {
      return '이미 가입된 이메일이야. 로그인으로 진행해줘.';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return '네트워크 연결이 불안정해. 잠시 후 다시 시도해줘.';
    }
    return '인증에 실패했어. 잠시 후 다시 시도해줘.';
  }

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
      if (mounted) setState(() => _message = _friendlyAuthError(e));
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
                '• 어려움: 다음 영향까지 생각 + 나눠서 계획 세우기\n'
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
