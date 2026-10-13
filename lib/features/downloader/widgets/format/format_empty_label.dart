import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';

class FormatEmptyLabel extends StatelessWidget {
  final String label;
  const FormatEmptyLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: c.textTertiary, fontSize: 14),
        ),
      ),
    );
  }
}
