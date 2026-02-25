import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/scenario.dart';

class ScenarioRepository {
  static Future<List<Scenario>> loadScenarios() async {
    final raw = await rootBundle.loadString('assets/scenarios.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final scenariosRaw = decoded['scenarios'];
    if (scenariosRaw is! List<dynamic>) {
      return const [];
    }

    final scenarios = <Scenario>[];
    for (final item in scenariosRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      try {
        scenarios.add(Scenario.fromJson(item));
      } catch (_) {
        continue;
      }
    }

    scenarios.sort((a, b) => a.id.compareTo(b.id));
    return scenarios;
  }
}
