import 'dart:io';
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
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image == null) return;

    setState(() {
      _isLoading = true;
      _newProfileImage = image; // Show local image immediately
    });

    try {
      final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}');
      final uploadTask = await storageRef.putFile(File(image.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await userRef.update({'profileImageUrl': downloadUrl});
      setState(() {
        _profileImageUrl = downloadUrl;
        _newProfileImage = null; // Clear local image after upload
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProfilePicture() async {
     final userRef = _userRef;
     if (_profileImageUrl == null || userRef == null) return;

     final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar Foto'),
          content: const Text('¿Estás seguro de que quieres eliminar tu foto de perfil? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Delete from storage
      await FirebaseStorage.instance.refFromURL(_profileImageUrl!).delete();
      // Delete from database
      await userRef.update({'profileImageUrl': null});
      setState(() {
        _profileImageUrl = null;
        _newProfileImage = null;
      });
    } catch (e) {
      // Handle error, e.g., file not found
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageToShow = _newProfileImage != null
        ? FileImage(File(_newProfileImage!.path))
        : (_profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null) as ImageProvider?;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: imageToShow,
                        backgroundColor: theme.colorScheme.surface,
                        child: imageToShow == null ? Icon(Icons.person, size: 60, color: Colors.grey.shade400) : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.photo_camera, size: 18),
                            label: const Text('Cambiar Foto'),
                            onPressed: _pickAndUploadImage,
                          ),
                          if (_profileImageUrl != null || _newProfileImage != null)
                          TextButton.icon(
                            icon: Icon(Icons.delete, size: 18, color: theme.colorScheme.error),
                            label: Text('Eliminar Foto', style: TextStyle(color: theme.colorScheme.error)),
                            onPressed: _deleteProfilePicture,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.person_pin_rounded),
                        title: Text(_userName, style: theme.textTheme.titleLarge),
                        subtitle: const Text('Nombre Completo'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: Text(_userEmail),
                        subtitle: const Text('Correo Electrónico'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.work_outline),
                        title: Text(_userRole),
                        subtitle: const Text('Rol de Usuario'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
