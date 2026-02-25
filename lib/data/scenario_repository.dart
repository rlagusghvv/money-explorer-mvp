import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/scenario.dart';

class ScenarioLoadOutcome {
  const ScenarioLoadOutcome({
    required this.scenarios,
    required this.skippedMalformedCount,
  });

  final List<Scenario> scenarios;
  final int skippedMalformedCount;
}

class ScenarioRepository {
  static int _lastSkippedMalformedCount = 0;

  static int get lastSkippedMalformedCount => _lastSkippedMalformedCount;

  static Future<List<Scenario>> loadScenarios() async {
    final raw = await rootBundle.loadString('assets/scenarios.json');
    final outcome = parseScenariosJson(raw);
    _lastSkippedMalformedCount = outcome.skippedMalformedCount;
    if (_lastSkippedMalformedCount > 0) {
      debugPrint(
        '[ScenarioRepository] malformed scenario skipped: $_lastSkippedMalformedCount',
      );
    }
    return outcome.scenarios;
  }

  static ScenarioLoadOutcome parseScenariosJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return const ScenarioLoadOutcome(scenarios: [], skippedMalformedCount: 0);
    }

    final scenariosRaw = decoded['scenarios'];
    if (scenariosRaw is! List<dynamic>) {
      return const ScenarioLoadOutcome(scenarios: [], skippedMalformedCount: 0);
    }

    final scenarios = <Scenario>[];
    var skippedMalformedCount = 0;
    for (final item in scenariosRaw) {
      if (item is! Map<String, dynamic>) {
        skippedMalformedCount += 1;
        continue;
      }
      try {
        scenarios.add(Scenario.fromJson(item));
      } catch (_) {
        skippedMalformedCount += 1;
      }
    }

    scenarios.sort((a, b) => a.id.compareTo(b.id));
    return ScenarioLoadOutcome(
      scenarios: scenarios,
      skippedMalformedCount: skippedMalformedCount,
    );
  }
}
