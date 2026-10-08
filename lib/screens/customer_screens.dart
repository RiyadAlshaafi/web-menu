import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../l10n/l10n_ext.dart';
import '../time_format.dart';
import '../report_error.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_widgets.dart';
import '../widgets/tawla_mark.dart';

part 'customer/loading.dart';
part 'customer/menu.dart';
part 'customer/cart.dart';
part 'customer/bill.dart';
part 'customer/call_staff.dart';
part 'customer/guest_parts.dart';
