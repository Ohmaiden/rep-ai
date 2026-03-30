/// Tappable Number Widget
/// =======================
/// Shows a number with +/- buttons. Tap the number to type a value directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TappableNumber extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  final double fontSize;

  const TappableNumber({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10000,
    this.step = 1,
    this.fontSize = 24,
  });

  @override
  State<TappableNumber> createState() => _TappableNumberState();
}

class _TappableNumberState extends State<TappableNumber> {
  bool _editing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(TappableNumber old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _controller.text = '${widget.value}';
      _controller.selection = TextSelection(
          baseOffset: 0, extentOffset: _controller.text.length);
    });
  }

  void _finishEditing() {
    final parsed = int.tryParse(_controller.text) ?? widget.value;
    final clamped = parsed.clamp(widget.min, widget.max);
    widget.onChanged(clamped);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: widget.value > widget.min
              ? () => widget
                  .onChanged((widget.value - widget.step).clamp(widget.min, widget.max))
              : null,
          icon: const Icon(Icons.remove_circle_outline),
          iconSize: 28,
          color: const Color(0xFF2563EB),
        ),
        GestureDetector(
          onTap: _editing ? null : _startEditing,
          child: SizedBox(
            width: 56,
            child: _editing
                ? TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: UnderlineInputBorder(),
                    ),
                    onSubmitted: (_) => _finishEditing(),
                    onTapOutside: (_) => _finishEditing(),
                  )
                : Text(
                    '${widget.value}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        IconButton(
          onPressed: widget.value < widget.max
              ? () => widget
                  .onChanged((widget.value + widget.step).clamp(widget.min, widget.max))
              : null,
          icon: const Icon(Icons.add_circle_outline),
          iconSize: 28,
          color: const Color(0xFF2563EB),
        ),
      ],
    );
  }
}
