import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:mobile_app/go_router/router_generator.dart';
import 'package:mobile_app/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

const double _kDesignWidth  = 390.0;
const double _kDesignHeight = 844.0;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Stripe.publishableKey =
  'pk_test_51TehYmRrXpjs70YAmxdyM5BPPZISo5TLIj49xvLAyUx0HQ314SoRoogJf6hHmwQxjY9aJVrHKgYXgf8aO34vCErC00DbL0icOA';

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(_kDesignWidth, _kDesignHeight),
      minTextAdapt: true,
      splitScreenMode: false,
      // Disable scaling on web — raw values fit perfectly in the 390-wide frame.
      enableScaleWH: kIsWeb ? () => false : null,
      enableScaleText: kIsWeb ? () => false : null,
      builder: (_, __) {
        if (kIsWeb) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _appTheme,
            home: _WebShell(),
          );
        }
        return MaterialApp.router(
          title: 'ResQ',
          debugShowCheckedModeBanner: false,
          theme: _appTheme,
          routerConfig: RouterGenerationConfig.gorouter,
        );
      },
    );
  }
}

ThemeData get _appTheme => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  useMaterial3: true,
);

class _WebShell extends StatelessWidget {
  static const Color _bgColor = Color(0xFF0F0F1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Width is always fixed at 390 (phone width).
            // Height fills the browser window so nothing gets cut off,
            // but never exceeds 844 (so it still looks like a phone on tall screens).
            final frameH = constraints.maxHeight.clamp(0.0, _kDesignHeight);

            return Container(
              width: _kDesignWidth,
              height: frameH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 60,
                    spreadRadius: 10,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: _appTheme,
                  routerConfig: RouterGenerationConfig.gorouter,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}