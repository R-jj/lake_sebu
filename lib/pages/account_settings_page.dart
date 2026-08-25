import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/phone_validator.dart';
import '../services/user_repository.dart';
import '_sub_page_shell.dart';
// phone_verification_page.dart is intentionally NOT imported here.
// It is preserved in the project for future SMS verification support,
// but nothing in the current flow navigates to it.

class AccountSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  const AccountSettingsPage({super.key, required this.onBack});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  // ── Sub-views ─────────────────────────────────────────────────────────────
  bool _showPhoneEdit = false;
  bool _showChangePassword = false;

  // ── Edit mode ─────────────────────────────────────────────────────────────
  bool _editMode = false;
  final _nameCtrl = TextEditingController();
  String? _nameError;
  bool _isSaving = false;
  String? _saveError;
  String? _saveSuccess;

  // ── Toggle prefs (local UI state — extend to Firestore if needed) ─────────
  bool _notifications = true;
  bool _marketing = false;
  bool _smsAlerts = true;

  @override
  void initState() {
    super.initState();
    _seedFields();
  }

  void _seedFields() {
    final profile =
        context.read<UserProfileProvider>().profile;
    _nameCtrl.text = profile?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Save profile ──────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name cannot be empty.');
      return;
    }
    setState(() {
      _isSaving = true;
      _saveError = null;
      _saveSuccess = null;
      _nameError = null;
    });

    final err = await context
        .read<UserProfileProvider>()
        .updateProfile(displayName: name);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (err == null) {
        _editMode = false;
        _saveSuccess = 'Profile updated successfully.';
      } else {
        _saveError = err;
      }
    });
  }

  // ── Sub-view routing ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showPhoneEdit) {
      return _PhoneEditView(
        onBack: () => setState(() => _showPhoneEdit = false),
        onSaved: () => setState(() => _showPhoneEdit = false),
      );
    }
    if (_showChangePassword) {
      return _ChangePasswordView(
        onBack: () => setState(() => _showChangePassword = false),
      );
    }
    return _buildMain(context);
  }

  // ── Main layout ───────────────────────────────────────────────────────────

  Widget _buildMain(BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();
    final profile = profileProvider.profile;
    final auth = context.watch<AppAuthProvider>();
    final isGoogle = auth.isGoogleUser;

    return SubPageShell(
      title: 'Account settings',
      subtitle: 'Privacy, security & preferences',
      onBack: widget.onBack,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Feedback banners ────────────────────────────────────────────
            if (_saveSuccess != null) ...[
              _banner(_saveSuccess!, isError: false),
              const SizedBox(height: 12),
            ],
            if (_saveError != null) ...[
              _banner(_saveError!, isError: true),
              const SizedBox(height: 12),
            ],

            // ── Personal info ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PERSONAL INFO',
                    style: TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                if (!isGoogle)
                  GestureDetector(
                    onTap: () {
                      if (_editMode) {
                        _saveProfile();
                      } else {
                        setState(() {
                          _editMode = true;
                          _saveSuccess = null;
                          _saveError = null;
                        });
                      }
                    },
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kBrand))
                        : Text(
                            _editMode ? '✓ Save' : 'Edit',
                            style: TextStyle(
                                color: _editMode ? kGreen : kBrand,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kSurface2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  // Name — editable
                  _FieldRow(
                    label: 'Full name',
                    ctrl: _nameCtrl,
                    enabled: _editMode,
                    error: _nameError,
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Email — read-only (managed by Firebase Auth)
                  _ReadonlyFieldRow(
                    label: 'Email address',
                    value: profile?.email ?? auth.user?.email ?? '—',
                  ),
                  const SizedBox(height: 12),
                  // Phone — read-only display + change button
                  _buildPhoneRow(profile?.phoneNumber),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Security ────────────────────────────────────────────────────
            const SizedBox(height: 20),
            const Text('SECURITY',
                style: TextStyle(
                    color: kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kSurface2),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  if (!isGoogle) ...[
                    _SecurityTile(
                      icon: Icons.key_outlined,
                      label: 'Change password',
                      sub: 'Update your account password',
                      onTap: () => setState(
                          () => _showChangePassword = true),
                    ),
                    const Divider(
                        height: 1,
                        color: kSurface2,
                        indent: 16,
                        endIndent: 16),
                  ],
                  _SecurityTile(
                    icon: Icons.logout_outlined,
                    label: 'Sign out of all devices',
                    sub: 'Revokes your current session token',
                    onTap: () => _confirmSignOutAll(context, auth),
                  ),
                ],
              ),
            ),

            // ── Notifications & privacy ─────────────────────────────────────
            const SizedBox(height: 20),
            const Text('NOTIFICATIONS & PRIVACY',
                style: TextStyle(
                    color: kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kSurface2),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  _ToggleRow(
                    label: 'Push notifications',
                    sub: 'Order updates & offers',
                    on: _notifications,
                    onToggle: () =>
                        setState(() => _notifications = !_notifications),
                  ),
                  const Divider(
                      height: 1,
                      color: kSurface2,
                      indent: 16,
                      endIndent: 16),
                  _ToggleRow(
                    label: 'Marketing emails',
                    sub: 'Deals, new restaurants',
                    on: _marketing,
                    onToggle: () =>
                        setState(() => _marketing = !_marketing),
                  ),
                  const Divider(
                      height: 1,
                      color: kSurface2,
                      indent: 16,
                      endIndent: 16),
                  _ToggleRow(
                    label: 'SMS alerts',
                    sub: 'Delivery status via text',
                    on: _smsAlerts,
                    onToggle: () =>
                        setState(() => _smsAlerts = !_smsAlerts),
                  ),
                ],
              ),
            ),

            // ── Danger zone ─────────────────────────────────────────────────
            const SizedBox(height: 20),
            const Text('DANGER ZONE',
                style: TextStyle(
                    color: kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            _dangerBtn(
              'Delete account',
              onTap: () => _confirmDeleteAccount(context, auth),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phone row ─────────────────────────────────────────────────────────────

  Widget _buildPhoneRow(String? phoneNumber) {
    final hasPhone = phoneNumber != null && phoneNumber.isNotEmpty;
    final displayPhone =
        hasPhone ? PhoneValidator.format(phoneNumber) : 'Not set';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Contact number" — not "Phone verified" or "Verified phone".
        // SMS verification is not yet active; we never claim the number
        // has been verified.
        const Text(
          'Contact number',
          style: TextStyle(
              color: kMuted, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: kSurface2,
            border: Border.all(color: kSurface2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayPhone,
                  style: TextStyle(
                      color: hasPhone ? kInk : kMuted, fontSize: 14),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showPhoneEdit = true),
                child: Text(
                  hasPhone ? 'Change' : 'Add',
                  style: const TextStyle(
                      color: kBrand,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Confirmations ─────────────────────────────────────────────────────────

  Future<void> _confirmSignOutAll(
      BuildContext context, AppAuthProvider auth) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Sign out of all devices?',
      body:
          'This will revoke your current session token. Other active sessions will be invalidated within the hour.',
      confirmLabel: 'Sign out all',
      confirmColor: kRed,
    );
    if (confirmed != true || !mounted) return;
    final ok = await auth.signOutAllDevices();
    if (!ok && mounted) {
      setState(() => _saveError = auth.errorMessage ??
          'Sign out failed. Please try again.');
    }
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, AppAuthProvider auth) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Delete account?',
      body:
          'This will permanently delete your account, saved addresses, favourites, and all associated data. This cannot be undone.',
      confirmLabel: 'Delete account',
      confirmColor: kRed,
    );
    if (confirmed != true || !mounted) return;

    // For email/password accounts, get the password *before* any other await.
    String? password;
    if (!auth.isGoogleUser) {
      if (!context.mounted) return;
      password = await showDialog<String>(
        context: context,
        builder: (ctx) => _ReauthDialog(),
      );
      if (password == null || password.isEmpty) return;
    }

    if (!mounted) return;

    final reauthed = await auth.reauthenticate(password: password);
    if (!reauthed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await UserRepository.instance.deleteAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError =
            'Account deletion failed. Please try again or contact support.';
      });
    }
    // On success the auth state change fires and _AuthGate navigates away.
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: kSerif.copyWith(
                color: kInk,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        content: Text(body,
            style: const TextStyle(
                color: kMuted, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: kMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: confirmColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _dangerBtn(String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.08),
          border: Border.all(color: kRed.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                color: kRed, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _banner(String msg, {required bool isError}) {
    final color = isError ? kRed : kGreen;
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline,
              color: color,
              size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: TextStyle(
                      color: color, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}

// ── Phone edit sub-view ───────────────────────────────────────────────────────

/// Simple phone-number edit/add screen used from [AccountSettingsPage].
///
/// Validates format with [PhoneValidator], normalises to E.164, and calls
/// [UserRepository.updatePhoneNumber].  No OTP or SMS involved.
class _PhoneEditView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const _PhoneEditView({required this.onBack, required this.onSaved});

  @override
  State<_PhoneEditView> createState() => _PhoneEditViewState();
}

class _PhoneEditViewState extends State<_PhoneEditView> {
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();

  String? _phoneError;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the current number if one exists.
    final profile =
        context.read<UserProfileProvider>().profile;
    if (profile?.phoneNumber != null && profile!.phoneNumber!.isNotEmpty) {
      // Show local format for editing convenience (e.g. "0917 123 4567").
      _phoneCtrl.text = PhoneValidator.format(profile.phoneNumber!);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
      _successMessage = null;
    });

    try {
      await UserRepository.instance.updatePhoneNumber(e164);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = 'Contact number updated.';
      });
      // Short delay so the user sees the success state, then pop back.
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not save your number. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPageShell(
      title: 'Contact number',
      subtitle: 'Used by restaurants to reach you about your orders',
      onBack: widget.onBack,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banners
            if (_successMessage != null) ...[
              _StatusBanner(message: _successMessage!, isError: false),
              const SizedBox(height: 16),
            ],
            if (_errorMessage != null) ...[
              _StatusBanner(message: _errorMessage!, isError: true),
              const SizedBox(height: 16),
            ],

            // Info note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kBrand.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: kBrand.withValues(alpha: 0.18)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: kBrand, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your contact number is shared with the restaurant '
                      'when you place an order so they can reach you about '
                      'delivery or order details.',
                      style: TextStyle(
                          color: kInk, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Phone field
            const Text(
              'Contact number',
              style: TextStyle(
                  color: kInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildPhoneField(),
            const SizedBox(height: 6),
            const Text(
              'Format: 0917 123 4567 or +63 917 123 4567',
              style: TextStyle(color: kMuted, fontSize: 11),
            ),
            const SizedBox(height: 28),

            // Save button
            GestureDetector(
              onTap: _isLoading ? null : _save,
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
                    : const Text(
                        'Save',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
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
                    onSubmitted: (_) => _save(),
                    style:
                        const TextStyle(color: kInk, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '917 123 4567',
                      hintStyle: const TextStyle(
                          color: kMuted, fontSize: 15),
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
}

// ── Change Password sub-view ──────────────────────────────────────────────────

class _ChangePasswordView extends StatefulWidget {
  final VoidCallback onBack;
  const _ChangePasswordView({required this.onBack});

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _currentVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;
  String? _currentError;
  String? _newError;
  String? _confirmError;
  bool _isLoading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    String? ce, ne, coe;
    if (_currentCtrl.text.isEmpty) ce = 'Current password is required.';
    if (_newCtrl.text.isEmpty) {
      ne = 'New password is required.';
    } else if (_newCtrl.text.length < 6) {
      ne = 'Password must be at least 6 characters.';
    }
    if (_confirmCtrl.text != _newCtrl.text) {
      coe = 'Passwords do not match.';
    }
    setState(() {
      _currentError = ce;
      _newError = ne;
      _confirmError = coe;
    });
    return ce == null && ne == null && coe == null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });
    final auth = context.read<AppAuthProvider>();
    final ok = await auth.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _success = 'Password changed successfully.';
        _currentCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
      } else {
        _error = auth.errorMessage ?? 'Password change failed.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SubPageShell(
      title: 'Change password',
      subtitle: 'Enter your current password to continue',
      onBack: widget.onBack,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_success != null) ...[
              _StatusBanner(message: _success!, isError: false),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              _StatusBanner(message: _error!, isError: true),
              const SizedBox(height: 16),
            ],
            _PwdField(
                label: 'Current password',
                ctrl: _currentCtrl,
                visible: _currentVisible,
                error: _currentError,
                onToggle: () => setState(
                    () => _currentVisible = !_currentVisible),
                onChanged: (_) =>
                    setState(() => _currentError = null),
                enabled: !_isLoading),
            const SizedBox(height: 16),
            _PwdField(
                label: 'New password',
                ctrl: _newCtrl,
                visible: _newVisible,
                error: _newError,
                onToggle: () =>
                    setState(() => _newVisible = !_newVisible),
                onChanged: (_) => setState(() => _newError = null),
                enabled: !_isLoading),
            const SizedBox(height: 16),
            _PwdField(
                label: 'Confirm new password',
                ctrl: _confirmCtrl,
                visible: _confirmVisible,
                error: _confirmError,
                onToggle: () => setState(
                    () => _confirmVisible = !_confirmVisible),
                onChanged: (_) =>
                    setState(() => _confirmError = null),
                enabled: !_isLoading),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _isLoading ? null : _submit,
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
                    : const Text('Update password',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Re-auth dialog ────────────────────────────────────────────────────────────

class _ReauthDialog extends StatefulWidget {
  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final _ctrl = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Confirm your password',
          style: kSerif.copyWith(
              color: kInk,
              fontWeight: FontWeight.w900,
              fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Enter your current password to continue.',
              style: TextStyle(
                  color: kMuted, fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: !_visible,
            style: const TextStyle(color: kInk, fontSize: 14),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: const TextStyle(color: kMuted),
              filled: true,
              fillColor: kSurface2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: kBrand, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              isDense: true,
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _visible = !_visible),
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                      _visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: kMuted),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel',
              style: TextStyle(
                  color: kMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: const Text('Confirm',
              style: TextStyle(
                  color: kBrand,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Shared field widgets ──────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool enabled;
  final String? error;
  final ValueChanged<String>? onChanged;

  const _FieldRow({
    required this.label,
    required this.ctrl,
    required this.enabled,
    this.error,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          enabled: enabled,
          onChanged: onChanged,
          style: TextStyle(
              color: enabled ? kInk : kMuted, fontSize: 14),
          decoration: InputDecoration(
            errorText: error,
            errorStyle: const TextStyle(color: kRed, fontSize: 12),
            filled: true,
            fillColor: enabled ? kSurface : kSurface2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: error != null ? kRed : kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: error != null ? kRed : kBorder)),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kSurface2)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: kBrand, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _ReadonlyFieldRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadonlyFieldRow(
      {required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: kSurface2,
            border: Border.all(color: kSurface2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value,
              style:
                  const TextStyle(color: kMuted, fontSize: 14)),
        ),
      ],
    );
  }
}

class _PwdField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool visible;
  final String? error;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const _PwdField({
    required this.label,
    required this.ctrl,
    required this.visible,
    this.error,
    required this.onToggle,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          enabled: enabled,
          obscureText: !visible,
          onChanged: onChanged,
          style: const TextStyle(color: kInk, fontSize: 14),
          decoration: InputDecoration(
            errorText: error,
            errorStyle:
                const TextStyle(color: kRed, fontSize: 12),
            filled: true,
            fillColor: kSurface2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: error != null ? kRed : kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: error != null ? kRed : kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: kBrand, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            isDense: true,
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: kMuted),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _SecurityTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: kSurface2,
                  borderRadius: BorderRadius.circular(12)),
              child:
                  Center(child: Icon(icon, size: 18, color: kInk)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: kInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(sub,
                      style: const TextStyle(
                          color: kMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: kBorder, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool on;
  final VoidCallback onToggle;

  const _ToggleRow({
    required this.label,
    required this.sub,
    required this.on,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: kInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(sub,
                    style: const TextStyle(
                        color: kMuted, fontSize: 12)),
              ],
            ),
          ),
          _Toggle(on: on, onToggle: onToggle),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool on;
  final VoidCallback onToggle;

  const _Toggle({required this.on, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: on ? kBrand : kBorder,
          borderRadius: BorderRadius.circular(100),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _StatusBanner(
      {required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? kRed : kGreen;
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  style: TextStyle(
                      color: color, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}
