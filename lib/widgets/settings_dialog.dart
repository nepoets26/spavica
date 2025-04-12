import 'package:flutter/material.dart';
import 'dart:async';

import '../services/user_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final UserService _userService = UserService();
  static const List<double> _speedOptions = [
    0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75,
    0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15, 1.2, 1.25, 1.3,
    1.35, 1.4, 1.45, 1.5, 1.55, 1.6, 1.65, 1.7, 1.75, 1.8, 1.85,
    1.9, 1.95, 2.0
  ];

  double _selectedSpeed = 1.0;
  double _initialSpeed = 1.0;

  String _selectedReviewOrder = 'IntervalAscending';
  String _initialReviewOrder = 'IntervalAscending';

  String _selectedTheme = 'Dark';
  String _initialTheme = 'Dark';

  final Map<String, String> _reviewOrderOptions = {
    'IntervalAscending': 'Interval (Ascending)',
    'OverdueDescending': 'Overdue (Descending)',
  };

  final Map<String, String> _themeOptions = {
    'Dark': 'Dark',
    'LightPurplePink': 'Light (Purple and Pink)',
    'LightBlueGreen': 'Light (Blue and Green)',
  };

  StreamSubscription? _preferencesSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  @override
  void dispose() {
    _preferencesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    _preferencesSubscription = _userService.getUserPreferences().listen((preferences) {
      if (mounted) {
        setState(() {
          _selectedSpeed = preferences.speedAddCard;
          _initialSpeed = preferences.speedAddCard;
          _selectedReviewOrder = preferences.reviewOrder;
          _initialReviewOrder = preferences.reviewOrder;
          _selectedTheme = preferences.theme;
          _initialTheme = preferences.theme;
        });
      }
    });
  }

  Future<void> _saveSettings() async {
    try {
      await _userService.updateUserPreferences(
        speedAddCard: _selectedSpeed,
        reviewOrder: _selectedReviewOrder,
        theme: _selectedTheme,
      );
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Default speed for new cards:'),
          const SizedBox(height: 8),
          DropdownButtonFormField<double>(
            value: _selectedSpeed,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
            items: _speedOptions.map((speed) {
              return DropdownMenuItem<double>(
                value: speed,
                child: Text(speed.toStringAsFixed(2) + 'x'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedSpeed = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          const Text('Review Order:'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedReviewOrder,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
            items: _reviewOrderOptions.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedReviewOrder = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          const Text('Theme:'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTheme,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
            items: _themeOptions.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedTheme = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saveSettings,
          child: const Text('Save'),
        ),
      ],
    );
  }
}