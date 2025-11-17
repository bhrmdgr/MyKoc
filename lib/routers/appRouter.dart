// lib/routers/appRouter.dart
import 'package:flutter/material.dart';
import 'package:mykoc/pages/auth/sign_in/signIn.dart';
import 'package:mykoc/pages/auth/sign_up/signUp.dart';
import 'package:mykoc/pages/main/main_screen.dart';

void navigateToSignIn(BuildContext context) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const Signin()),
  );
}

void navigateToSignUp(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const Signup()),
  );
}

void navigateToHome(BuildContext context) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const MainScreen()),
  );
}

void goBack(BuildContext context) {
  Navigator.pop(context);
}