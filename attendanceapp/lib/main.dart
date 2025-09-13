import 'package:flutter/material.dart';
import 'package:attendanceapp/pages/login_user_page.dart';
import 'package:attendanceapp/pages/register_user_page.dart';
import 'package:attendanceapp/services/camera_service.dart'; // ✅ import CameraService

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CameraService().initCamera(forceReinitOnWeb: true); // ✅ Initialize shared camera

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/register': (context) => const RegisterUserPage(), // ✅ no camera param
        '/login': (context) => const LoginUserPage(),       // ✅ no camera param
      },
    );
  }
}
