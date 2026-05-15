import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/service/api_service.dart';

/// Custom AppBar shown at the top of MainScreen.
///
/// Renders: page title (left), current date + Live pill + Simulate toggle.
/// The Simulate toggle is intentionally UI-only at this phase — no logic is
/// hooked up yet. It exposes [simulating] / [onToggleSimulate] so a future
/// session can wire in the live-data simulation without changing this widget.
class FarmTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FarmTopBar({
    super.key,
    required this.title,
    required this.simulating,
    required this.onToggleSimulate,
    this.showMenuButton = true,
  });

  final String title;
  final bool simulating;
  final VoidCallback onToggleSimulate;
  /// Hide the hamburger when the drawer is rendered permanently as a
  /// sidebar (tablet layout).
  final bool showMenuButton;

  static const _primary = Color(0xFF27500A);
  static const _accent = Color(0xFFEF9F27);

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
              const _LivePill(),
              const SizedBox(width: 8),
              _SimulateButton(
                active: simulating,
                onTap: onToggleSimulate,
                primary: _primary,
                accent: _accent,
              ),
              const SizedBox(width: 8),
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
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0x33000000), width: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: _confirmAndSignOut,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.black54,
                      ),
                    )
                  : const Icon(Icons.logout, size: 14, color: Colors.black54),
              const SizedBox(width: 4),
              const Text(
                'Sign out',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePill extends StatefulWidget {
  const _LivePill();

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.3).animate(_ctl),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF639922),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Live',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF27500A),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimulateButton extends StatelessWidget {
  const _SimulateButton({
    required this.active,
    required this.onTap,
    required this.primary,
    required this.accent,
  });

  final bool active;
  final VoidCallback onTap;
  final Color primary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFFAEEDA) : Colors.transparent;
    final border = active ? accent : const Color(0x33000000);
    final fg = active ? const Color(0xFF633806) : Colors.black54;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.stop : Icons.play_arrow,
                size: 14,
                color: fg,
              ),
              const SizedBox(width: 4),
              Text(
                active ? 'Stop' : 'Simulate',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
