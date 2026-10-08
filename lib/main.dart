import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:mobile_app/go_router/router_generator.dart';
import 'package:mobile_app/screens/welcome_screen.dart';
import 'package:mobile_app/screens/role_selecting_screen.dart';
import 'package:mobile_app/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey = 'pk_test_51TehYmRrXpjs70YAmxdyM5BPPZISo5TLIj49xvLAyUx0HQ314SoRoogJf6hHmwQxjY9aJVrHKgYXgf8aO34vCErC00DbL0icOA';
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: kIsWeb?
      const Size(1440, 900) :
      const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      child: MaterialApp.router(
          title: 'ResQ',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          routerConfig: RouterGenerationConfig.gorouter),
    );

  }


}