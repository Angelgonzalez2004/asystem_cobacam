import 'package:asystem_cobacam/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  String _selectedLanguage = 'es';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _emailNotifications = prefs.getBool('emailNotifications') ?? true;
        _pushNotifications = prefs.getBool('pushNotifications') ?? true;
        _selectedLanguage = prefs.getString('language') ?? 'es';
      });
    }
  }

  Future<void> _setEmailNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailNotifications = value;
    });
    await prefs.setBool('emailNotifications', value);
  }

  Future<void> _setPushNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = value;
    });
    await prefs.setBool('pushNotifications', value);
  }

  Future<void> _setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = lang;
    });
    await prefs.setString('language', lang);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Tema de la aplicación'),
                trailing: DropdownButton<ThemeMode>(
                  value: themeProvider.themeMode,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Sistema'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Claro'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Oscuro'),
                    ),
                  ],
                  onChanged: (ThemeMode? mode) {
                    if (mode != null) {
                      themeProvider.setThemeMode(mode);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notificaciones por Email'),
                    value: _emailNotifications,
                    onChanged: _setEmailNotifications,
                  ),
                  SwitchListTile(
                    title: const Text('Notificaciones Push'),
                    value: _pushNotifications,
                    onChanged: _setPushNotifications,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Idioma'),
                trailing: DropdownButton<String>(
                  value: _selectedLanguage,
                  items: const [
                    DropdownMenuItem(
                      value: 'es',
                      child: Text('Español'),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text('Inglés'),
                    ),
                  ],
                  onChanged: (String? lang) {
                    if (lang != null) {
                      _setLanguage(lang);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: ListTile(
                leading: const Icon(Icons.cleaning_services),
                title: const Text('Limpiar Caché'),
                onTap: () async {
                  if (!mounted) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Limpiar Caché'),
                      content: const Text(
                          '¿Estás seguro de que quieres limpiar la caché de la aplicación?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    // Aquí iría la lógica real de limpieza
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Caché limpiada con éxito.'),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
