import 'package:flutter/material.dart';

import '../theme/cafe_theme.dart';
import 'cafe_widgets.dart';

class MetricTrio extends StatelessWidget {
  const MetricTrio({
    super.key,
    required this.title,
    required this.subtitle,
    required this.salesLabel,
    required this.sales,
    required this.expensesLabel,
    required this.expenses,
    required this.netLabel,
    required this.net,
  });

  final String title;
  final String subtitle;
  final String salesLabel;
  final String sales;
  final String expensesLabel;
  final String expenses;
  final String netLabel;
  final String net;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CafeTheme.display.copyWith(fontSize: 22)),
        Text(subtitle, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 720;
            final cards = [
              _box(salesLabel, sales, CafeColors.ink),
              _box(expensesLabel, expenses, CafeColors.alert),
              _box(netLabel, net, CafeColors.ink),
            ];
            if (stacked) {
              return Column(
                children: [
                  for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
                ],
              );
            }
            return Row(
              children: [
                for (final card in cards) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: card)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _box(String label, String value, Color color) {
    return SoftCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
          Text(value, style: CafeTheme.display.copyWith(fontSize: 24, color: color)),
        ],
      ),
    );
  }
}
