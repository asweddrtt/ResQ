import 'package:go_router/go_router.dart';
import 'package:mobile_app/go_router/routes.dart';
import 'package:mobile_app/screens/chat_screen.dart';
import 'package:mobile_app/screens/clinic_reg.dart';
import 'package:mobile_app/screens/email_ver_screen.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/screens/identity_ver.dart';
import 'package:mobile_app/screens/report_case_screen.dart';
import 'package:mobile_app/screens/shelter_home_screen.dart';
import 'package:mobile_app/screens/shelter_reg.dart';
import 'package:mobile_app/screens/sign_in.dart';
import 'package:mobile_app/screens/register_screen.dart';
import 'package:mobile_app/screens/role_selecting_screen.dart';
import 'package:mobile_app/screens/support_chat_screen.dart';

import '../screens/add_adoption.dart';
import '../screens/chat_room.dart';
import '../screens/clinics_home.dart';
import '../screens/welcome_screen.dart';

class RouterGenerationConfig {
  static GoRouter gorouter = GoRouter(
    initialLocation: AppRoutes.welcome,
    routes: [
      GoRoute(
    path: AppRoutes.welcome,
    name: '/welcome',
    builder: (context, state) => WelcomeScreen(),
  ),
      GoRoute(
        path: AppRoutes.roleSelection,
        name: '/role_selection',
        builder: (context, state) => RoleSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatRoom,
        name: 'chat_room',
        builder: (context, state) {
          // 🚨 CHANGED: Extracts a Map so we can pass both name and ID
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final chatName = extra['name'] as String? ?? 'Chat';
          final conversationId = extra['id'] as String? ?? '';

          return ChatScreen(chatName: chatName, conversationId: conversationId);
        },
      ),
      GoRoute(
        path: AppRoutes.identityVer,
        name: '/identity_ver',
        builder: (context, state) => IdentityVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportCase,
        name: '/report_case',
        builder: (context, state) => ReportCaseScreen(),
      ),
      GoRoute(path: AppRoutes.addAdoption,
        name: '/add_adoption',
        builder: (context, state) => AddAdoptionScreen(),
      ),
      GoRoute(path: AppRoutes.shelterHome,
        name: '/shelter_home',
        builder: (context, state) => ShelterHomeScreen(),
      ),


      GoRoute(
        path: AppRoutes.userReg,
        name: '/user_reg',
        builder: (context, state) => RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: '/sign_in',
        builder: (context, state) => SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.messages,
        name: 'messages',
        builder: (context, state) => MessagesScreen(isShelter: false),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: '/home',
        builder: (context, state) => HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.supportChat,
        name: '/supportChat',
        builder: (context, state) => SupportChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.shelterReg,
        name: '/shelter_reg',
        builder: (context, state) => ShelterRegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.clinicReg,
        name: '/clinic_reg',
        builder: (context, state) => ClinicReg(),
      ),
      GoRoute(
        path: AppRoutes.emailVer,
        name: '/email_ver',
        builder: (context, state) => EmailVerScreen(),
      ),

      GoRoute(
        path: AppRoutes.clinicHome, // Ensure this is in your AppRoutes!
        name: '/clinic_home',
        builder: (context, state) => const ClinicHomeScreen(),
      ),



    ]
  );
}