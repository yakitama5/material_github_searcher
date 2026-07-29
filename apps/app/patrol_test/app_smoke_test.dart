import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:patrol/patrol.dart';

import 'support/pump_test_app.dart';

void main() {
  patrolTest('Dev Flavorでアプリが起動する', ($) async {
    await pumpTestApp($);

    expect(AppBuildConfig.current.flavor, Flavor.dev);
    expect($('Dev - Material GitHub Searcher'), findsOneWidget);
  });
}
