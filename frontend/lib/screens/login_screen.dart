import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_sign_in/google_sign_in.dart';

import '../core/service/api_service.dart';
import '../widgets/brand_logo.dart';
import 'forgot_password_screen.dart';
import 'main_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  // Separate busy flag for the OAuth buttons so the password Submit
  // button doesn't flicker while a Google/Apple sign-in is in flight.
  bool _oauthBusy = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(bool loginMode) {
    if (_isLoginMode == loginMode) return;
    setState(() {
      _isLoginMode = loginMode;
      _isLoading = false;
    });
  }

  String? _identifierValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email or username is required';
    return null;
  }

  String? _userNameValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.length < 3) return 'Username must be at least 3 characters';
    if (v.length > 30) return 'Username must be at most 30 characters';
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(v)) {
      return 'Letters, numbers, _ and - only';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();
    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!isValid) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (!_isLoginMode && password.length < 8) {
      return 'Use at least 8 characters';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (_isLoginMode) return null;
    if ((value ?? '').isEmpty) return 'Confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _signInWithGoogle() async {
    if (_oauthBusy || _isLoading) return;
    setState(() => _oauthBusy = true);
    try {
      // GoogleSignIn opens the platform sign-in flow. On Android this
      // requires google-services.json + a configured OAuth client ID.
      final account = await GoogleSignIn().signIn();
      if (account == null) {
        // User cancelled the picker.
        if (mounted) setState(() => _oauthBusy = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception(
          'Google did not return an idToken. Check your OAuth client ID config.',
        );
      }
      await ApiService.googleLogin(idToken);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _oauthBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _signInWithApple() async {
    // Apple Sign-In needs the iOS-side Xcode entitlement + the
    // `sign_in_with_apple` package. Backend endpoint is ready; wire
    // the package up when shipping the iOS build.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Apple Sign-In ships with the iOS build.'),
      ),
    );
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isLoading = true);

    if (_isLoginMode) {
      try {
        await ApiService.login(
          _identifierController.text.trim(),
          _passwordController.text,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }

    // Register flow: POST /auth/register, then go to OTP verification.
    final email = _emailController.text.trim();
    final userName = _userNameController.text.trim();
    try {
      await ApiService.register(
        userName: userName,
        email: email,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            password: _passwordController.text,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // Pill-style decoration shared across every text field. Filled with
  // a subtle off-white, no visible border at rest, primary-coloured
  // focus ring, all corners rounded to match the reference mockup.
  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    Widget? suffixIcon,
  }) {
    const primary = Color(0xFF27500A);
    const fieldFill = Color(0xFFF4F6F1);
    const radius = 16.0;
    final base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: fieldFill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: base,
      enabledBorder: base,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: Color(0xFFB52C2B), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: Color(0xFFB52C2B), width: 1.5),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    const lightBg = Color(0xFFF7F8F5);
    const border = Color(0xFFE4E9DD);

    return Scaffold(
      backgroundColor: lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: AutofillGroup(
                  child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandLogo(height: 80)),
                      const SizedBox(height: 20),
                      Text(
                        _isLoginMode ? 'Welcome back' : 'Create your account',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLoginMode
                            ? 'See how your farm is doing today.'
                            : 'Register once and start tracking your farm operations.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: lightBg,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _modeChip(
                                label: 'Login',
                                selected: _isLoginMode,
                                onTap: () => _switchMode(true),
                              ),
                            ),
                            Expanded(
                              child: _modeChip(
                                label: 'Register',
                                selected: !_isLoginMode,
                                onTap: () => _switchMode(false),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isLoginMode)
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: TextInputType.text,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.username],
                          decoration: _fieldDecoration(
                            label: 'Email or Username',
                            hint: 'you@email.com or yourname',
                          ),
                          validator: _identifierValidator,
                        )
                      else ...[
                        TextFormField(
                          controller: _userNameController,
                          keyboardType: TextInputType.text,
                          autocorrect: false,
                          decoration: _fieldDecoration(
                            label: 'Username',
                            hint: 'yourname',
                          ),
                          validator: _userNameValidator,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _fieldDecoration(
                            label: 'Email',
                            hint: 'your@email.com',
                          ),
                          validator: _emailValidator,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: _fieldDecoration(
                          label: 'Password',
                          hint: '********',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: _passwordValidator,
                      ),
                      if (!_isLoginMode) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: _fieldDecoration(
                            label: 'Confirm Password',
                            hint: '********',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: _confirmPasswordValidator,
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isLoginMode ? 'Login' : 'Create Account'),
                      ),
                      if (_isLoginMode) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: const Text('Forgot password?'),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: const [
                          Expanded(child: Divider(height: 1)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Or continue with',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          Expanded(child: Divider(height: 1)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _OAuthButton(
                              label: 'Google',
                              assetPath: 'assets/icons/google.png',
                              fallbackIcon: Icons.g_translate,
                              onTap: _signInWithGoogle,
                              busy: _oauthBusy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _OAuthButton(
                              label: 'Apple',
                              assetPath: 'assets/icons/apple.png',
                              fallbackIcon: Icons.apple,
                              onTap: _signInWithApple,
                              busy: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLoginMode
                                ? "Don't have an account? "
                                : 'Already have an account? ',
                          ),
                          GestureDetector(
                            onTap: () => _switchMode(!_isLoginMode),
                            child: Text(
                              _isLoginMode ? 'Register' : 'Login',
                              style: const TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const primary = Color(0xFF27500A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Pill-style OAuth provider button. Probes the asset bundle on first
/// build to decide whether to render the brand artwork at `assetPath`
/// or fall back to a Material icon. The probe avoids the Image.asset
/// 404 the Flutter web engine logs when the file is missing — useful
/// while assets/icons/ is empty (see assets/icons/README.md).
class _OAuthButton extends StatefulWidget {
  const _OAuthButton({
    required this.label,
    required this.assetPath,
    required this.fallbackIcon,
    required this.onTap,
    required this.busy,
  });

  final String label;
  final String assetPath;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final bool busy;

  @override
  State<_OAuthButton> createState() => _OAuthButtonState();
}

class _OAuthButtonState extends State<_OAuthButton> {
  // null = still probing, true = asset exists, false = use fallback icon.
  bool? _assetAvailable;

  @override
  void initState() {
    super.initState();
    _probeAsset();
  }

  Future<void> _probeAsset() async {
    try {
      await rootBundle.load(widget.assetPath);
      if (mounted) setState(() => _assetAvailable = true);
    } catch (_) {
      // Asset missing in the bundle. Keep the fallback icon — the
      // user can drop the official brand file in later and the next
      // hot-restart will pick it up automatically.
      if (mounted) setState(() => _assetAvailable = false);
    }
  }

  Widget _logo() {
    if (widget.busy) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF27500A),
        ),
      );
    }
    if (_assetAvailable == true) {
      return Image.asset(widget.assetPath, width: 20, height: 20);
    }
    // Probing or missing → render the fallback Material icon.
    return Icon(
      widget.fallbackIcon,
      size: 22,
      color: const Color(0xFF1A1A18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFD9DCD3), width: 1),
        borderRadius: BorderRadius.circular(28),
      ),
      child: InkWell(
        onTap: widget.busy ? null : widget.onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _logo(),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
