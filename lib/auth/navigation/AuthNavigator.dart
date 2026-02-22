import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/auth/login/LoginScreen.dart';
import 'package:recipeapp_frontend/auth/register/RegisterScreen.dart';

import '../forgot_password/ForgotPasswordScreen.dart';
import '../register/RegisterConfirmScreen.dart';
import 'AuthCubit.dart';

class AuthNavigator extends StatelessWidget {
  const AuthNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return Navigator(
          pages: [
            const MaterialPage(child: LoginScreen()),

            if (state == AuthState.register)
              const MaterialPage(child: RegisterScreen()),

            if (state == AuthState.confirm)
              const MaterialPage(child: RegisterConfirmScreen()),

            if (state == AuthState.forgotPassword)
              const MaterialPage(child: ForgotPasswordScreen()),
          ],
          onPopPage: (route, result) {
            if (!route.didPop(result)) return false;

            context.read<AuthCubit>().showLogin();
            return true;
          },
        );
      },
    );
  }
}
