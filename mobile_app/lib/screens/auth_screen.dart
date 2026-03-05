import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPass = prefs.getString('saved_password');
    final remember = prefs.getBool('remember_me') ?? false;
    if (remember && savedEmail != null) {
      setState(() {
        _emailCtrl.text = savedEmail;
        if (savedPass != null) _passCtrl.text = savedPass;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailCtrl.text.trim());
      await prefs.setString('saved_password', _passCtrl.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

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

    if (err == null) {
      // Login/register succeeded — save credentials if remember me is on
      await _saveCredentials();
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
              const Text("Proxi Premium",
                  style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue)),
              const Text("Premium Social Network",
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
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Remember Me + Forgot Password row
              if (!_isRegister)
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                    ),
                    const Text("Remember Me"),
                    const Spacer(),
                    TextButton(
                      onPressed: _forgotPassword,
                      child: const Text("Forgot Password?"),
                    ),
                  ],
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