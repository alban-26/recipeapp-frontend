import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../AuthRepository.dart';
import '../navigation/AuthCubit.dart';
import 'ForgotPasswordBloc.dart';
import 'ForgotPasswordEvent.dart';
import 'ForgotPasswordState.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocProvider(
        create: (context) => ForgotPasswordBloc(
          authRepository: context.read<AuthRepository>(),
        ),
        child: const _ForgotPasswordForm(),
      ),
    );
  }
}

class _ForgotPasswordForm extends StatelessWidget {
  const _ForgotPasswordForm();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ForgotPasswordBloc, ForgotPasswordState>(
      listener: (context, state) {
        if (state.status == ForgotPasswordStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Wenn die E-Mail existiert, wurde ein Passwort-Zurücksetzen-Link verschickt.',
              ),
            ),
          );

          context.read<AuthCubit>().showLogin();
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
                  'Password zurücksetzen',
                  style: GoogleFonts.pacifico(
                    fontSize: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),

                TextField(
                  onChanged: (value) => context
                      .read<ForgotPasswordBloc>()
                      .add(ForgotPasswordEmailChanged(value)),
                  decoration: const InputDecoration(
                    labelText: 'Email',
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
                  child: state.status == ForgotPasswordStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: () => context
                        .read<ForgotPasswordBloc>()
                        .add(ForgotPasswordSubmitted()),
                    child: const Text('Reset-Link senden'),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () =>
                      context.read<AuthCubit>().showLogin(),
                  child: const Text('Zurück zum Login'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
