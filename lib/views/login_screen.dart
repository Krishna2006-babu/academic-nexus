import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 1. Email & Password Sign In
  // ---------------------------------------------------------------------------
  Future<void> _handleEmailPasswordSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Please enter both email and password.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmailPassword(email, password);
      // Navigation is automatically handled if your root widget listens to authStateChanges
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Authentication failed.");
    } catch (e) {
      _showSnackBar("An unexpected error occurred: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Google Sign In
  // ---------------------------------------------------------------------------
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // User closed the popup window
        setState(() => _isLoading = false);
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Google sign-in failed.");
    } catch (e) {
      _showSnackBar("Could not authenticate with Google: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Forgot Password Dialog
  // ---------------------------------------------------------------------------
  void _openForgotPasswordDialog() {
    final TextEditingController resetEmailController =
        TextEditingController(text: _emailController.text.trim());

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Reset Password",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your registered email address and we'll send you a password reset link.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Email Address",
                labelStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.indigoAccent),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final resetEmail = resetEmailController.text.trim();
              if (resetEmail.isEmpty) {
                _showSnackBar("Please enter an email address.");
                return;
              }
              Navigator.pop(dialogCtx);
              try {
                await _authService.sendPasswordResetEmail(resetEmail);
                _showSnackBar("Password reset email sent to $resetEmail.");
              } on FirebaseAuthException catch (e) {
                _showSnackBar(e.message ?? "Could not send reset email.");
              }
            },
            child: const Text("Send Link"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Phone Number OTP Flow (Bottom Sheet)
  // ---------------------------------------------------------------------------
  void _openPhoneAuthSheet() {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController otpController = TextEditingController();
    String? verificationId;
    bool isCodeSent = false;
    bool isSheetSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isCodeSent ? "Enter SMS Code" : "Sign in with Mobile",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!isCodeSent) ...[
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Phone Number (+CountryCode)",
                        hintText: "+91 9876543210",
                        hintStyle: const TextStyle(color: Colors.white30),
                        labelStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(Icons.phone_iphone, color: Colors.indigoAccent),
                        filled: true,
                        fillColor: Colors.grey[850],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSheetSubmitting
                          ? null
                          : () async {
                              final rawPhone = phoneController.text.trim();
                              if (rawPhone.isEmpty || !rawPhone.startsWith('+')) {
                                _showSnackBar("Please include country code (e.g. +91...)");
                                return;
                              }

                              setSheetState(() => isSheetSubmitting = true);

                              await _authService.verifyPhoneNumber(
                                phoneNumber: rawPhone,
                                onVerificationCompleted: (credential) async {
                                  await FirebaseAuth.instance.signInWithCredential(credential);
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                },
                                onVerificationFailed: (e) {
                                  setSheetState(() => isSheetSubmitting = false);
                                  _showSnackBar(e.message ?? "Phone verification failed.");
                                },
                                onCodeSent: (vId, resendToken) {
                                  setSheetState(() {
                                    verificationId = vId;
                                    isCodeSent = true;
                                    isSheetSubmitting = false;
                                  });
                                },
                                onCodeAutoRetrievalTimeout: (vId) {
                                  verificationId = vId;
                                },
                              );
                            },
                      child: isSheetSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Send Verification OTP", style: TextStyle(fontSize: 16)),
                    ),
                  ] else ...[
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, letterSpacing: 4),
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: "6-Digit SMS Code",
                        labelStyle: const TextStyle(color: Colors.white60),
                        counterText: "",
                        filled: true,
                        fillColor: Colors.grey[850],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSheetSubmitting
                          ? null
                          : () async {
                              final code = otpController.text.trim();
                              if (code.length < 6 || verificationId == null) {
                                _showSnackBar("Please enter the complete 6-digit code.");
                                return;
                              }

                              setSheetState(() => isSheetSubmitting = true);

                              try {
                                await _authService.signInWithPhoneOtp(
                                  verificationId: verificationId!,
                                  smsCode: code,
                                );
                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              } on FirebaseAuthException catch (e) {
                                _showSnackBar(e.message ?? "Verification failed.");
                              } finally {
                                if (sheetCtx.mounted) {
                                  setSheetState(() => isSheetSubmitting = false);
                                }
                              }
                            },
                      child: isSheetSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Verify Code & Sign In", style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.grey[900]),
    );
  }

  // ---------------------------------------------------------------------------
  // Build Main Screen
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon & Title
                const Icon(
                  Icons.school_rounded,
                  size: 64,
                  color: Colors.indigoAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Academic Nexus",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Sign in to access your vault & AI mentor",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // Email Field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    labelStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.indigoAccent),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.indigoAccent),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white60,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                // Forgot Password Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _openForgotPasswordDialog,
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(color: Colors.indigoAccent, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Primary Sign In Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _handleEmailPasswordSignIn,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Sign In",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[800])),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("OR", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Colors.grey[800])),
                  ],
                ),
                const SizedBox(height: 24),

                // Google Sign In Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.white),
                  label: const Text(
                    "Continue with Google",
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey[800]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.grey[900],
                  ),
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                ),
                const SizedBox(height: 12),

                // Mobile Phone Sign In Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.phone_android_rounded, size: 20, color: Colors.white),
                  label: const Text(
                    "Continue with Phone Number",
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey[800]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.grey[900],
                  ),
                  onPressed: _isLoading ? null : _openPhoneAuthSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}