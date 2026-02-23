import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/scenario.dart';

class ScenarioRepository {
  static Future<List<Scenario>> loadScenarios() async {
    final raw = await rootBundle.loadString('assets/scenarios.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final scenarios = decoded['scenarios'] as List<dynamic>;

    return scenarios
        .map((e) => Scenario.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }
}
