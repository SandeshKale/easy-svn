import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/repo_list/repo_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: EasySvnApp()));
}

class EasySvnApp extends StatelessWidget {
  const EasySvnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'easy-svn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RepoListScreen(),
    );
  }
}
