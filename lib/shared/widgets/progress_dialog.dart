import 'dart:async';

import 'package:flutter/material.dart';
import 'package:git2_bridge/git2_bridge.dart';

/// Runs [operation] (a clone/pull/push call that reports progress via
/// its `onProgress` callback) behind a non-dismissible progress
/// dialog, and maps [GitBridgeException] to a friendly error dialog on
/// failure (plan §4 W9: "Map libgit2 error codes to user-friendly
/// messages").
Future<bool> runWithProgressDialog({
  required BuildContext context,
  required String title,
  required Future<void> Function(GbProgressCallback onProgress) operation,
}) async {
  final progress = ValueNotifier<GbProgress?>(null);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: ValueListenableBuilder<GbProgress?>(
            valueListenable: progress,
            builder: (context, value, _) {
              final pct = value?.percent;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: (pct != null && pct >= 0) ? pct / 100 : null,
                  ),
                  const SizedBox(height: 12),
                  Text(value?.message ?? 'Starting…'),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  String? errorMessage;
  try {
    await operation((p) => progress.value = p);
  } on GitBridgeException catch (e) {
    errorMessage = e.userMessage;
  } on Exception catch (e) {
    errorMessage = 'Unexpected error: $e';
  }

  if (!context.mounted) return errorMessage == null;
  Navigator.of(context, rootNavigator: true).pop();

  if (errorMessage != null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Something went wrong'),
        content: Text(errorMessage!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }
  return true;
}

/// Runs [operation] (e.g. a zip import) behind a non-dismissible,
/// indeterminate loading dialog, and maps [GitBridgeException] (and any
/// other exception) to a friendly error dialog on failure. Returns the
/// operation's result, or null if it failed.
Future<T?> runWithLoadingDialog<T>({
  required BuildContext context,
  required String title,
  required Future<T> Function() operation,
}) async {
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(title)),
            ],
          ),
        ),
      ),
    ),
  );

  T? result;
  String? errorMessage;
  try {
    result = await operation();
  } on GitBridgeException catch (e) {
    errorMessage = e.userMessage;
  } on Exception catch (e) {
    errorMessage = 'Unexpected error: $e';
  }

  if (!context.mounted) return result;
  Navigator.of(context, rootNavigator: true).pop();

  if (errorMessage != null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Something went wrong'),
        content: Text(errorMessage!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return null;
  }
  return result;
}
