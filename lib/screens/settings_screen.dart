import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../util/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ...existing code...
  final _baseCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _models = const [
    'gemma:7b-instruct',
    'codellama:7b-instruct',
  ];
  String _selectedModel = 'gemma:7b-instruct';

  @override
  void initState() {
    super.initState();
    () async {
      final (base, key, model) = await AppConfig.load();
      _baseCtrl.text = base;
      _keyCtrl.text = key;
      _selectedModel = _models.contains(model) ? model : 'gemma:7b-instruct';
      if (mounted) setState(() {});
    }();
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Local Model Endpoint',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _baseCtrl,
            decoration: const InputDecoration(
              labelText: 'Base URL (e.g. http://192.168.0.54:11434)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedModel,
            decoration: const InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(),
            ),
            items: _models
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (val) =>
                setState(() => _selectedModel = val ?? _selectedModel),
          ),
          const SizedBox(height: 20),
          const Text('Optional API Key',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(
              labelText: 'API Key (not needed for local Ollama)',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              await AppConfig.save(
                baseUrl: _baseCtrl.text.trim(),
                apiKey: _keyCtrl.text.trim(),
                model: _selectedModel,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved')),
              );
              // Pop with result so HomeScreen can reload model
              Future.delayed(const Duration(milliseconds: 400), () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, true);
                }
              });
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 20),
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return DropdownButtonFormField<ThemeMode>(
                value: themeProvider.themeMode,
                decoration: const InputDecoration(
                  labelText: 'Theme',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    themeProvider.setTheme(mode);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('Primary Color',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Wrap(
                spacing: 8,
                children: colorOptions.map((color) {
                  return GestureDetector(
                    onTap: () => themeProvider.setPrimaryColor(color),
                    child: CircleAvatar(
                      backgroundColor: color,
                      radius: 18,
                      child: themeProvider.primaryColor == color
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
