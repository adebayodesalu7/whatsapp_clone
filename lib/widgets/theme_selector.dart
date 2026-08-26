import 'package:flutter/material.dart';

class ThemeSelector extends StatelessWidget {
  final String screenName;

  const ThemeSelector({super.key, required this.screenName});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.palette),
      onPressed: () {
        // Future: Show theme picker dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Theme settings for $screenName')),
        );
      },
    );
  }
}
