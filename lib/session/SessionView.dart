import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'SessionCubit.dart';

class SessionView extends StatelessWidget {
  const SessionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Session'),
            TextButton(
              child: const Text('Logout'),
              onPressed: () => BlocProvider.of<SessionCubit>(context).logout(),
            )
          ],
        ),
      ),
    );
  }
}
