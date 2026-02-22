import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../AuthRepository.dart';
import '../navigation/AuthCubit.dart';
import 'RegisterBloc.dart';
import 'RegisterEvent.dart';
import 'RegisterState.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: BlocProvider(
        create: (context) => RegisterBloc(
          authRepository: context.read<AuthRepository>(),
          navigationCubit: context.read<AuthCubit>(),
        ),
        child: const _RegisterForm(),
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc, RegisterState>(
      listener: (context, state) {
        if (state.status == RegisterStatus.success) {
          context.read<AuthCubit>().showConfirm();
        }
      },
      builder: (context, state) {
        return SafeArea(
          child: Center(
            child: SingleChildScrollView(
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

                  // EMAIL
                  TextField(
                    onChanged: (value) => context
                        .read<RegisterBloc>()
                        .add(RegisterEmailChanged(value)),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PASSWORD
                  TextField(
                    onChanged: (value) => context
                        .read<RegisterBloc>()
                        .add(RegisterPasswordChanged(value)),
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CONFIRM PASSWORD
                  TextField(
                    onChanged: (value) => context
                        .read<RegisterBloc>()
                        .add(RegisterConfirmPasswordChanged(value)),
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Passwort bestätigen',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ERROR MESSAGE
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  // BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: state.status == RegisterStatus.loading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: () => context
                          .read<RegisterBloc>()
                          .add(RegisterSubmitted()),
                      child: const Text('Registrieren'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // BACK TO LOGIN
                  TextButton(
                    onPressed: () =>
                        context.read<AuthCubit>().showLogin(),
                    child: const Text('Zurück zum Login'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
