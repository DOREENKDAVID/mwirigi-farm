import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/service/api_service.dart';

/// Custom AppBar shown at the top of MainScreen.
///
/// Renders: page title (left), current date, sign-out (right). Records
/// stream in from the offline-first repositories, so there's no need
/// for a Live/Simulate toggle here anymore.
class FarmTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FarmTopBar({
    super.key,
    required this.title,
    this.showMenuButton = true,
  });

  final String title;
  /// Hide the hamburger when the drawer is rendered permanently as a
  /// sidebar (tablet layout).
  final bool showMenuButton;

  static const _primary = Color(0xFF27500A);

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(DateTime.now());

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _primary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: showMenuButton,
      shape: const Border(
        bottom: BorderSide(color: Color(0x14000000)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A18),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              Text(
                dateLabel,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(width: 10),
              const _SignOutButton(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sign-out button. Confirms first (one tap could log out an admin
/// mid-task), then calls ApiService.logout() — which best-effort revokes
/// the refresh token server-side and wipes local secure-storage tokens —
/// then navigates back to the login screen using the global navigator
/// key so any nested routes are popped.
class _SignOutButton extends StatefulWidget {
  const _SignOutButton();

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _busy = false;

  Future<void> _confirmAndSignOut() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access the farm dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB52C2B),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ApiService.logout();
    } catch (_) {
      // logout() is already best-effort internally; ignore.
    }

    // Navigate via the global navigator so we leave whatever nested
    // route the user is on and land on /auth.
    final nav = ApiService.navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil('/auth', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    return Material(
      color: primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: _confirmAndSignOut,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.logout, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              const Text(
                'Sign out',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

