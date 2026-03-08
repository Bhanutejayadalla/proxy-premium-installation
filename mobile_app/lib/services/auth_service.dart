import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Currently signed-in Firebase user (null if not logged in).
  User? get currentUser => _auth.currentUser;

  /// Stream of auth-state changes (used by AppState to auto-login).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register a new user and return the credential.
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with email & password.
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password-reset email.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ─────────────────────────────────────────────
  //  PHONE AUTH
  // ─────────────────────────────────────────────

  /// Trigger phone number verification — sends an OTP SMS.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onAutoVerified,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException) onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Sign in with phone OTP (for phone-based login).
  Future<UserCredential> signInWithPhoneOtp(
      String verificationId, String otp) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Sign in with an auto-resolved PhoneAuthCredential.
  Future<UserCredential> signInWithPhoneCredentialDirect(
      PhoneAuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  /// Link a phone number (via OTP) to the currently signed-in account.
  Future<void> linkPhoneCredential(
      String verificationId, String otp) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    await _auth.currentUser!.linkWithCredential(credential);
  }

  /// Link an auto-resolved PhoneAuthCredential to the current account.
  Future<void> linkPhoneCredentialDirect(
      PhoneAuthCredential credential) async {
    await _auth.currentUser!.linkWithCredential(credential);
  }
}
