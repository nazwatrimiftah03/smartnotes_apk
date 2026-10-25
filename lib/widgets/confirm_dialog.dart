import 'package:flutter/material.dart';

Future<bool> showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      String confirmLabel = 'Hapus',
    }) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return ok == true;
}