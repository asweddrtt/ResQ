import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.grey.withOpacity(0.1),
                ),
                SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        height: 70.h,
                        width: 70.w,
                        decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(15.r)),
                        child: Image.asset(
                          "assets/images/logo.PNG",
                          height: 40.h,
                          width: 60.w,
                        ),
                      ),
                      SizedBox(
                        height: 15.h,
                      ),
                      Text("ResQ",
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.bold,
                              fontSize: 28.sp // Adjusted: 28 (Was 32)
                          )),
                      SizedBox(
                        height: 10.h,
                      ),
                      Text("helping animals through community action",
                          style: GoogleFonts.nunito(
                              fontSize: 12.sp, // Adjusted: 12 (standard read size)
                              color: Colors.grey)),
                      SizedBox(
                        height: 20.h,
                      ),
                      Container(
                        width: 325.w, // Adjusted: 325 (Fits 360 width better)
                        constraints: BoxConstraints(minHeight: 300.h),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(25.r)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 25.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Welcome to ResQ",
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22.sp, // Adjusted: 22
                                  )),
                              SizedBox(height: 8.h),

                              Text(
                                  "Sign in or create an account to report, adopt or support rescues",
                                  style: GoogleFonts.nunito(
                                      fontSize: 12.sp,
                                      color: Colors.grey)),
                              SizedBox(
                                height: 25.h,
                              ),

                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 280.w,
                                  height: 48.h, // Adjusted: 48 (Good touch target)
                                  decoration: BoxDecoration(
                                      color: Color(0xffffa94d),
                                      borderRadius: BorderRadius.circular(30.r)),
                                  child: TextButton(
                                      onPressed: () {
                                        context.push("/sign_in");
                                      },
                                      child: Text(
                                        "Login",
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 16.sp, // Adjusted: 16
                                            fontWeight: FontWeight.w600),
                                      )),
                                ),
                              ),
                              SizedBox(
                                height: 12.h,
                              ),

                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 280.w,
                                  height: 48.h, // Adjusted: 48
                                  decoration: BoxDecoration(
                                      color: Color(0xff5bb381),
                                      borderRadius: BorderRadius.circular(30.r)),
                                  child: TextButton(
                                      onPressed: () {
                                        context.push("/role_selection");
                                      },
                                      child: Text("Create account",
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w600))),
                                ),
                              ),
                              SizedBox(
                                height: 20.h,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                        height: 1.h,
                                        thickness: 1.h,
                                        color: Colors.grey.withOpacity(0.5)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("or continue with",
                                        style: GoogleFonts.nunito(
                                            fontSize: 12.sp,
                                            color: Colors.grey)),
                                  ),
                                  Expanded(
                                    child: Divider(
                                        height: 1.h,
                                        thickness: 1.h,
                                        color: Colors.grey.withOpacity(0.5)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 15.h),

                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 280.w,
                                  height: 48.h, // Adjusted: 48
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(30.r),
                                      border: Border.all(
                                          color: Colors.grey.withOpacity(0.5))),
                                  child: TextButton(
                                      onPressed: () {},
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            "assets/icons/google.webp",
                                            height: 22.h,
                                            width: 22.w,
                                          ),
                                          SizedBox(
                                            width: 10.w,
                                          ),
                                          Text(
                                            "Continue with Google",
                                            style: TextStyle(color: Colors.black, fontSize: 14.sp),
                                          ),
                                        ],
                                      )),
                                ),
                              ),
                              SizedBox(
                                height: 12.h,
                              ),

                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 280.w,
                                  height: 48.h, // Adjusted: 48
                                  decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(30.r)),
                                  child: TextButton(
                                      onPressed: () {},
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            "assets/icons/apple.png",
                                            color: Colors.white,
                                            height: 22.h,
                                            width: 22.w,
                                          ),
                                          SizedBox(
                                            width: 10.w,
                                          ),
                                          Text(
                                            "Continue with Apple",
                                            style: TextStyle(color: Colors.white, fontSize: 14.sp),
                                          ),
                                        ],
                                      )),
                                ),
                              ),
                              SizedBox(
                                height: 15.h,
                              ),
                              Center(
                                child: Text(
                                  "by continuing you agree to our terms and conditions",
                                  textAlign: TextAlign.center,
                                  style:
                                  TextStyle(fontSize: 10.sp, color: Colors.grey),
                                ),
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}