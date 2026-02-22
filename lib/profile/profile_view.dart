import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../StorageRepository.dart';
import '../auth/AuthRepository.dart';
import '../session/SessionCubit.dart';
import '../widgets/CommonAppBar.dart';

import 'profile_bloc.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionCubit = context.read<SessionCubit>();

    return BlocProvider(
      create: (context) => ProfileBloc(
        storageRepo: context.read<StorageRepository>(),
        authRepo: context.read<AuthRepository>(),
        user: sessionCubit.user,
      ),
      child: Scaffold(
        appBar: CommonAppBar(title: 'Profil'),
        body: const _ProfileContent(),
      ),
    );
  }
}

/* ───────────────────────── PROFILE CONTENT ───────────────────────── */

class _ProfileContent extends StatelessWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileHeader(email: state.email),
            const SizedBox(height: 24),
            _ActionTile(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () => context.read<SessionCubit>().logout(),
            ),
            const SizedBox(height: 24),
            const _DangerZone(),
          ],
        );
      },
    );
  }
}

/* ───────────────────────── PROFILE HEADER ───────────────────────── */

class _ProfileHeader extends StatelessWidget {
  final String email;

  const _ProfileHeader({required this.email});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: primary.withOpacity(0.15),
              child: Icon(Icons.person, size: 36, color: primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Angemeldet als',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  _EmailText(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailText extends StatelessWidget {
  const _EmailText();

  @override
  Widget build(BuildContext context) {
    final email = context.select(
          (ProfileBloc bloc) => bloc.state.email,
    );

    return Text(
      email,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}


class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}


class _DangerZone extends StatelessWidget {
  const _DangerZone();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        title: const Text(
          'Account löschen',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: const Text(
          'Diese Aktion kann nicht rückgängig gemacht werden',
        ),
        onTap: () => _confirmDelete(context),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account wirklich löschen?'),
        content: const Text(
          'Dein Account wird dauerhaft gelöscht und kann nicht '
              'wiederhergestellt werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              context.read<ProfileBloc>().add(DeleteAccountEvent());
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
