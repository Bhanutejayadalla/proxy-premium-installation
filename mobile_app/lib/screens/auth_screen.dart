import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _isRegister = false;
  String _loginMode = 'email'; // 'email' | 'phone'
  bool _showOtp = false;
  bool _isPhoneLoginOtp = false; // false = register OTP, true = phone login OTP
  bool _loading = false;
  String? _error;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
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
    if (_showOtp) {
      _isPhoneLoginOtp
          ? await _submitOtpPhoneLogin()
          : await _submitOtpRegister();
    } else if (_isRegister) {
      await _submitRegister();
    } else if (_loginMode == 'phone') {
      await _submitSendPhoneOtp();
    } else {
      await _submitEmailLogin();
    }
  }

  // ─── EMAIL LOGIN ──────────────────────────────────────────────────────────

  Future<void> _submitEmailLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = Provider.of<AppState>(context, listen: false);
    final err =
        await state.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
    if (err == null) await _saveCredentials();
    if (mounted) setState(() {
      _loading = false;
      _error = err;
    });
  }

  // ─── REGISTER ────────────────────────────────────────────────────────────

  Future<void> _submitRegister() async {
    if (_usernameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Username is required');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Phone number is required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = Provider.of<AppState>(context, listen: false);

    // Step 1 — create email/password account and Firestore profile
    final err = await state.register(
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
      _usernameCtrl.text.trim(),
      _phoneCtrl.text.trim(),
    );

    if (err != null) {
      if (mounted) setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }

    // Step 2 — send OTP to verify and link the phone number
    await state.auth.verifyPhoneNumber(
      phoneNumber: _phoneCtrl.text.trim(),
      onAutoVerified: (PhoneAuthCredential credential) async {
        // Android auto-resolved — link without manual OTP entry
        try {
          await state.auth.linkPhoneCredentialDirect(credential);
          await state.firebase.updateProfile(
            state.currentUser!.uid,
            {'phone_number': _phoneCtrl.text.trim()},
          );
        } catch (_) {}
        if (mounted) setState(() => _loading = false);
      },
      onCodeSent: (String vId, int? _) {
        if (mounted) {
          setState(() {
            _verificationId = vId;
            _showOtp = true;
            _isPhoneLoginOtp = false;
            _loading = false;
          });
        }
      },
      onFailed: (FirebaseAuthException e) {
        // Account already created — just skip phone linking
        if (mounted) {
          setState(() {
            _loading = false;
            _error =
                'Account created, but phone verification failed: ${e.message}\n'
                'You can verify your phone later in settings.';
          });
        }
      },
    );
  }

  // ─── VERIFY OTP (registration) ───────────────────────────────────────────

  Future<void> _submitOtpRegister() async {
    if (_otpCtrl.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = Provider.of<AppState>(context, listen: false);
    try {
      await state.auth
          .linkPhoneCredential(_verificationId!, _otpCtrl.text.trim());
      await state.firebase.updateProfile(
        state.currentUser!.uid,
        {'phone_number': _phoneCtrl.text.trim()},
      );
      if (mounted) setState(() => _loading = false);
      // AppState auth-stream handles home navigation automatically
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Invalid OTP. Please try again.';
      });
    }
  }

  // ─── PHONE LOGIN: SEND OTP ────────────────────────────────────────────────

  Future<void> _submitSendPhoneOtp() async {
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = Provider.of<AppState>(context, listen: false);

    await state.auth.verifyPhoneNumber(
      phoneNumber: _phoneCtrl.text.trim(),
      onAutoVerified: (PhoneAuthCredential credential) async {
        try {
          final cred =
              await state.auth.signInWithPhoneCredentialDirect(credential);
          final loginErr = await state.loginWithPhone(cred);
          if (loginErr != null && mounted) {
            setState(() {
              _loading = false;
              _error = loginErr;
            });
          }
        } catch (e) {
          if (mounted) setState(() {
            _loading = false;
            _error = e.toString();
          });
        }
      },
      onCodeSent: (String vId, int? _) {
        if (mounted) {
          setState(() {
            _verificationId = vId;
            _showOtp = true;
            _isPhoneLoginOtp = true;
            _loading = false;
          });
        }
      },
      onFailed: (FirebaseAuthException e) {
        if (mounted) setState(() {
          _loading = false;
          _error = 'Verification failed: ${e.message}';
        });
      },
    );
  }

  // ─── VERIFY OTP (phone login) ─────────────────────────────────────────────

  Future<void> _submitOtpPhoneLogin() async {
    if (_otpCtrl.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = Provider.of<AppState>(context, listen: false);
    try {
      final cred = await state.auth
          .signInWithPhoneOtp(_verificationId!, _otpCtrl.text.trim());
      final err = await state.loginWithPhone(cred);
      if (err != null && mounted) {
        setState(() {
          _loading = false;
          _error = err;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Invalid OTP. Please try again.';
      });
    }
  }

  // ─── FORGOT PASSWORD ──────────────────────────────────────────────────────

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

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  String get _buttonLabel {
    if (_showOtp) return 'Verify OTP';
    if (_isRegister) return 'Create Account';
    if (_loginMode == 'phone') return 'Send OTP';
    return 'Sign In';
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

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
              const Text(
                "Proxi Premium",
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue),
              ),
              const Text("Premium Social Network",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              if (_showOtp)
                ..._buildOtpStep()
              else if (_isRegister)
                ..._buildRegisterFields()
              else
                ..._buildLoginFields(),

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
                      : Text(_buttonLabel),
                ),
              ),
              const SizedBox(height: 16),

              if (_showOtp)
                TextButton(
                  onPressed: () => setState(() {
                    _showOtp = false;
                    _otpCtrl.clear();
                    _error = null;
                  }),
                  child: const Text("Back"),
                )
              else
                TextButton(
                  onPressed: () => setState(() {
                    _isRegister = !_isRegister;
                    _loginMode = 'email';
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

  // ─── OTP STEP ─────────────────────────────────────────────────────────────

  List<Widget> _buildOtpStep() {
    return [
      Icon(Icons.sms_outlined, size: 56, color: AppColors.formalPrimary),
      const SizedBox(height: 16),
      Text(
        'Enter the 6-digit code sent to\n${_phoneCtrl.text.trim()}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _otpCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, letterSpacing: 10),
        decoration: const InputDecoration(
          labelText: 'OTP Code',
          border: OutlineInputBorder(),
          counterText: '',
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  // ─── REGISTER FIELDS ──────────────────────────────────────────────────────

  List<Widget> _buildRegisterFields() {
    return [
      TextField(
        controller: _usernameCtrl,
        decoration: const InputDecoration(
          labelText: "Username",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person),
        ),
      ),
      const SizedBox(height: 16),
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
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: "Phone Number (e.g. +91XXXXXXXXXX)",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.phone),
          helperText: "Include country code. An OTP will be sent to verify.",
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _passCtrl,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: "Password",
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  // ─── LOGIN FIELDS ─────────────────────────────────────────────────────────

  List<Widget> _buildLoginFields() {
    return [
      // Email / Phone toggle tabs
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(children: [
          _loginTab('Email', 'email'),
          _loginTab('Phone', 'phone'),
        ]),
      ),
      const SizedBox(height: 16),

      if (_loginMode == 'email') ...[
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
        TextField(
          controller: _passCtrl,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: "Password",
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_off
                  : Icons.visibility),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: (v) => setState(() => _rememberMe = v ?? false),
            ),
            const Text("Remember Me"),
            const Spacer(),
            TextButton(
              onPressed: _forgotPassword,
              child: const Text("Forgot Password?"),
            ),
          ],
        ),
      ] else ...[
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "Phone Number (e.g. +91XXXXXXXXXX)",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
            helperText: "We'll send a one-time OTP to this number.",
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  Widget _loginTab(String label, String mode) {
    final active = _loginMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _loginMode = mode;
          _error = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          color: active ? AppColors.formalPrimary : const Color(0xFFE5E7EB),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}