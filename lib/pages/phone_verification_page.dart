import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/phone_validator.dart';
import '../services/user_repository.dart';

/// Result returned to the caller after a successful verification.
class PhoneVerificationResult {
  final String e164;
  const PhoneVerificationResult(this.e164);
}

/// Mode controls the header copy and whether to show a "skip" option.
enum PhoneVerificationMode {
  /// First-time setup — user must verify to continue.
  setup,

  /// Changing an existing verified number from Account Settings.
  change,
}

/// Full Firebase SMS OTP phone verification screen.
///
/// Flow:
///   1. User enters a Philippine mobile number.
///   2. [PhoneValidator] checks the format and normalises to E.164.
///   3. [UserRepository.isPhoneNumberTaken] checks uniqueness.
///   4. [FirebaseAuth.verifyPhoneNumber] sends the SMS.
///   5. User enters the 6-digit OTP.
///   6. [FirebaseAuth.signInWithCredential] (or link) verifies the code.
///   7. [UserRepository.markPhoneVerified] atomically updates the
///      Firestore profile and phoneIndex.
///   8. [onVerified] callback is called — the caller decides what to do next.
///
/// Error cases handled:
///   • Invalid phone format
///   • Number already taken by another account
///   • Incorrect OTP
///   • Expired OTP (with resend)
///   • Network failures
///   • Too many requests / quota exceeded
///   • Auto-retrieval / instant verification on Android
class PhoneVerificationPage extends StatefulWidget {
  final PhoneVerificationMode mode;

  /// Called with the verified E.164 number after success.
  final void Function(PhoneVerificationResult result) onVerified;

  /// Called when the user cancels (only shown in [PhoneVerificationMode.change]).
  final VoidCallback? onCancel;

  const PhoneVerificationPage({
    super.key,
    this.mode = PhoneVerificationMode.setup,
    required this.onVerified,
    this.onCancel,
  });

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final _auth = FirebaseAuth.instance;
  final _repo = UserRepository.instance;

  // ── Step tracking ─────────────────────────────────────────────────────────
  // Step 1: enter phone number
  // Step 2: enter OTP
  bool _otpSent = false;

  // ── Phone step ────────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  String? _phoneError;
  String? _verificationId;
  int? _resendToken;

  // ── OTP step ──────────────────────────────────────────────────────────────
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocuses = List.generate(6, (_) => FocusNode());
  String? _otpError;

  // ── Resend timer ──────────────────────────────────────────────────────────
  static const _resendSeconds = 60;
  int _secondsLeft = 0;
  Timer? _resendTimer;

  // ── Loading / general error ────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;

  // ── Cached normalised number ──────────────────────────────────────────────
  String? _normalizedPhone;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocuses) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Resend countdown ──────────────────────────────────────────────────────

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
  }

  // ── Step 1: Send OTP ──────────────────────────────────────────────────────

  Future<void> _sendOtp({bool isResend = false}) async {
    FocusScope.of(context).unfocus();

    // Validate format.
    final raw = _phoneCtrl.text.trim();
    final phoneErr = PhoneValidator.errorMessage(raw);
    if (phoneErr != null) {
      setState(() => _phoneError = phoneErr);
      return;
    }

    final e164 = PhoneValidator.normalize(raw)!;

    // Check uniqueness — skip if this is a resend or the user's own number.
    if (!isResend) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _phoneError = null;
      });

      try {
        final owner = await _repo.phoneNumberOwner(e164);
        final currentUid = _auth.currentUser?.uid;
        if (owner != null && owner != currentUid) {
          setState(() {
            _isLoading = false;
            _phoneError =
                'This phone number is already linked to another account.';
          });
          return;
        }
      } catch (_) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not verify phone number. Please try again.';
        });
        return;
      }
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _otpError = null;
      });
    }

    _normalizedPhone = e164;

    await _auth.verifyPhoneNumber(
      phoneNumber: e164,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),

      // Android automatic SMS retrieval — instant verification.
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _handleCredential(credential, e164);
      },

      verificationFailed: (FirebaseAuthException e) {
        debugPrint(
            'verifyPhoneNumber failed — code: ${e.code}, message: ${e.message}');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = _friendlyFirebaseError(e.code);
        });
      },

      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
          _otpSent = true;
        });
        _startResendTimer();
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) return;
        _verificationId = verificationId;
      },
    );
  }

  // ── Step 2: Verify OTP ────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();

    final code = _otpCtrls.map((c) => c.text.trim()).join();
    if (code.length < 6) {
      setState(() => _otpError = 'Please enter all 6 digits.');
      return;
    }

    if (_verificationId == null) {
      setState(() =>
          _errorMessage = 'Verification session expired. Please resend.');
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
      _errorMessage = null;
    });

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );

    await _handleCredential(credential, _normalizedPhone!);
  }

  Future<void> _handleCredential(
      PhoneAuthCredential credential, String e164) async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        // User is already signed in — link or re-link the phone credential.
        try {
          await currentUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'provider-already-linked') {
            // The phone number is already linked to this account — that's fine.
          } else {
            rethrow;
          }
        }
      } else {
        // Should not happen in normal flow, but handle gracefully.
        await _auth.signInWithCredential(credential);
      }

      // Atomically update Firestore profile + phoneIndex.
      await _repo.markPhoneVerified(e164);

      if (!mounted) return;
      widget.onVerified(PhoneVerificationResult(e164));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpError = _friendlyOtpError(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification failed. Please try again.';
      });
    }
  }

  // ── Error helpers ─────────────────────────────────────────────────────────

  String _friendlyFirebaseError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait before requesting another code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'missing-client-identifier':
      case 'captcha-check-failed':
        return 'Verification check failed. Please try again.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled. Please contact support.';
      case 'app-not-authorized':
      case 'app-not-verified':
        return 'App verification failed. Please try again or contact support.';
      case 'internal-error':
        return 'An internal error occurred. Please try again later.';
      default:
        return 'Failed to send verification code. Please try again.';
    }
  }

  String _friendlyOtpError(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Incorrect code. Please check and try again.';
      case 'session-expired':
        return 'Code expired. Please request a new one.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return 'Verification failed. Please try again.';
    }
  }

  // ── OTP field helpers ─────────────────────────────────────────────────────

  void _onOtpChanged(String value, int index) {
    if (_otpError != null) setState(() => _otpError = null);

    if (value.length == 1 && index < 5) {
      _otpFocuses[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocuses[index - 1].requestFocus();
    }

    // Auto-submit when all 6 digits are entered.
    final code = _otpCtrls.map((c) => c.text.trim()).join();
    if (code.length == 6 && !_isLoading) {
      _verifyOtp();
    }
  }

  void _onOtpKey(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpCtrls[index].text.isEmpty &&
        index > 0) {
      _otpFocuses[index - 1].requestFocus();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                _buildHeader(),
                const SizedBox(height: 40),
                if (!_otpSent) _buildPhoneStep() else _buildOtpStep(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isSetup = widget.mode == PhoneVerificationMode.setup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back / cancel button for "change" mode.
        if (widget.mode == PhoneVerificationMode.change &&
            widget.onCancel != null) ...[
          GestureDetector(
            onTap: widget.onCancel,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chevron_left, color: kInk, size: 22),
            ),
          ),
          const SizedBox(height: 24),
        ],

        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: kBrand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBrand.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.phone_outlined, color: kBrand, size: 26),
        ),
        const SizedBox(height: 20),
        Text(
          _otpSent
              ? 'Enter verification\ncode'
              : (isSetup
                  ? 'Verify your\nphone number'
                  : 'Change phone\nnumber'),
          style: kSerif.copyWith(
              color: kInk,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.1),
        ),
        const SizedBox(height: 10),
        Text(
          _otpSent
              ? 'We sent a 6-digit code to\n${PhoneValidator.format(_normalizedPhone ?? '')}'
              : (isSetup
                  ? 'A verification code will be sent\nto your mobile number via SMS.'
                  : 'Enter the new number. A code will\nbe sent to verify it.'),
          style: const TextStyle(color: kMuted, fontSize: 15, height: 1.55),
        ),
      ],
    );
  }

  // ── Phone entry step ──────────────────────────────────────────────────────

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mobile number',
            style: TextStyle(
                color: kInk, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildPhoneField(),
        const SizedBox(height: 8),
        const Text(
          'Format: 0917 123 4567 or +63 917 123 4567',
          style: TextStyle(color: kMuted, fontSize: 11),
        ),
        const SizedBox(height: 28),
        if (_errorMessage != null) ...[
          _buildBanner(_errorMessage!, isError: true),
          const SizedBox(height: 20),
        ],
        _buildPrimaryButton(
          label: 'Send verification code',
          isLoading: _isLoading,
          onTap: () => _sendOtp(),
        ),
        if (widget.mode == PhoneVerificationMode.change &&
            widget.onCancel != null) ...[
          const SizedBox(height: 14),
          _buildSecondaryButton(label: 'Cancel', onTap: widget.onCancel!),
        ],
      ],
    );
  }

  Widget _buildPhoneField() {
    final hasError = _phoneError != null;
    final bc = hasError ? kRed : kBorder;
    final fc = hasError ? kRed : kBrand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: kSurface2,
            border: Border.all(color: bc),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Country code badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: bc)),
                ),
                child: const Text(
                  '🇵🇭 +63',
                  style: TextStyle(
                      color: kInk, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (hasFocus && _phoneError != null) {
                      setState(() => _phoneError = null);
                    }
                  },
                  child: TextField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[\d\s\-]')),
                    ],
                    onChanged: (_) {
                      if (_phoneError != null) {
                        setState(() => _phoneError = null);
                      }
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                    onSubmitted: (_) => _sendOtp(),
                    style: const TextStyle(color: kInk, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '917 123 4567',
                      hintStyle:
                          const TextStyle(color: kMuted, fontSize: 15),
                      border: InputBorder.none,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: fc, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(_phoneError!,
              style: const TextStyle(color: kRed, fontSize: 12)),
        ],
      ],
    );
  }

  // ── OTP entry step ────────────────────────────────────────────────────────

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOtpBoxes(),
        if (_otpError != null) ...[
          const SizedBox(height: 8),
          Text(_otpError!,
              style: const TextStyle(color: kRed, fontSize: 13)),
        ],
        const SizedBox(height: 28),
        if (_errorMessage != null) ...[
          _buildBanner(_errorMessage!, isError: true),
          const SizedBox(height: 20),
        ],
        _buildPrimaryButton(
          label: 'Verify code',
          isLoading: _isLoading,
          onTap: _verifyOtp,
        ),
        const SizedBox(height: 20),
        _buildResendRow(),
        const SizedBox(height: 14),
        _buildSecondaryButton(
          label: 'Change phone number',
          onTap: () {
            setState(() {
              _otpSent = false;
              _otpError = null;
              _errorMessage = null;
              for (final c in _otpCtrls) {
                c.clear();
              }
              _resendTimer?.cancel();
            });
          },
        ),
      ],
    );
  }

  Widget _buildOtpBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        final hasError = _otpError != null;
        final bc = hasError ? kRed : kBorder;
        final fc = hasError ? kRed : kBrand;
        return SizedBox(
          width: 46,
          height: 56,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) => _onOtpKey(event, i),
            child: TextField(
              controller: _otpCtrls[i],
              focusNode: _otpFocuses[i],
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => _onOtpChanged(v, i),
              style: kSerif.copyWith(
                  color: kInk, fontSize: 22, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: kSurface2,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: bc)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: bc)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: fc, width: 2)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kRed)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildResendRow() {
    final canResend = _secondsLeft <= 0 && !_isLoading;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Didn't receive a code? ",
            style: const TextStyle(color: kMuted, fontSize: 14)),
        if (_secondsLeft > 0)
          Text(
            'Resend in ${_secondsLeft}s',
            style: const TextStyle(
                color: kMuted, fontSize: 14, fontWeight: FontWeight.w600),
          )
        else
          GestureDetector(
            onTap: canResend ? () => _sendOtp(isResend: true) : null,
            child: Text(
              'Resend',
              style: TextStyle(
                  color: canResend ? kBrand : kMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : const LinearGradient(
                  colors: [kBrand, kBrandDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          color: isLoading ? kSurface2 : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                      color: kBrand.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(kMuted)))
            : Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                color: kMuted, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBanner(String message, {required bool isError}) {
    final color = isError ? kRed : kGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline,
              color: color,
              size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style:
                      TextStyle(color: color, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}
