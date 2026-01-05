import 'dart:io';
import 'package:asystem_cobacam/screens/welcome_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  DatabaseReference? _userRef;

  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _isEditing = false;
  XFile? _newProfileImage;

  // Controllers for editing
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _userRef = FirebaseDatabase.instance.ref('users/${_currentUser.uid}');
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    if (_userRef == null) return;
    try {
      final snapshot = await _userRef!.get();
      if (snapshot.exists) {
        setState(() {
          _userData = Map<String, dynamic>.from(snapshot.value as Map);
          _nameController.text = _userData['fullName'] ?? '';
          _locationController.text = _userData['location'] ?? '';
          _phoneController.text = _userData['phone'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al cargar perfil', isError: true);
    }
  }

  Future<void> _saveProfileChanges() async {
    if (_userRef == null) return;
    setState(() => _isLoading = true);
    try {
      await _userRef!.update({
        'fullName': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      await _loadUserData();
      setState(() => _isEditing = false);
      if (mounted) UiHelpers.showSnackBar(context, 'Perfil actualizado correctamente');
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al guardar cambios', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_currentUser == null || _userRef == null) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() {
      _isLoading = true;
      _newProfileImage = image;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${_currentUser.uid}');
      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();
      await _userRef!.update({'profileImageUrl': downloadUrl});
      await _loadUserData();
      if (mounted) UiHelpers.showSnackBar(context, 'Foto de perfil actualizada');
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al subir foto', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final bool confirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: 'Eliminar Cuenta',
      content: 'Esta acción es irreversible. Se borrarán todos tus datos. ¿Estás seguro?',
      confirmText: 'Sí, eliminar',
      cancelText: 'Cancelar',
      isDestructive: true,
    );

    if (!confirmed || _currentUser == null || !mounted) return;

    // Prompt for password for re-authentication
    String? password = await showDialog<String>(
      context: context,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: const Text('Confirmar Contraseña'),
          content: TextField(
            obscureText: true,
            onChanged: (val) => input = val,
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, input), child: const Text('Confirmar')),
          ],
        );
      },
    );

    if (password == null || password.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Re-authenticate
      AuthCredential credential = EmailAuthProvider.credential(email: _currentUser.email ?? '', password: password);
      await _currentUser.reauthenticateWithCredential(credential);

      // Delete Profile Image
      if (_userData['profileImageUrl'] != null) {
        try {
          await FirebaseStorage.instance.refFromURL(_userData['profileImageUrl']).delete();
        } catch (_) {
          // Ignore if image doesn't exist
        }
      }

      // Delete User Data
      await _userRef!.remove();

      // Delete Auth Account
      await _currentUser.delete();

      if (mounted) {
        UiHelpers.showSnackBar(context, 'Cuenta eliminada exitosamente.');
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false);
      }
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al eliminar cuenta: ${e.toString()}', isError: true);
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final String creationDate = _currentUser?.metadata.creationTime != null 
        ? DateFormat('MMMM yyyy', 'es_MX').format(_currentUser!.metadata.creationTime!) 
        : 'Desconocido';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: FadeInUp(
                    child: Column(
                      children: [
                        _buildHeader(theme, isDark),
                        const SizedBox(height: 32),
                        _buildMainStats(theme, creationDate),
                        const SizedBox(height: 24),
                        _buildInfoCard(theme, isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final profileUrl = _userData['profileImageUrl'];
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary, width: 3),
              ),
              child: CircleAvatar(
                radius: 65,
                backgroundColor: theme.colorScheme.surface,
                backgroundImage: _newProfileImage != null
                    ? FileImage(File(_newProfileImage!.path))
                    : (profileUrl != null ? NetworkImage(profileUrl) : null) as ImageProvider?,
                child: (profileUrl == null && _newProfileImage == null)
                    ? Icon(Icons.person, size: 60, color: theme.colorScheme.primary.withValues(alpha: 0.3))
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                radius: 20,
                child: IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                  onPressed: _pickAndUploadImage,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _userData['fullName'] ?? 'Usuario Cobacam',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          _userData['role'] ?? 'Rol no definido',
          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildMainStats(ThemeData theme, String creationDate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem(theme, 'Plantel', _userData['campus'] ?? 'N/A'),
        _buildStatDivider(),
        _buildStatItem(theme, 'Desde', creationDate),
      ],
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  Widget _buildInfoCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark ? BorderSide.none : BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Información Personal', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(_isEditing ? Icons.check_circle : Icons.edit_note, color: theme.colorScheme.primary),
                  onPressed: () {
                    if (_isEditing) {
                      _saveProfileChanges();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                )
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            _buildEditableTile(Icons.person_outline, 'Nombre Completo', _nameController, _isEditing),
            _buildEditableTile(Icons.location_on_outlined, 'Ubicación', _locationController, _isEditing),
            _buildEditableTile(Icons.phone_outlined, 'Teléfono', _phoneController, _isEditing),
            _buildReadOnlyTile(Icons.email_outlined, 'Correo Electrónico', _currentUser?.email ?? 'N/A'),
            _buildReadOnlyTile(Icons.cake_outlined, 'Fecha de Nacimiento', _userData['dateOfBirth'] ?? 'No registrada'),
            const SizedBox(height: 32),
            Center(
              child: TextButton.icon(
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('Eliminar Cuenta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.red.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEditableTile(IconData icon, String label, TextEditingController controller, bool isEditing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: isEditing
                ? TextFormField(
                    controller: controller,
                    decoration: InputDecoration(labelText: label, contentPadding: EdgeInsets.zero, isDense: true),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(controller.text.isEmpty ? 'No registrado' : controller.text, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}