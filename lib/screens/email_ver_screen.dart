import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class EmailVerScreen extends StatefulWidget {
  const EmailVerScreen({super.key});

  @override
  State<EmailVerScreen> createState() => _EmailVerScreenState();
}

class _EmailVerScreenState extends State<EmailVerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey.withOpacity(0.2)
            ),
            Container(
              width: 325,
              constraints: BoxConstraints(minHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 60.h,
                      width: 60.h,
                      decoration: BoxDecoration(
                        color: Colors.green,
                      borderRadius: BorderRadius.circular(15.h))

                    ),
                    SizedBox(height: 20),
                    Text(
                      "Verify your email",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "A verification link has been sent to your email. Please check your inbox and click the link to verify your account.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: const Color(0xffffa94d), // Orange
                        borderRadius: BorderRadius.circular(30.r),
                      ),
                      child: TextButton(
                        onPressed: () {
                          final role = GoRouterState.of(context).extra as String? ?? 'volunteer';
                          if (role == 'volunteer') {
                            context.push("/identity_ver");
                          } else if (role == 'clinic') {
                            context.push("/clinic_home");
                          } else if (role == 'shelter') {
                            context.push("/shelter_home");
                          }
                            else {
                            context.push("/home");
                          }

                        },
                        child: Text(
                          "Next",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  ],
                            ),
              )
                        ),
          ],
        ),
    )
    );
  }
}
