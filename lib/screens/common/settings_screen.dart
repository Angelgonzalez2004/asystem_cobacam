import 'package:asystem_cobacam/providers/theme_provider.dart';
import 'package:asystem_cobacam/services/lock_service.dart';
import 'package:asystem_cobacam/services/session_service.dart';
import 'package:asystem_cobacam/screens/common/setup_pin_screen.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  List<Map<String, dynamic>> _activeSessions = [];
  String? _currentDeviceId;
  bool _isLoadingSessions = true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadSessions();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          // Si packageInfo devuelve valores vacíos (común en web si no se configura), usamos defaults
          final version =
              packageInfo.version.isEmpty ? '1.0.0' : packageInfo.version;
          final build =
              packageInfo.buildNumber.isEmpty ? '1' : packageInfo.buildNumber;
          _appVersion = 'v$version ($build)';
        });
      }
    } catch (e) {
      debugPrint("Error loading app version: $e");
      if (mounted) {
        setState(() {
          _appVersion = 'v1.0.0 (Oficial)';
        });
      }
    }
  }

  Future<void> _loadSessions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _currentDeviceId = await SessionService().getCurrentDeviceId();

      // Escuchar cambios en tiempo real en las sesiones
      FirebaseDatabase.instance
          .ref('users/${user.uid}/sessions')
          .onValue
          .listen((event) {
        if (!mounted) return;
        final data = event.snapshot.value;
        final List<Map<String, dynamic>> sessions = [];

        if (data != null && data is Map) {
          data.forEach((key, value) {
            final session = Map<String, dynamic>.from(value as Map);
            session['key'] = key;
            sessions.add(session);
          });
        }

        // Ordenar: Actual primero, luego por fecha reciente
        sessions.sort((a, b) {
          if (a['deviceId'] == _currentDeviceId) return -1;
          if (b['deviceId'] == _currentDeviceId) return 1;
          return (b['lastActive'] ?? 0).compareTo(a['lastActive'] ?? 0);
        });

        setState(() {
          _activeSessions = sessions;
          _isLoadingSessions = false;
        });
      });
    } catch (e) {
      debugPrint("Error loading sessions: $e");
      if (mounted) setState(() => _isLoadingSessions = false);
    }
  }

  Future<void> _revokeSession(String deviceKey, String modelName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión en este dispositivo?'),
        content: Text(
            'Se desconectará la cuenta en "$modelName". Si no reconoces este dispositivo, cambia tu contraseña inmediatamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SessionService().revokeSession(deviceKey);
        if (mounted)
          UiHelpers.showSnackBar(context, 'Dispositivo desconectado.');
      } catch (e) {
        if (mounted)
          UiHelpers.showSnackBar(context, 'Error al desconectar: $e',
              isError: true);
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restablecer Contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Se enviará un enlace a tu correo para cambiar la contraseña de forma segura.'),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Confirma tu correo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.trim().isEmpty) return;
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: emailController.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    UiHelpers.showSnackBar(context,
                        'Correo enviado. Revisa tu bandeja de entrada.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    UiHelpers.showSnackBar(context, 'Error: $e', isError: true);
                  }
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Cuenta?'),
        content: const Text(
          'Esta acción es irreversible. Se perderán todos tus datos locales y acceso. '
          'Si eres alumno, tu historial académico permanecerá en la base de datos de la escuela.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        UiHelpers.showSnackBar(context,
            'Por seguridad, contacta al administrador para eliminar tu cuenta.',
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lockService = Provider.of<LockService>(context);

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Ajustes del Sistema',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              elevation: 0,
              backgroundColor: theme.scaffoldBackgroundColor,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader(theme, 'Seguridad de la Cuenta'),

          _buildSettingsTile(
            context,
            icon: Icons.phonelink_lock_rounded,
            title: 'Bloqueo de Aplicación',
            subtitle: lockService.isPinSet
                ? 'PIN configurado'
                : 'Configurar PIN de bloqueo',
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SetupPinScreen()));
            },
          ),
          if (lockService.isPinSet)
            _buildSettingsTile(
              context,
              icon: Icons.lock_clock_rounded,
              title: 'Bloquear Ahora',
              subtitle: 'Bloquea la aplicación inmediatamente',
              onTap: () {
                lockService.lock();
              },
            ),

          // --- ACTIVE SESSIONS LIST ---
          if (_isLoadingSessions)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator()))
          else if (_activeSessions.isEmpty)
            _buildSettingsTile(context,
                icon: Icons.error_outline,
                title: 'No se pudo cargar la información')
          else
            ..._activeSessions.map((session) {
              final isCurrent = session['deviceId'] == _currentDeviceId;
              final lastActive = session['lastActive'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(session['lastActive'])
                  : DateTime.now();
              final formattedDate =
                  DateFormat('dd/MM HH:mm').format(lastActive);

              IconData deviceIcon = Icons.devices_other;
              if (session['platform'].toString().contains('Android'))
                deviceIcon = Icons.phone_android;
              if (session['platform'].toString().contains('iOS'))
                deviceIcon = Icons.phone_iphone;
              if (session['platform'].toString().contains('Web'))
                deviceIcon = Icons.web;
              if (session['platform'].toString().contains('Windows') ||
                  session['platform'].toString().contains('Mac'))
                deviceIcon = Icons.computer;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.colorScheme.primary.withOpacity(0.05)
                      : theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: isCurrent
                      ? Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3))
                      : null,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: ListTile(
                  leading: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(deviceIcon,
                            color: isCurrent ? Colors.white : Colors.grey),
                      ),
                      if (isCurrent)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: theme.cardColor, width: 2),
                            ),
                          ),
                        )
                    ],
                  ),
                  title: Text(session['model'] ?? 'Dispositivo',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrent
                            ? 'Este dispositivo • Activo ahora'
                            : 'Última vez: $formattedDate • ${session['platform']}',
                        style: TextStyle(
                            fontSize: 12,
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : Colors.grey),
                      ),
                      if (session['location'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                session['location'],
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: isCurrent
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red),
                          onPressed: () =>
                              _revokeSession(session['key'], session['model']),
                          tooltip: 'Desconectar dispositivo',
                        ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              );
            }),

          const SizedBox(height: 20),
          _buildSettingsTile(
            context,
            icon: Icons.lock_reset_rounded,
            title: 'Cambiar Contraseña',
            subtitle: 'Recibir enlace de recuperación',
            onTap: _showChangePasswordDialog,
          ),

          const SizedBox(height: 30),
          _buildSectionHeader(theme, 'Apariencia'),
          _buildSettingsTile(
            context,
            icon: Icons.dark_mode_outlined,
            title: 'Modo Oscuro',
            subtitle: 'Alternar entre tema claro y oscuro',
            trailing: Switch(
              value: themeProvider.themeMode == ThemeMode.dark,
              onChanged: (val) {
                themeProvider
                    .setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
              },
              activeColor: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(height: 30),
          _buildSectionHeader(theme, 'Información'),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'Versión de la App',
            subtitle: _appVersion.isEmpty ? 'Cargando...' : _appVersion,
          ),

          const SizedBox(height: 40),
          OutlinedButton.icon(
            onPressed: _handleDeleteAccount,
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Solicitar Eliminación de Cuenta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: TextStyle(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)))
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Colors.grey)
                : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
