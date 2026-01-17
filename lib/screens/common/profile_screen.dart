import 'dart:io';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  final bool isEmbedded;
  const ProfileScreen({super.key, this.isEmbedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseReference _userRef = FirebaseDatabase.instance.ref('users');

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  // Data Containers
  Map<String, dynamic> _userData = {};
  XFile? _newProfileImage;

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) return;
    try {
      final snapshot = await _userRef.child(_currentUser.uid).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _userData = data;
          _nameController.text = data['fullName'] ?? '';
          _phoneController.text =
              data['phone'] ?? ''; // Assuming phone field exists or adding it
          _locationController.text = data['location'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newProfileImage = image;
      });
      // Optionally save immediately or wait for "Save" button.
      // For UX, let's wait for explicit save to avoid accidental uploads,
      // but showing preview is key.
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;
    setState(() => _isSaving = true);

    try {
      String? imageUrl = _userData['profileImageUrl'];

      // 1. Upload new image if selected
      if (_newProfileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${_currentUser.uid}');

        if (kIsWeb) {
          final bytes = await _newProfileImage!.readAsBytes();
          await storageRef.putData(
              bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          await storageRef.putFile(File(_newProfileImage!.path));
        }
        imageUrl = await storageRef.getDownloadURL();
      }

      // 2. Update Database
      final updateData = {
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'profileImageUrl': imageUrl,
      };

      await _userRef.child(_currentUser.uid).update(updateData);

      // 3. Update Local State
      setState(() {
        _userData.addAll(updateData);
        _isEditing = false;
        _newProfileImage = null;
      });

      if (mounted) {
        UiHelpers.showSnackBar(context, '¡Perfil actualizado con éxito!');
        // Opcional: Podrías forzar un refresh del Drawer aquí si usas un Provider
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Error al actualizar: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
          body: Center(
              child:
                  CircularProgressIndicator(color: theme.colorScheme.primary)));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header Expansible
          SliverAppBar(
            expandedHeight: 280.0,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            elevation: 0,
            automaticallyImplyLeading: !widget.isEmbedded,
            leading: widget.isEmbedded
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  onPressed: () => setState(() => _isEditing = true),
                  tooltip: 'Editar Perfil',
                )
              else
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _newProfileImage = null;
                      // Reset fields
                      _nameController.text = _userData['fullName'] ?? '';
                      _phoneController.text = _userData['phone'] ?? '';
                      _locationController.text = _userData['location'] ?? '';
                    });
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Fondo decorativo
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                    ),
                  ),
                  // Imagen y Nombre
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _getProfileImage(),
                                child: _getProfileImage() == null
                                    ? Icon(Icons.person,
                                        size: 60, color: Colors.grey[400])
                                    : null,
                              ),
                            ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userData['fullName'] ?? 'Usuario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          _userData['role'] ?? 'Rol Desconocido',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido del Formulario
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              transform:
                  Matrix4.translationValues(0, -20, 0), // Solape negativo
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(theme, 'Información Personal'),
                  const SizedBox(height: 16),
                  _buildProfileField(
                    label: 'Nombre Completo',
                    controller: _nameController,
                    icon: Icons.person_outline,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileField(
                    label: 'Teléfono de Contacto',
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    enabled: _isEditing,
                    inputType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileField(
                    label: 'Lugar de Residencia',
                    controller: _locationController,
                    icon: Icons.location_on_outlined,
                    enabled: _isEditing,
                  ),

                  const SizedBox(height: 32),
                  _buildSectionHeader(theme, 'Datos Institucionales'),
                  const SizedBox(height: 16),

                  // Read-only fields
                  _buildReadOnlyField(
                    label: 'Correo Institucional',
                    value: _userData['email'] ?? '',
                    icon: Icons.email_outlined,
                    theme: theme,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          label: 'Rol',
                          value: _userData['role'] ?? '',
                          icon: Icons.badge_outlined,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildReadOnlyField(
                          label: 'Plantel',
                          value: _userData['campus'] ?? 'N/A',
                          icon: Icons.school_outlined,
                          theme: theme,
                        ),
                      ),
                    ],
                  ),

                  // Espacio extra si es alumno para datos como matrícula
                  if (_userData['role'] == 'Alumno') ...[
                    const SizedBox(height: 16),
                    _buildReadOnlyField(
                      label: 'Fecha de Nacimiento',
                      value: _userData['dateOfBirth'] ?? 'N/A',
                      icon: Icons.cake_outlined,
                      theme: theme,
                    ),
                  ],

                  const SizedBox(height: 40),

                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('GUARDAR CAMBIOS',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0)),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_newProfileImage != null) {
      if (kIsWeb) {
        return NetworkImage(_newProfileImage!.path);
      }
      return FileImage(File(_newProfileImage!.path));
    }
    if (_userData['profileImageUrl'] != null &&
        _userData['profileImageUrl'].isNotEmpty) {
      return NetworkImage(_userData['profileImageUrl']);
    }
    return null;
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        Divider(
            color: theme.colorScheme.primary.withOpacity(0.2), thickness: 1),
      ],
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = false,
    TextInputType inputType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
            : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: enabled
            ? Border.all(color: theme.colorScheme.primary.withOpacity(0.5))
            : Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: inputType,
        style: TextStyle(
            color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: Icon(icon,
              color: enabled ? theme.colorScheme.primary : Colors.grey),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16, color: theme.colorScheme.primary.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? 'N/A' : value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
