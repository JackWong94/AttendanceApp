import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'services/tenant_model_service.dart';
import 'models/tenant_model.dart';
import 'pages/web_login_page.dart';
import 'pages/login_user_page.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    // ✅ already logged in
    final tenant = await TenantModelService.instance.getTenantByEmail(user.email!);
    if (tenant != null) {
      TenantModelService.instance.setTenant(tenant);
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      home: FirebaseAuth.instance.currentUser != null
          ? const LoginUserPage() // user already logged in
          : const WebLoginPage(),  // otherwise login
      routes: {
        '/login': (_) => const LoginUserPage(),
      },
      navigatorObservers: [routeObserver],
    );
  }
}
