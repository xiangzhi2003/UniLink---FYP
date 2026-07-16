import 'package:flutter/material.dart';

const _reasons = [
  'Spam',
  'Scam or fraud',
  'Inappropriate content',
  'Prohibited item',
  'Other',
];

/// Preset-reason chooser for reporting a listing or user. Deliberately has
/// NO free-text field: a TextField inside a modal dialog freezes this
/// project's test device (see the reply-to-review incident) -- fixed
/// choices sidestep the keyboard entirely. Returns the chosen reason, or
/// null if dismissed.
Future<String?> showReportReasonDialog(BuildContext context, {required String what}) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('Report $what'),
      children: [
        for (final reason in _reasons)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, reason),
            child: Text(reason),
          ),
      ],
    ),
  );
}
