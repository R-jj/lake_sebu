import 'package:flutter/material.dart';
import '../constants.dart';
import '_sub_page_shell.dart';

class AccountSettingsPage extends StatefulWidget {
  final VoidCallback onBack;

  const AccountSettingsPage({super.key, required this.onBack});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  // Profile fields
  final _nameCtrl = TextEditingController(text: 'Alex Rivera');
  final _emailCtrl = TextEditingController(text: 'alex.rivera@email.com');
  final _phoneCtrl = TextEditingController(text: '+1 (212) 555-0194');
  bool _editMode = false;

  // Toggle prefs
  bool _notifications = true;
  bool _marketing = false;
  bool _smsAlerts = true;
  bool _twoFactor = false;
  bool _dataSharing = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toggleRows = [
      {
        'label': 'Push notifications',
        'sub': 'Order updates & offers',
        'on': _notifications,
        'toggle': () => setState(() => _notifications = !_notifications),
      },
      {
        'label': 'Marketing emails',
        'sub': 'Deals, new restaurants',
        'on': _marketing,
        'toggle': () => setState(() => _marketing = !_marketing),
      },
      {
        'label': 'SMS alerts',
        'sub': 'Delivery status via text',
        'on': _smsAlerts,
        'toggle': () => setState(() => _smsAlerts = !_smsAlerts),
      },
      {
        'label': 'Two-factor auth',
        'sub': 'Extra login security',
        'on': _twoFactor,
        'toggle': () => setState(() => _twoFactor = !_twoFactor),
      },
      {
        'label': 'Data sharing',
        'sub': 'Help improve the app',
        'on': _dataSharing,
        'toggle': () => setState(() => _dataSharing = !_dataSharing),
      },
    ];

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
            // Personal info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PERSONAL INFO',
                    style: TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                GestureDetector(
                  onTap: () => setState(() => _editMode = !_editMode),
                  child: Text(
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kSurface2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  _Field(label: 'Full name', ctrl: _nameCtrl, enabled: _editMode),
                  const SizedBox(height: 12),
                  _Field(label: 'Email address', ctrl: _emailCtrl, enabled: _editMode),
                  const SizedBox(height: 12),
                  _Field(label: 'Phone number', ctrl: _phoneCtrl, enabled: _editMode),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            // Security
            const SizedBox(height: 20),
            const Text('SECURITY',
                style: TextStyle(
                    color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
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
                  _SecurityTile(
                      icon: Icons.key_outlined,
                      label: 'Change password',
                      sub: 'Last changed 3 months ago'),
                  const Divider(height: 1, color: kSurface2, indent: 16, endIndent: 16),
                  _SecurityTile(
                      icon: Icons.phone_iphone,
                      label: 'Manage devices',
                      sub: '2 active sessions'),
                ],
              ),
            ),

            // Notifications & privacy
            const SizedBox(height: 20),
            const Text('NOTIFICATIONS & PRIVACY',
                style: TextStyle(
                    color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kSurface2),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: List.generate(toggleRows.length, (i) {
                  final row = toggleRows[i];
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row['label'] as String,
                                      style: const TextStyle(
                                          color: kInk,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 1),
                                  Text(row['sub'] as String,
                                      style: const TextStyle(color: kMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            _Toggle(
                                on: row['on'] as bool,
                                onToggle: row['toggle'] as VoidCallback),
                          ],
                        ),
                      ),
                      if (i < toggleRows.length - 1)
                        const Divider(
                            height: 1, color: kSurface2, indent: 16, endIndent: 16),
                    ],
                  );
                }),
              ),
            ),

            // Danger zone
            const SizedBox(height: 20),
            const Text('DANGER ZONE',
                style: TextStyle(
                    color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 12),
            _dangerBtn('Sign out of all devices', kRed, filled: true),
            const SizedBox(height: 10),
            _dangerBtn('Delete account', kRed.withValues(alpha: 0.6), filled: false),
          ],
        ),
      ),
    );
  }

  Widget _dangerBtn(String label, Color textColor, {required bool filled}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: filled ? kRed.withValues(alpha: 0.08) : Colors.transparent,
        border: Border.all(
            color: filled ? kRed.withValues(alpha: 0.2) : kRed.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Field widget ──────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool enabled;

  const _Field({required this.label, required this.ctrl, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          enabled: enabled,
          style: TextStyle(
              color: enabled ? kInk : kMuted, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? kSurface : kSurface2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: enabled ? kBorder : kSurface2)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder)),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kSurface2)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBrand, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ── Security tile ─────────────────────────────────────────────────────────────

class _SecurityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const _SecurityTile(
      {required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Icon(icon, size: 18, color: kInk)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: kInk, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(sub, style: const TextStyle(color: kMuted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kBorder, size: 18),
        ],
      ),
    );
  }
}

// ── Toggle ────────────────────────────────────────────────────────────────────

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
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
