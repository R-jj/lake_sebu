import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/phone_validator.dart';
import '../services/user_repository.dart';

/// Shown by [_AuthGate] in main.dart when the authenticated user's profile
/// does not yet have a phone number.
///
/// The user must provide a contact number before they can access [RootShell].
/// The number is validated with [PhoneValidator] and saved directly to
/// `users/{uid}.phoneNumber` — no SMS or OTP is involved.
///
/// Google Sign-In users land here automatically on their first sign-in.
/// Email/password users land here after completing registration.
/// Existing users without a phone number will also land here on next sign-in.
///
/// The gate cannot be navigated away from until the user either:
///   a) Saves a valid phone number → [_AuthGate] transitions to [RootShell].
///   b) Signs out.
///
/// NOTE: [phone_verification_page.dart] is preserved in the project for
/// future use when SMS verification becomes available.  Nothing currently
/// navigates to it.
class ProfileCompletionGate extends StatefulWidget {
  const ProfileCompletionGate({super.key});

  @override
  State<ProfileCompletionGate> createState() => _ProfileCompletionGateState();
}

class _ProfileCompletionGateState extends State<ProfileCompletionGate> {
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();

  String? _phoneError;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  // ── Save phone number ─────────────────────────────────────────────────────

  Future<void> _savePhoneNumber() async {
    FocusScope.of(context).unfocus();

    final raw = _phoneCtrl.text.trim();
    final validationError = PhoneValidator.errorMessage(raw);
    if (validationError != null) {
      setState(() => _phoneError = validationError);
      return;
    }

    final e164 = PhoneValidator.normalize(raw)!;

    setState(() {
      _isLoading = true;
      _phoneError = null;
      _errorMessage = null;
    });

    try {
      await UserRepository.instance.updatePhoneNumber(e164);
      // The UserProfileProvider's real-time stream will pick up the Firestore
      // change and call AppAuthProvider.markProfileComplete() automatically,
      // which causes _AuthGate to transition to RootShell.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not save your number. Please try again.';
      });
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final profileProvider = context.watch<UserProfileProvider>();
    final displayName =
        profileProvider.profile?.displayName ?? auth.user?.name ?? 'there';

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
                _buildHeader(displayName),
                const SizedBox(height: 40),
                _buildPhoneSection(),
                const SizedBox(height: 40),
                _buildSaveButton(),
                const SizedBox(height: 20),
                _buildSignOutButton(context, auth),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(String displayName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: kBrand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBrand.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.phone_outlined, color: kBrand, size: 26),
        ),
        const SizedBox(height: 20),
        Text(
          'One last step,\n$displayName!',
          style: kSerif.copyWith(
            color: kInk,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Add a contact number so restaurants can '
          'reach you about your orders.',
          style: TextStyle(color: kMuted, fontSize: 15, height: 1.6),
        ),
      ],
    );
  }

  // ── Phone section ─────────────────────────────────────────────────────────

  Widget _buildPhoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanation card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kBrand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBrand.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: kBrand, size: 18),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Your contact number is shared with the restaurant '
                  'only when you place an order, so they can reach you '
                  'about delivery or order details.',
                  style: TextStyle(color: kInk, fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Field label
        const Text(
          'Contact number',
          style: TextStyle(
              color: kInk, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildPhoneField(),
        const SizedBox(height: 6),
        const Text(
          'Format: 0917 123 4567 or +63 917 123 4567',
          style: TextStyle(color: kMuted, fontSize: 11),
        ),

        // Error banner
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(_errorMessage!),
        ],
      ],
    );
  }

  Widget _buildPhoneField() {
    final hasError = _phoneError != null;
    final borderColor = hasError ? kRed : kBorder;
    final focusBorderColor = hasError ? kRed : kBrand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: kSurface2,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Country code badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: borderColor)),
                ),
                child: const Text(
                  '🇵🇭 +63',
                  style: TextStyle(
                      color: kInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
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
                    onSubmitted: (_) => _savePhoneNumber(),
                    style: const TextStyle(color: kInk, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '917 123 4567',
                      hintStyle:
                          const TextStyle(color: kMuted, fontSize: 15),
                      border: InputBorder.none,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: focusBorderColor, width: 1.5),
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

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _savePhoneNumber,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : const LinearGradient(
                  colors: [kBrand, kBrandDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          color: _isLoading ? kSurface2 : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isLoading
              ? null
              : [
                  BoxShadow(
                      color: kBrand.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(kMuted)))
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Save contact number',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context, AppAuthProvider auth) {
    return GestureDetector(
      onTap: () async => auth.signOut(),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Sign out',
          style: TextStyle(
              color: kMuted, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        border: Border.all(color: kRed.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: kRed, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style:
                  const TextStyle(color: kRed, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
