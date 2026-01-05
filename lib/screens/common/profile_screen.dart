import 'dart:io';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  DatabaseReference? _userRef;

  String _userName = 'Cargando...';
  String _userEmail = 'Cargando...';
  String _userRole = 'Cargando...';
  String? _profileImageUrl;
  bool _isLoading = true;
  XFile? _newProfileImage;

  @override
  void initState() {
    super.initState();
    final user = _currentUser;
    if (user != null) {
      _userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      _loadUserData();
    } else {
      setState(() {
        _isLoading = false;
        _userName = 'Error: No se encontró usuario';
      });
    }
  }

  Future<void> _loadUserData() async {
    final userRef = _userRef;
    if (userRef == null) return;

    try {
      final snapshot = await userRef.get();
      if (snapshot.exists) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _userName = userData['fullName'] ?? 'Nombre no disponible';
          _userEmail = _currentUser?.email ?? 'Email no disponible';
          _userRole = userData['role'] ?? 'Rol no disponible';
          _profileImageUrl = userData['profileImageUrl'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _userName = 'No se encontraron datos de perfil.';
          _userEmail = _currentUser?.email ?? 'Email no disponible';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _userName = 'Error al cargar datos';
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = _currentUser;
    final userRef = _userRef;
    if (user == null || userRef == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image == null) return;

    setState(() {
      _isLoading = true;
      _newProfileImage = image; // Show local image immediately
    });

    try {
      final storageRef =
          FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}');
      final uploadTask = await storageRef.putFile(File(image.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await userRef.update({'profileImageUrl': downloadUrl});
      setState(() {
        _profileImageUrl = downloadUrl;
        _newProfileImage = null; // Clear local image after upload
      });
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Foto de perfil actualizada.');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al subir la foto.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProfilePicture() async {
    final userRef = _userRef;
    if (_profileImageUrl == null || userRef == null) return;

    final bool confirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: 'Eliminar Foto',
      content: '¿Estás seguro de que quieres eliminar tu foto de perfil?',
      confirmText: 'Eliminar',
      isDestructive: true,
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseStorage.instance.refFromURL(_profileImageUrl!).delete();
      await userRef.update({'profileImageUrl': null});
      setState(() {
        _profileImageUrl = null;
        _newProfileImage = null;
      });
      if (mounted) UiHelpers.showSnackBar(context, 'Foto de perfil eliminada.');
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al eliminar la foto.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final imageToShow = _newProfileImage != null
        ? FileImage(File(_newProfileImage!.path))
        : (_profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null)
            as ImageProvider?;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: FadeInUp(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildProfileHeader(theme, imageToShow),
                        const SizedBox(height: 40),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: isDark
                                ? BorderSide.none
                                : BorderSide(color: Colors.grey.shade100),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildInfoTile(theme, Icons.person_outline,
                                    'Nombre Completo', _userName),
                                _buildDivider(),
                                _buildInfoTile(theme, Icons.email_outlined,
                                    'Correo Electrónico', _userEmail),
                                _buildDivider(),
                                _buildInfoTile(
                                    theme,
                                    Icons.verified_user_outlined,
                                    'Rol del Sistema',
                                    _userRole),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          '© 2026 Colegio de Bachilleres del Estado de Campeche',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, ImageProvider? image) {
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
                radius: 70,
                backgroundImage: image,
                backgroundColor: theme.colorScheme.surface,
                child: image == null
                    ? Icon(Icons.person,
                        size: 70,
                        color: theme.colorScheme.primary.withValues(alpha: 0.3))
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
                  icon: const Icon(Icons.camera_alt,
                      size: 20, color: Colors.white),
                  onPressed: _pickAndUploadImage,
                ),
              ),
            ),
          ],
        ),
        if (_profileImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton.icon(
              onPressed: _deleteProfilePicture,
              icon: Icon(Icons.delete_outline,
                  size: 16, color: theme.colorScheme.error),
              label: Text('Eliminar foto',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoTile(
      ThemeData theme, IconData icon, String label, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(label,
          style: theme.textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      subtitle: Text(value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
    );
  }
}
