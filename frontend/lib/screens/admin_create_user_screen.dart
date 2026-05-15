import 'package:flutter/material.dart';

import '../core/service/api_service.dart';

class AdminCreateUserScreen extends StatefulWidget {
  const AdminCreateUserScreen({super.key});

  @override
  State<AdminCreateUserScreen> createState() => _AdminCreateUserScreenState();
}

class _AdminCreateUserScreenState extends State<AdminCreateUserScreen> {
  static const _roles = <String>[
    'CEO',
    'DAIRY_MANAGER',
    'LAYERS_MANAGER',
    'PIGGERY_MANAGER',
    'VET',
    'ICT',
  ];

  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _role;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  bool _accessChecked = false;
  bool _isCeo = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final token = await ApiService.readToken();
    final role = await ApiService.readRole();
    if (!mounted) return;
    setState(() {
      _accessChecked = true;
      _isCeo = token != null && token.isNotEmpty && role == 'CEO';
    });
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a role')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService.createStaff(
        userName: _userNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _role!,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff account created')),
      );
      _formKey.currentState?.reset();
      _userNameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() => _role = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);

    if (!_accessChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isCeo) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Staff Account'),
          backgroundColor: primary,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Access denied. Only the CEO can create staff accounts.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Staff Account'),
        backgroundColor: primary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add a new staff member',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The new account will be pre-verified and active immediately.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _userNameController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.length < 3) return 'At least 3 characters';
                      if (v.length > 30) return 'At most 30 characters';
                      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(v)) {
                        return 'Letters, numbers, _ and - only';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Initial Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final p = value ?? '';
                      if (p.length < 8) return 'Use at least 8 characters';
                      if (!RegExp(r'[A-Z]').hasMatch(p)) return 'Include an uppercase letter';
                      if (!RegExp(r'[a-z]').hasMatch(p)) return 'Include a lowercase letter';
                      if (!RegExp(r'\d').hasMatch(p)) return 'Include a number';
                      if (!RegExp(r'[^A-Za-z0-9]').hasMatch(p)) {
                        return 'Include a special character';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: _roles
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.replaceAll('_', ' ')),
                            ))
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (v) => setState(() => _role = v),
                    validator: (v) => v == null ? 'Pick a role' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Staff Account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
