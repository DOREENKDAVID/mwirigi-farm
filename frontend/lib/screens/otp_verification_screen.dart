import 'dart:async';

import 'package:flutter/material.dart';

import '../core/service/api_service.dart';
import '../widgets/brand_logo.dart';
import 'main_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? password;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.password,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;

  Timer? _timer;
  int _seconds = 60;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) {
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorText = 'Enter the 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      await ApiService.verifyEmail(widget.email, code);

      if (widget.password != null && widget.password!.isNotEmpty) {
        await ApiService.login(widget.email, widget.password!);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (_) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified — please log in.')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await ApiService.resendOtp(widget.email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent to your email.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Account'),
        backgroundColor: primary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandLogo(height: 80)),
                const SizedBox(height: 24),
                Text(
                  'Code sent to ${widget.email}',
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '6-digit OTP',
                    border: const OutlineInputBorder(),
                    errorText: _errorText,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _seconds == 0 && !_isResending ? _resend : null,
                  child: _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _seconds == 0
                              ? 'Resend code'
                              : 'Resend in 00:${_seconds.toString().padLeft(2, '0')}',
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
