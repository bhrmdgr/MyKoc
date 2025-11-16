import 'package:flutter/material.dart';
import 'package:mykoc/pages/auth/sign_in/signIn.dart';
import 'package:mykoc/pages/auth/sign_up/signUp.dart';
import 'package:mykoc/pages/home/homeView.dart';

// Navigation functions

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
    MaterialPageRoute(builder: (context) => const HomeView()),
  );
}

void goBack(BuildContext context) {
  Navigator.pop(context);
}