import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../AuthRepository.dart';
import '../navigation/AuthCubit.dart';
import 'LoginBloc.dart';
import 'LoginEvent.dart';
import 'LoginState.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocProvider(
        create: (context) => LoginBloc(
          authRepository: context.read<AuthRepository>(),
          navigationCubit: context.read<AuthCubit>(),
        ),
        child: const _LoginForm(),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state.status == LoginStatus.success) {
          context.read<AuthCubit>().launchSession();
        }
      },
      builder: (context, state) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Love Your Meal',
                  style: GoogleFonts.pacifico(
                    fontSize: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),

                TextField(
                  onChanged: (value) => context
                      .read<LoginBloc>()
                      .add(LoginEmailChanged(value)),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  onChanged: (value) => context
                      .read<LoginBloc>()
                      .add(LoginPasswordChanged(value)),
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Passwort',
                  ),
                ),
                const SizedBox(height: 16),

                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: state.status == LoginStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: () => context
                        .read<LoginBloc>()
                        .add(LoginSubmitted()),
                    child: const Text('Login'),
                  ),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.read<AuthCubit>().showSignUp(),
                  child: const Text('Account erstellen'),
                ),
                TextButton(
                  onPressed: () => context.read<AuthCubit>().showForgotPassword(),
                  child: const Text('Password vergessen'),
                ),


              ],
            ),
          ),
        );
      },
    );
  }
}
