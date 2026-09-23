import 'package:flutter/material.dart';

import '../presentation/views/workbench/workbench_view.dart';
import 'board_theme.dart';

class ElectroBoardApp extends StatelessWidget {
  const ElectroBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElectroBoard',
      debugShowCheckedModeBanner: false,
      theme: BoardTheme.build(),
      home: const WorkbenchView(),
    );
  }
}
