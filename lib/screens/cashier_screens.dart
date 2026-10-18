import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/choice_labels.dart';
import '../l10n/l10n_ext.dart';
import '../printing/receipt_print.dart';
import '../core/time_format.dart';
import '../features/app_feature.dart';
import '../models/models.dart';
import '../navigation/app_sections.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/cafe_dialogs.dart';
import '../widgets/cafe_widgets.dart';
import '../widgets/dish_choices_sheet.dart';
import '../widgets/scroll_when_short.dart';
import '../widgets/shell_parts.dart';
import '../widgets/tawla_ui.dart';
import '../widgets/update_panel.dart';


part 'cashier/shell.dart';
part 'cashier/live_alerts.dart';
part 'cashier/settle_panel.dart';
part 'cashier/floor_overview.dart';
part 'cashier/shift_sales.dart';
part 'cashier/quick_takeout.dart';
part 'cashier/table_order.dart';
part 'cashier/shared.dart';
