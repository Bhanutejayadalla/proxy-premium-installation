import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../constants.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final state = Provider.of<AppState>(context, listen: false);
    String? err;

    if (_isRegister) {
      if (_usernameCtrl.text.trim().isEmpty) {
        setState(() {
          _error = 'Username is required';
          _loading = false;
        });
        return;
      }
      err = await state.register(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
        _usernameCtrl.text.trim(),
      );
    } else {
      err = await state.login(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first');
      return;
    }
    try {
      await Provider.of<AppState>(context, listen: false)
          .auth
          .sendPasswordReset(_emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              const Text("Proxi",
                  style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue)),
              const Text("Dual Mode Social",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // Username (register only)
              if (_isRegister) ...[
                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Username",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 8),

              // Forgot password
              if (!_isRegister)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text("Forgot Password?"),
                  ),
                ),

              const SizedBox(height: 16),

              // Error
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.formalPrimary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(_isRegister ? "Create Account" : "Sign In"),
                ),
              ),
              const SizedBox(height: 16),

              // Toggle register / login
              TextButton(
                onPressed: () =>
                    setState(() {
                      _isRegister = !_isRegister;
                      _error = null;
                    }),
                child: Text(_isRegister
                    ? "Already have an account? Sign In"
                    : "Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}