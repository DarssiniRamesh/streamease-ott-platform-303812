import 'package:flutter/material.dart';
import 'package:ott_frontend/app.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = await AppBootstrap.bootstrap();
  runApp(StreamEaseApp(deps: deps));
}
