import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/money.dart';
import '../l10n/l10n_ext.dart';
import '../theme/cafe_theme.dart';

typedef CafeDateSelection = ({DateTime? start, DateTime? end});

Future<CafeDateSelection?> showCafeDatePicker({
  required BuildContext context,
  DateTime? value,
  DateTimeRange? range,
}) {
  return showDialog<CafeDateSelection>(
    context: context,
    builder: (_) => _CafeDatePicker(value: value, range: range),
  );
}

Future<DateTime?> showCafeMonthPicker({
  required BuildContext context,
  required DateTime value,
  required DateTime firstMonth,
  required DateTime lastMonth,
}) async {
  final picked = await showDialog<CafeDateSelection>(
    context: context,
    builder: (_) => _CafeDatePicker(
      value: DateUtils.addMonthsToMonthDate(value, 0),
      monthBounds: DateTimeRange(
        start: DateUtils.addMonthsToMonthDate(firstMonth, 0),
        end: DateUtils.addMonthsToMonthDate(lastMonth, 0),
      ),
    ),
  );
  return picked?.start;
}

enum _View { days, months, years, input }

class _CafeDatePicker extends StatefulWidget {
  const _CafeDatePicker({this.value, this.range, this.monthBounds});

  final DateTime? value;
  final DateTimeRange? range;
  final DateTimeRange? monthBounds;

  @override
  State<_CafeDatePicker> createState() => _CafeDatePickerState();
}

class _CafeDatePickerState extends State<_CafeDatePicker> {
  final _today = DateUtils.dateOnly(toTripoli(DateTime.now()));
  final _form = GlobalKey<FormState>();
  late final _first = widget.monthBounds?.start ?? DateTime(2020);
  late final _last =
      widget.monthBounds?.end ??
      DateTime(_today.year, _today.month, _today.day + 1);
  late DateTime? _start = _bounded(widget.range?.start ?? widget.value);
  late DateTime? _end = _bounded(widget.range?.end);
  late DateTime _month = DateUtils.addMonthsToMonthDate(_start ?? _today, 0);
  late _View _view = _monthOnly ? _View.months : _View.days;
  bool _invalidRange = false;
  DateTime? _inputStart;
  DateTime? _inputEnd;

  bool get _isRange => widget.range != null;
  bool get _monthOnly => widget.monthBounds != null;

  DateTime? _bounded(DateTime? value) {
    if (value == null) return null;
    final date = DateUtils.dateOnly(value);
    if (date.isBefore(_first)) return _first;
    if (date.isAfter(_last)) return _last;
    return date;
  }

  bool _monthAvailable(DateTime month) =>
      !month.isBefore(_first) &&
      !month.isAfter(DateUtils.addMonthsToMonthDate(_last, 0));

  void _pickDay(DateTime day) {
    setState(() {
      final start = _start;
      if (_isRange && start != null && _end == null && !day.isBefore(start)) {
        _end = day;
      } else {
        _start = day;
        _end = null;
      }
    });
  }

  void _submit() {
    if (_view == _View.input) {
      if (!_form.currentState!.validate()) return;
      _form.currentState!.save();
      if (_isRange && _inputEnd!.isBefore(_inputStart!)) {
        setState(() => _invalidRange = true);
        return;
      }
      _start = _inputStart;
      _end = _inputEnd;
    }
    Navigator.pop(context, (start: _start, end: _end));
  }

  @override
  Widget build(BuildContext context) {
    final strings = MaterialLocalizations.of(context);
    final colors = CafeSurfaces.of(context);
    final start = _start;
    final end = _end;
    final title = _monthOnly
        ? context.l10n.datePickerSelectMonth
        : _isRange
        ? strings.dateRangePickerHelpText
        : strings.datePickerHelpText;
    final selection = switch ((start, end)) {
      (final DateTime from, final DateTime to) =>
        '${strings.formatShortDate(from)} – ${strings.formatShortDate(to)}',
      (final DateTime date, _) =>
        _monthOnly
            ? strings.formatMonthYear(date)
            : strings.formatFullDate(date),
      _ => _isRange ? strings.unspecifiedDateRange : title,
    };
    final input = _view == _View.input;
    final browsing = _view == _View.months || _view == _View.years;

    return Dialog(
      backgroundColor: CafeColors.paper,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ColoredBox(
                      color: colors.header,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          24,
                          18,
                          12,
                          22,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (start != null || _isRange)
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: colors.onHeader,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  Text(
                                    selection,
                                    style: TextStyle(
                                      color: colors.onHeader,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_monthOnly)
                              IconButton(
                                color: colors.onHeader,
                                tooltip: input
                                    ? strings.calendarModeButtonLabel
                                    : strings.inputDateModeButtonLabel,
                                onPressed: () => setState(() {
                                  _view = input ? _View.days : _View.input;
                                  _invalidRange = false;
                                }),
                                icon: Icon(
                                  input
                                      ? Icons.calendar_today_outlined
                                      : Icons.edit_outlined,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (input)
                            _buildInput(strings)
                          else ...[
                            _buildNavigation(strings, colors),
                            const SizedBox(height: 12),
                            if (browsing)
                              _buildChoices(strings, colors)
                            else
                              _buildDays(strings, colors),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 20, color: CafeColors.line),
                  if (browsing && !_monthOnly)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => setState(() => _view = _View.days),
                        child: Text(context.l10n.datePickerBackToCalendar),
                      ),
                    )
                  else
                    Wrap(
                      alignment:
                          !_monthOnly && !_isRange && widget.value != null
                          ? WrapAlignment.spaceBetween
                          : WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!_monthOnly && !_isRange && widget.value != null)
                          TextButton(
                            onPressed: () => Navigator.pop<CafeDateSelection>(
                              context,
                              (start: null, end: null),
                            ),
                            child: Text(context.l10n.datePickerClearDate),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(strings.cancelButtonLabel),
                            ),
                            const SizedBox(width: 6),
                            FilledButton(
                              onPressed:
                                  input ||
                                      (start != null &&
                                          (!_isRange || end != null))
                                  ? _submit
                                  : null,
                              child: Text(context.l10n.catalogApply),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(MaterialLocalizations strings, CafeSurfaces colors) {
    final locale = Localizations.localeOf(context).languageCode;
    final previous = DateUtils.addMonthsToMonthDate(_month, -1);
    final next = DateUtils.addMonthsToMonthDate(_month, 1);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      spacing: 4,
      children: [
        Wrap(
          spacing: 6,
          children: [
            _choice(
              DateFormat.MMMM(locale).format(_month),
              colors,
              selected: _view == _View.months,
              onPressed: () => setState(
                () => _view = _view == _View.months && !_monthOnly
                    ? _View.days
                    : _View.months,
              ),
              dropdown: true,
            ),
            _choice(
              strings.formatYear(_month),
              colors,
              selected: _view == _View.years,
              onPressed: () => setState(
                () => _view = _view == _View.years
                    ? (_monthOnly ? _View.months : _View.days)
                    : _View.years,
              ),
              dropdown: true,
            ),
          ],
        ),
        if (_view == _View.days)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: strings.previousMonthTooltip,
                onPressed: _monthAvailable(previous)
                    ? () => setState(() => _month = previous)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: strings.nextMonthTooltip,
                onPressed: _monthAvailable(next)
                    ? () => setState(() => _month = next)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }

  Widget _choice(
    String label,
    CafeSurfaces colors, {
    required bool selected,
    required VoidCallback? onPressed,
    bool dropdown = false,
  }) {
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          foregroundColor: selected && !dropdown
              ? colors.onButton
              : CafeColors.ink,
          backgroundColor: selected
              ? (dropdown
                    ? Color.alphaBlend(
                        colors.button.withValues(alpha: .13),
                        Colors.white,
                      )
                    : colors.button)
              : Colors.white,
          disabledBackgroundColor: CafeColors.key,
          disabledForegroundColor: CafeColors.inkMuted,
          side: const BorderSide(color: CafeColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: dropdown
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              )
            : Text(label),
      ),
    );
  }

  Widget _buildChoices(MaterialLocalizations strings, CafeSurfaces colors) {
    final months = _view == _View.months;
    final shortMonth = DateFormat.MMM(
      Localizations.localeOf(context).languageCode,
    );
    final dates = months
        ? List.generate(12, (index) => DateTime(_month.year, index + 1))
        : List.generate(
            _last.year - _first.year + 1,
            (index) => DateTime(_first.year + index),
          );
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final date in dates)
            SizedBox(
              width: (constraints.maxWidth - 16) / 3,
              child: _choice(
                months ? shortMonth.format(date) : strings.formatYear(date),
                colors,
                selected: months
                    ? (_monthOnly ? date == _start : date.month == _month.month)
                    : date.year == _month.year,
                onPressed: (!months || _monthAvailable(date))
                    ? () => setState(() {
                        final target = months
                            ? date
                            : DateTime(date.year, _month.month);
                        _month = DateUtils.addMonthsToMonthDate(
                          _bounded(target)!,
                          0,
                        );
                        if (_monthOnly && months) _start = date;
                        _view = _monthOnly ? _View.months : _View.days;
                      })
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDays(MaterialLocalizations strings, CafeSurfaces colors) {
    final offset = DateUtils.firstDayOffset(_month.year, _month.month, strings);
    final count = DateUtils.getDaysInMonth(_month.year, _month.month);
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    strings.narrowWeekdays[(strings.firstDayOfWeekIndex + i) %
                        7],
                    style: const TextStyle(
                      color: CafeColors.inkMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: SizedBox(
                    height: 43,
                    child: _buildDay(
                      row * 7 + column - offset + 1,
                      count,
                      strings,
                      colors,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget? _buildDay(
    int number,
    int count,
    MaterialLocalizations strings,
    CafeSurfaces colors,
  ) {
    if (number < 1 || number > count) return null;
    final day = DateTime(_month.year, _month.month, number);
    final enabled = !day.isBefore(_first) && !day.isAfter(_last);
    final first = day == _start;
    final last = day == _end;
    final selected = first || last;
    final today = day == _today;
    final inRange =
        _isRange &&
        _end != null &&
        !day.isBefore(_start!) &&
        !day.isAfter(_end!);
    final radius = BorderRadius.circular(10);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected || inRange,
      label: today
          ? '${strings.currentDateLabel}, ${strings.formatFullDate(day)}'
          : strings.formatFullDate(day),
      onTap: enabled ? () => _pickDay(day) : null,
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (inRange && _start != _end)
            PositionedDirectional(
              start: first ? null : 0,
              end: last ? null : 0,
              width: selected ? 24 : null,
              height: 34,
              child: ColoredBox(
                color: Color.alphaBlend(
                  colors.button.withValues(alpha: .15),
                  Colors.white,
                ),
              ),
            ),
          InkWell(
            borderRadius: radius,
            onTap: enabled ? () => _pickDay(day) : null,
            child: Center(
              child: Container(
                width: 38,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colors.button : null,
                  border: today && !selected
                      ? Border.all(color: colors.buttonInk)
                      : null,
                  borderRadius: radius,
                ),
                child: Text(
                  strings.formatDecimal(number),
                  style: TextStyle(
                    fontWeight: selected || today
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: selected
                        ? colors.onButton
                        : enabled
                        ? CafeColors.ink
                        : CafeColors.inkMuted.withValues(alpha: .65),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(MaterialLocalizations strings) {
    return Form(
      key: _form,
      onChanged: () {
        if (_invalidRange) setState(() => _invalidRange = false);
      },
      child: Column(
        children: [
          InputDatePickerFormField(
            firstDate: _first,
            lastDate: _last,
            initialDate: _start,
            autofocus: true,
            fieldLabelText: _isRange ? strings.dateRangeStartLabel : null,
            onDateSaved: (value) => _inputStart = value,
          ),
          if (_isRange) ...[
            const SizedBox(height: 12),
            InputDatePickerFormField(
              firstDate: _first,
              lastDate: _last,
              initialDate: _end,
              fieldLabelText: strings.dateRangeEndLabel,
              onDateSaved: (value) => _inputEnd = value,
            ),
          ],
          if (_invalidRange)
            Text(
              strings.invalidDateRangeLabel,
              style: const TextStyle(color: CafeColors.alert),
            ),
        ],
      ),
    );
  }
}
