import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:attendanceapp/pages/web_login_page.dart';
import 'package:attendanceapp/pages/login_user_page.dart';
import 'package:attendanceapp/configs_and_tools/data_migrate.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "main", enable: true);
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  debug.log("🚀 App start");
  WidgetsFlutterBinding.ensureInitialized();
  final opts = DefaultFirebaseOptions.currentPlatform;

  await Firebase.initializeApp(options: opts);

  //await runMigrationScript(); DO NOT REMOVE OR RUN IT UNLESS YOU KNOW WHAT YOU ARE DOING
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      home: const WebLoginPage(),
      navigatorObservers: [routeObserver],
    );
  }
}
