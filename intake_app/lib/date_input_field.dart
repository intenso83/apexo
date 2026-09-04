import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool isValidIntakeDate(String value) {
  final match = RegExp(
    r'^(0[1-9]|[12][0-9]|3[01])/(0[1-9]|1[0-2])/([0-9]{4})$',
  ).firstMatch(value);
  if (match == null) return false;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

class DateInputField extends StatefulWidget {
  const DateInputField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onChanged;

  @override
  State<DateInputField> createState() => _DateInputFieldState();
}

class _DateInputFieldState extends State<DateInputField> {
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  final _dayFocus = FocusNode();
  final _monthFocus = FocusNode();
  final _yearFocus = FocusNode();
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_readCombinedValue);
    _readCombinedValue();
  }

  @override
  void didUpdateWidget(covariant DateInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_readCombinedValue);
      widget.controller.addListener(_readCombinedValue);
      _readCombinedValue();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_readCombinedValue);
    _day.dispose();
    _month.dispose();
    _year.dispose();
    _dayFocus.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  void _readCombinedValue() {
    if (_updating) return;
    final parts = widget.controller.text.split('/');
    _setText(_day, parts.isNotEmpty ? parts[0] : '');
    _setText(_month, parts.length > 1 ? parts[1] : '');
    _setText(_year, parts.length > 2 ? parts[2] : '');
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _writeCombinedValue() {
    _updating = true;
    widget.controller.text = '${_day.text}/${_month.text}/${_year.text}';
    _updating = false;
    widget.onChanged?.call();
  }

  void _dayChanged(String value) {
    var normalized = value;
    final number = int.tryParse(value);
    if (value.length == 1 && number != null && number > 3) {
      normalized = '0$value';
      _setText(_day, normalized);
    }
    _writeCombinedValue();
    if (normalized.length == 2) _monthFocus.requestFocus();
  }

  void _monthChanged(String value) {
    var normalized = value;
    final number = int.tryParse(value);
    if (value.length == 1 && number != null && number > 1) {
      normalized = '0$value';
      _setText(_month, normalized);
    }
    _writeCombinedValue();
    if (normalized.length == 2) _yearFocus.requestFocus();
  }

  void _finishDay() {
    if (_day.text.length == 1) _setText(_day, '0${_day.text}');
    _writeCombinedValue();
    _monthFocus.requestFocus();
  }

  void _finishMonth() {
    if (_month.text.length == 1) _setText(_month, '0${_month.text}');
    _writeCombinedValue();
    _yearFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 430,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '${widget.label} *',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _segment(
                  key: const ValueKey('date_day'),
                  controller: _day,
                  focusNode: _dayFocus,
                  hint: 'DD',
                  length: 2,
                  action: TextInputAction.next,
                  onChanged: _dayChanged,
                  onComplete: _finishDay,
                ),
              ),
              const _DateSeparator(),
              Expanded(
                flex: 2,
                child: _segment(
                  key: const ValueKey('date_month'),
                  controller: _month,
                  focusNode: _monthFocus,
                  hint: 'MM',
                  length: 2,
                  action: TextInputAction.next,
                  onChanged: _monthChanged,
                  onComplete: _finishMonth,
                ),
              ),
              const _DateSeparator(),
              Expanded(
                flex: 3,
                child: _segment(
                  key: const ValueKey('date_year'),
                  controller: _year,
                  focusNode: _yearFocus,
                  hint: 'YYYY',
                  length: 4,
                  action: TextInputAction.done,
                  onChanged: (_) => _writeCombinedValue(),
                  onComplete: () {
                    _writeCombinedValue();
                    _yearFocus.unfocus();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required int length,
    required TextInputAction action,
    required ValueChanged<String> onChanged,
    required VoidCallback onComplete,
  }) {
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: action,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      ),
      onChanged: onChanged,
      onEditingComplete: onComplete,
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 7),
      child: Text(
        '/',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
      ),
    );
  }
}
