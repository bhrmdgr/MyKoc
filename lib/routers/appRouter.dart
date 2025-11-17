import 'package:flutter/material.dart';
import 'package:mykoc/pages/auth/sign_in/signIn.dart';
import 'package:mykoc/pages/auth/sign_up/signUp.dart';
import 'package:mykoc/pages/main/main_screen.dart';
import 'package:mykoc/pages/classroom/create_class/create_class_view.dart';

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

Future<bool?> navigateToCreateClass(BuildContext context) async {
  return await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (context) => const CreateClassView()),
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