import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:attendanceapp/pages/web_login_page.dart';
import 'package:attendanceapp/pages/login_user_page.dart';
import 'package:attendanceapp/services/user_service.dart';
import 'package:attendanceapp/repositories/user_repository.dart';
import 'package:attendanceapp/viewmodels/user_viewmodel.dart';
import 'package:attendanceapp/viewmodels/auth_viewmodel.dart';
import 'package:attendanceapp/usecases/user/get_all_users_usecase.dart';
import 'package:attendanceapp/configs_and_tools/data_migrate.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "main", enable: true);

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  debug.log("🚀 App start");
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final opts = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(options: opts);
    debug.log("✅ Firebase initialized");
  } catch (e, st) {
    debug.log("❌ Firebase init failed: $e\n$st");
  }
  //await runMigrationScript(); DO NOT REMOVE OR RUN IT UNLESS YOU KNOW WHAT YOU ARE DOING
  runApp(
    MultiProvider(
      providers: [
        // 1. Auth is global (always exists)
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(),
        ),

        // 2. User depends on Auth → use ProxyProvider
        ChangeNotifierProxyProvider<AuthViewModel, UserViewModel>(
          create: (_) => UserViewModel(
              GetAllUsersUseCase(
                UserRepository(
                  UserService(FirebaseFirestore.instance),
                  "",
                ),
              ),
          ),

          update: (_, authVm, userVm) {
            final tenantId = authVm.tenantId ?? "";

            return UserViewModel(
              GetAllUsersUseCase(
                UserRepository(
                  UserService(FirebaseFirestore.instance),
                  tenantId,
                ),
              ),
            );
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
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
