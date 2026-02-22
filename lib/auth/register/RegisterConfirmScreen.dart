import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation/AuthCubit.dart';

class RegisterConfirmScreen extends StatelessWidget {
  const RegisterConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
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

                const Icon(
                  Icons.mark_email_read_rounded,
                  size: 72,
                ),
                const SizedBox(height: 24),

                const Text(
                  'E-Mail bestätigt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Eine Bestätigungs-E-Mail wurde an dich gesendet.\n'
                      'Bitte überprüfe dein Postfach und folge den Anweisungen.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () =>
                        context.read<AuthCubit>().showLogin(),
                    child: const Text('Zurück zum Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
