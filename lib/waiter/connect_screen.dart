import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../lan/lan_protocol.dart';
import '../theme/cafe_theme.dart';
import '../widgets/tawla_mark.dart';
import 'waiter_state.dart';

/// First screen on a new phone: find the till on the Wi-Fi and wait for the cashier to allow it.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _name.text = context.read<WaiterController>().deviceName;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiter = context.watch<WaiterController>();
    return Scaffold(
      backgroundColor: CafeColors.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              children: [
                const Center(child: TawlaLockup(size: 30)),
                const SizedBox(height: 28),
                ...switch (waiter.phase) {
                  WaiterPhase.starting || WaiterPhase.searching => _searching(context),
                  WaiterPhase.pairing => _pairing(context),
                  WaiterPhase.denied => _problem(context, Icons.block, context.l10n.waiterDenied),
                  WaiterPhase.noAnswer => _problem(context, Icons.wifi_off, context.l10n.waiterNoAnswer),
                  WaiterPhase.choose || WaiterPhase.ready => _choose(context, waiter),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _searching(BuildContext context) => [
    const SizedBox(height: 40),
    const Center(child: TawlaLoader(size: 96)),
    const SizedBox(height: 24),
    Text(context.l10n.waiterSearching, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    Text(context.l10n.waiterSearchingHint, textAlign: TextAlign.center, style: const TextStyle(color: CafeColors.inkMuted)),
  ];

  List<Widget> _pairing(BuildContext context) => [
    const SizedBox(height: 40),
    const Center(child: TawlaLoader(size: 96)),
    const SizedBox(height: 24),
    Text(context.l10n.waiterWaitingAllow, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    Text(context.l10n.waiterWaitingAllowHint, textAlign: TextAlign.center, style: const TextStyle(color: CafeColors.inkMuted)),
  ];

  List<Widget> _problem(BuildContext context, IconData icon, String message) => [
    const SizedBox(height: 40),
    Icon(icon, size: 64, color: CafeColors.alert),
    const SizedBox(height: 16),
    Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 24),
    _BigButton(
      label: context.l10n.waiterTryAgain,
      icon: Icons.refresh,
      onPressed: () => context.read<WaiterController>().search(),
    ),
  ];

  List<Widget> _choose(BuildContext context, WaiterController waiter) {
    final l10n = context.l10n;
    return [
      Text(l10n.waiterFoundTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        decoration: InputDecoration(
          labelText: l10n.waiterYourName,
          prefixIcon: const Icon(Icons.badge_outlined),
          counterText: '',
        ),
      ),
      const SizedBox(height: 16),
      if (waiter.found.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const Icon(Icons.wifi_find, size: 48, color: CafeColors.inkMuted),
              const SizedBox(height: 8),
              Text(l10n.waiterSearchingHint, textAlign: TextAlign.center, style: const TextStyle(color: CafeColors.inkMuted)),
            ],
          ),
        ),
      for (final hub in waiter.found)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TillCard(
            hub: hub,
            onTap: () => waiter.connect(hub, name: _name.text),
          ),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: waiter.search,
        icon: const Icon(Icons.refresh),
        label: Text(l10n.waiterSearchAgain),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      const SizedBox(height: 12),
      if (!_typing)
        TextButton(
          onPressed: () => setState(() => _typing = true),
          child: Text(l10n.waiterEnterAddress),
        )
      else
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _address,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.waiterEnterAddress, hintText: l10n.waiterAddressHint),
                onSubmitted: (_) => _connectTyped(waiter),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _connectTyped(waiter),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 52)),
              child: Text(l10n.waiterConnect),
            ),
          ],
        ),
    ];
  }

  void _connectTyped(WaiterController waiter) {
    final address = _address.text.trim();
    if (address.isEmpty) return;
    waiter.connectToAddress(address, name: _name.text);
  }
}

class _TillCard extends StatelessWidget {
  const _TillCard({required this.hub, required this.onTap});

  final FoundHub hub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: CafeColors.terracottaSoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.storefront, color: CafeColors.terracotta, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hub.cafeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(hub.host, style: const TextStyle(color: CafeColors.inkMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: CafeColors.terracotta),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
    );
  }
}
