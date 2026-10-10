import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../l10n/l10n_ext.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_widgets.dart';
import '../widgets/tawla_mark.dart';
import '../widgets/update_panel.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> with SingleTickerProviderStateMixin {
  final focusNode = FocusNode();
  bool _signingIn = false;
  late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  late final Animation<double> shakeOffset = TweenSequence<double>([
    for (final (from, to) in const [(0.0, -8.0), (-8.0, 8.0), (8.0, -6.0), (-6.0, 6.0), (6.0, -3.0), (-3.0, 0.0)])
      TweenSequenceItem(tween: Tween(begin: from, end: to).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
  ]).animate(shake);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
  }

  @override
  void dispose() {
    focusNode.dispose();
    shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final cashiers = store.cashiers.where((item) => item.active).toList();
    final selected = cashiers.where((item) => item.id == store.selectedCashierId);
    final selectedName = selected.isEmpty ? context.l10n.authGuestCashier : selected.first.name;

    return KeyboardListener(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final key = event.logicalKey.keyLabel;
        if (RegExp(r'^[0-9]$').hasMatch(key)) {
          store.enterPinDigit(key);
        } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
          store.deletePin();
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _submit(store);
        }
      },
      child: CafeAuthFrame(
        maxWidth: 920,
        background: const Stack(
          children: [
            Positioned(top: 80, right: 40, child: _Glow()),
            Positioned(bottom: 120, left: 40, child: _Glow()),
          ],
        ),
        child: Column(
          children: [
            const UpdatePanel(),
            if (store.serverUnreachable) ...[
              _OfflineStartCard(store: store),
              const SizedBox(height: 16),
            ] else if (!store.deviceLinked) ...[
              Text(context.l10n.authDeviceNotLinked, style: const TextStyle(color: CafeColors.alert, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                _DevLogo(
                  child: _AuthBrand(subtitle: context.l10n.authPosTerminalSubtitle.replaceAll('\n', ' ')),
                ),
                const Spacer(),
                GhostChip(
                  label: context.l10n.authSwitchToAdminSignIn,
                  icon: Icons.shield_outlined,
                  onTap: () => context.go(store.hasAdmin ? '/admin/login' : '/admin/setup'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SoftCard(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: CafeColors.peach,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.apps, color: CafeColors.terracotta),
                      ),
                      const SizedBox(height: 14),
                      Text(context.l10n.authCashierSignInTitle, style: CafeTheme.display.copyWith(fontSize: 32)),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.authCashierSignInSubtitle,
                        style: const TextStyle(color: CafeColors.inkMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      if (cashiers.isEmpty)
                        EmptyHint(context.l10n.noCashiers)
                      else
                        Row(
                          children: cashiers.take(3).map((member) {
                            final active = member.id == store.selectedCashierId;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: InkWell(
                                  onTap: () => store.selectCashier(member.id),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
                                    decoration: BoxDecoration(
                                      color: CafeColors.key,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: active ? CafeSurfaces.of(context).button : Colors.transparent,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: CafeColors.terracottaSoft,
                                          child: Text(
                                            member.initials,
                                            style: const TextStyle(
                                              color: CafeColors.terracottaDark,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 18),
                      AnimatedBuilder(
                        animation: shakeOffset,
                        builder: (context, child) => Transform.translate(offset: Offset(shakeOffset.value, 0), child: child),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final filled = index < store.pinBuffer.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled ? CafeColors.terracotta : const Color(0xFFD9D0C8),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          text: context.l10n.authAuthenticatingAs,
                          style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
                          children: [
                            TextSpan(
                              text: selectedName,
                              style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      if (store.loginError != null) ...[
                        const SizedBox(height: 6),
                        Text(store.loginError!, style: const TextStyle(color: CafeColors.alert, fontSize: 12)),
                      ],
                      const SizedBox(height: 14),
                      _PinPad(store: store),
                      const SizedBox(height: 16),
                      TerracottaButton(
                        label: context.l10n.authSignIn,
                        showArrow: true,
                        busy: _signingIn,
                        onPressed: _signingIn ? null : () => _submit(store),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.authPosFooter(context.watch<CafeStore>().cafeName),
              style: const TextStyle(color: CafeColors.inkMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(CafeStore store) async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    if (!await store.signInCashier()) {
      if (mounted) setState(() => _signingIn = false);
      if (mounted && !MediaQuery.disableAnimationsOf(context)) shake.forward(from: 0);
      return;
    }
    if (!mounted) return;
    context.go('/pos');
  }
}

/// Shown at startup when the server can't be reached: offers to keep selling offline.
class _OfflineStartCard extends StatelessWidget {
  const _OfflineStartCard({required this.store});
  final CafeStore store;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SoftCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_off, color: CafeColors.alert),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(context.l10n.offlineStartTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                store.canStartOffline ? context.l10n.offlineStartBody : context.l10n.offlineNeverOnline,
                style: const TextStyle(color: CafeColors.inkMuted, height: 1.35),
              ),
              if (store.canStartOffline) ...[
                const SizedBox(height: 14),
                TerracottaButton(
                  label: context.l10n.offlineStartButton,
                  onPressed: () async {
                    await store.startOfflineSession();
                    if (context.mounted) context.go('/pos/takeout');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.store});
  final CafeStore store;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['Clear', '0', 'DEL'],
    ];
    const letters = {
      '2': 'ABC',
      '3': 'DEF',
      '4': 'GHI',
      '5': 'JKL',
      '6': 'MNO',
      '7': 'PQRS',
      '8': 'TUV',
      '9': 'WXYZ',
      '0': '-',
    };
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((key) {
              final isAction = key == 'Clear' || key == 'DEL';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Material(
                    color: isAction ? Colors.transparent : CafeColors.key,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (key == 'Clear') {
                          store.clearPin();
                        } else if (key == 'DEL') {
                          store.deletePin();
                        } else {
                          store.enterPinDigit(key);
                        }
                      },
                      child: SizedBox(
                        height: 58,
                        child: Center(
                          child: key == 'DEL'
                              ? const Icon(Icons.backspace_outlined, size: 18)
                              : key == 'Clear'
                                  ? Text(context.l10n.authPinClear, style: const TextStyle(color: CafeColors.inkMuted))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                        if (letters[key] != null)
                                          Text(letters[key]!, style: const TextStyle(fontSize: 9, color: CafeColors.inkMuted)),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 220,
        height: 220,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color(0x33C24A2D), Color(0x00F7F1E9)]),
        ),
      ),
    );
  }
}

class AdminAuthScreen extends StatefulWidget {
  const AdminAuthScreen({super.key, this.setup = false});

  final bool setup;

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final setupCode = TextEditingController();
  bool obscure = true;
  bool remember = false;
  bool signingIn = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    setupCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final setup = widget.setup;

    return CafeAuthFrame(
      child: Column(
        children: [
          Row(
            children: [
              const _DevLogo(child: _AuthBrand()),
              const Spacer(),
              GhostChip(
                label: context.l10n.authStaffPos,
                icon: Icons.point_of_sale,
                onTap: () => context.go('/login'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(color: CafeColors.peach, shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_outlined, color: CafeColors.terracotta),
                ),
                const SizedBox(height: 14),
                Text(
                  setup ? context.l10n.authCreateAdminAccess : context.l10n.authAdminSignIn,
                  style: CafeTheme.display.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.l10n.authManagerEmail, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'admin@cafeitaliano.com',
                    prefixIcon: Icon(Icons.mail_outline, size: 18),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(context.l10n.authPassword, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const Spacer(),
                    if (!setup)
                      TextButton(
                        onPressed: () {
                          context.go('/admin/forgot', extra: email.text);
                        },
                        child: Text(context.l10n.authForgotPasswordLink, style: const TextStyle(color: CafeColors.terracotta)),
                      ),
                  ],
                ),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: setup ? context.l10n.authCreateStrongPassword : '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                    ),
                  ),
                ),
                if (setup) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.l10n.authConfirmPassword, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: context.l10n.authRepeatPassword,
                      prefixIcon: const Icon(Icons.verified_user_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.l10n.authSetupCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: setupCode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: context.l10n.authSetupCodeHint,
                      prefixIcon: const Icon(Icons.key_outlined, size: 18),
                    ),
                  ),
                  if (!store.deviceLinked) ...[
                    const SizedBox(height: 8),
                    Text(context.l10n.authDeviceNotLinked, style: const TextStyle(color: CafeColors.alert, fontSize: 12)),
                  ],
                ],
                const SizedBox(height: 12),
                if (!setup)
                  Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: Checkbox(
                          value: remember,
                          onChanged: (value) => setState(() => remember = value ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(context.l10n.authKeepSignedIn),
                    ],
                  ),
                if (error != null || store.adminError != null) ...[
                  const SizedBox(height: 8),
                  Text(error ?? store.adminError!, style: const TextStyle(color: CafeColors.alert, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                TerracottaButton(
                  label: setup ? context.l10n.authCreateAccessCta : context.l10n.authSignInCta,
                  busy: signingIn,
                  onPressed: signingIn
                      ? null
                      : () async {
                    if (!setup) setState(() => signingIn = true);
                    if (setup) {
                      final result = await store.createAdmin(
                        email: email.text,
                        password: password.text,
                        confirm: confirm.text,
                        setupCode: setupCode.text,
                      );
                      if (!context.mounted) return;
                      if (result != null) {
                        setState(() => error = result);
                      } else {
                        context.go('/admin/dashboard');
                      }
                    } else {
                      final result = await store.signInAdmin(email.text, password.text, remember: remember);
                      if (!context.mounted) return;
                      if (result == null) {
                        context.go('/admin/dashboard');
                      } else {
                        setState(() => signingIn = false);
                      }
                    }
                  },
                ),
                if (setup) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go('/admin/login'),
                    child: Text(
                      context.l10n.authHaveAccountSignIn,
                      style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final email = TextEditingController(text: widget.email);
  final digits = List.generate(6, (_) => TextEditingController());
  final nodes = List.generate(6, (_) => FocusNode());
  String? error;
  Timer? timer;
  int cooldown = 44;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => cooldown = cooldown > 0 ? cooldown - 1 : 0);
    });
  }

  @override
  void dispose() {
    email.dispose();
    for (final item in digits) {
      item.dispose();
    }
    for (final item in nodes) {
      item.dispose();
    }
    timer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final store = context.read<CafeStore>();
    final failure = await store.requestPasswordReset(email.text);
    if (!mounted) return;
    setState(() {
      error = failure;
      if (failure == null) cooldown = 44;
    });
  }

  String get code => digits.map((item) => item.text).join();

  @override
  Widget build(BuildContext context) {
    return CafeAuthFrame(
      child: Column(
        children: [
          Row(
            children: [
              const _AuthBrand(),
              const Spacer(),
              GhostChip(
                label: context.l10n.authAdminSignIn,
                icon: Icons.home_outlined,
                onTap: () => context.go('/admin/login'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SoftCard(
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: CafeColors.terracottaSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.lock_reset, color: CafeColors.terracotta),
                        ),
                        const SizedBox(height: 14),
                        Text(context.l10n.authForgotPasswordTitle, style: CafeTheme.display.copyWith(fontSize: 30)),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.authForgotPasswordSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: CafeColors.inkMuted),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            return Container(
                              width: 48,
                              height: 56,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: CafeColors.key,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: digits[index].text.isNotEmpty ? CafeSurfaces.of(context).button : Colors.transparent,
                                ),
                              ),
                              child: TextField(
                                controller: digits[index],
                                focusNode: nodes[index],
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  counterText: '',
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 5) nodes[index + 1].requestFocus();
                                  setState(() {});
                                },
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.authSafeCodeSent,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: cooldown == 0 ? _send : null,
                          child: Text.rich(
                            TextSpan(
                              text: context.l10n.authDidntReceive,
                              style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13),
                              children: [
                                TextSpan(
                                  text: cooldown > 0
                                      ? context.l10n.authResendCodeIn('0:${cooldown.toString().padLeft(2, '0')}')
                                      : context.l10n.authResendCode,
                                  style: TextStyle(color: CafeSurfaces.of(context).buttonInk, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(error!, style: const TextStyle(color: CafeColors.alert)),
                        ],
                        const SizedBox(height: 18),
                        TerracottaButton(
                          label: context.l10n.authVerifyCodeCta,
                          onPressed: () async {
                            final result = await context.read<CafeStore>().verifyOtp(code);
                            if (!context.mounted) return;
                            if (result != null) {
                              setState(() => error = result);
                            } else {
                              context.go('/admin/password');
                            }
                          },
                        ),
                        TextButton(
                          onPressed: () => context.go('/admin/login'),
                          child: Text(context.l10n.authBackToSignIn, style: const TextStyle(color: CafeColors.ink)),
                        ),
                      ],
                    ),
                  ),
          const SizedBox(height: 24),
          Text(
            context.l10n.authForgotFooter,
            style: const TextStyle(color: CafeColors.inkMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  bool get hasLen => password.text.length >= 8;
  bool get hasNum => RegExp(r'[0-9]').hasMatch(password.text);
  bool get hasCap => RegExp(r'[A-Z]').hasMatch(password.text);
  bool get hasSym => RegExp(r'[^A-Za-z0-9]').hasMatch(password.text);
  bool get match => password.text.isNotEmpty && password.text == confirm.text;
  int get score => [hasLen, hasNum, hasCap, hasSym].where((item) => item).length;

  @override
  Widget build(BuildContext context) {
    return CafeAuthFrame(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _AuthBrand(subtitle: context.l10n.authHospitalityCoreAdmin),
          ),
          const SizedBox(height: 28),
          SoftCard(
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: CafeColors.terracottaSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.vpn_key, color: CafeColors.terracotta),
                        ),
                        const SizedBox(height: 14),
                        Text(context.l10n.authSetNewPasswordTitle, style: CafeTheme.display.copyWith(fontSize: 30)),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.authSetNewPasswordSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: CafeColors.inkMuted),
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(context.l10n.authNewPassword, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => obscure = !obscure),
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(4, (index) {
                            return Expanded(
                              child: Container(
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                color: index < score ? CafeColors.terracotta : CafeColors.line,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(context.l10n.authConfirmNewPassword, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: confirm,
                          obscureText: true,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.verified_user_outlined, size: 18),
                            suffixIcon: Icon(Icons.visibility_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(match ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: match ? CafeColors.success : CafeColors.inkMuted),
                            const SizedBox(width: 6),
                            Text(context.l10n.authPasswordsMustMatch, style: const TextStyle(fontSize: 12, color: CafeColors.inkMuted)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.authPasswordRequirements, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 18,
                                runSpacing: 6,
                                children: [
                                  _req(context.l10n.authReqMinLength, hasLen),
                                  _req(context.l10n.authReqNumber, hasNum),
                                  _req(context.l10n.authReqCapital, hasCap),
                                  _req(context.l10n.authReqSymbol, hasSym),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(error!, style: const TextStyle(color: CafeColors.alert)),
                        ],
                        const SizedBox(height: 18),
                        TerracottaButton(
                          label: context.l10n.authUpdatePasswordCta,
                          onPressed: () async {
                            final result = await context.read<CafeStore>().completePasswordReset(
                                  password: password.text,
                                  confirm: confirm.text,
                                );
                            if (!context.mounted) return;
                            if (result != null) {
                              setState(() => error = result);
                            } else {
                              context.go('/admin/login');
                            }
                          },
                        ),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(context.l10n.authReturnToStaffSignIn, style: const TextStyle(color: CafeColors.ink)),
                        ),
                      ],
                    ),
                  ),
          const SizedBox(height: 24),
          Text(
            context.l10n.authChangePasswordFooter(
              context.watch<CafeStore>().cafeName,
              context.watch<CafeStore>().appVersion,
            ),
            style: const TextStyle(color: CafeColors.inkMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _req(String label, bool ok) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: ok ? CafeColors.success : CafeColors.inkMuted),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DevLogo extends StatefulWidget {
  const _DevLogo({required this.child});

  final Widget child;

  @override
  State<_DevLogo> createState() => _DevLogoState();
}

class _DevLogoState extends State<_DevLogo> {
  int taps = 0;
  DateTime? started;

  Future<void> _hit() async {
    final now = DateTime.now();
    if (started == null || now.difference(started!) > const Duration(seconds: 3)) {
      started = now;
      taps = 1;
    } else {
      taps += 1;
    }
    if (taps < 7) return;
    taps = 0;
    started = null;
    final password = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.devPasswordTitle),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, password.text),
            child: Text(context.l10n.commonOk),
          ),
        ],
      ),
    );
    final value = entered ?? '';
    password.dispose();
    if (!mounted || value.isEmpty) return;
    final allowed = await AppDatabase.instance.checkDevAccess(value);
    if (!mounted || !allowed) return;
    context.go('/dev', extra: value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _hit, child: widget.child);
  }
}

/// The Tawla lockup with the cafe's name beside it, at the top of every sign-in page.
class _AuthBrand extends StatelessWidget {
  const _AuthBrand({this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final name = context.watch<CafeStore>().cafeName;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Directionality(textDirection: TextDirection.ltr, child: TawlaLockup(size: 30)),
        Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 14), color: CafeColors.line),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: CafeColors.ink)),
              Text(
                (subtitle ?? context.l10n.brandTagline).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: CafeColors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
