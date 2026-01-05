import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _officeController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _dobController = TextEditingController();

  String _userRole = 'Cargando...';
  String _userCampus = 'Cargando...';
  String? _userPhotoUrl;
  File? _imageFile;
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot =
          await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (snapshot.exists && snapshot.value != null) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          setState(() {
            _nameController.text = userData['fullName'] ?? '';
            _emailController.text = user.email ?? '';
            _userRole = userData['role'] ?? 'N/A';
            _userCampus = userData['campus'] ?? 'N/A';
            _userPhotoUrl = userData['profileImageUrl'];
            _phoneController.text = userData['phone'] ?? '';
            _officeController.text = userData['office'] ?? '';
            _bioController.text = userData['bio'] ?? '';
            _locationController.text = userData['location'] ?? '';
            _dobController.text = userData['dateOfBirth'] ?? '';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar perfil: ${e.toString()}')));
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dobController.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd').parse(_dobController.text)
          : DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<String> _uploadImageToStorage(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    final storageRef =
        FirebaseStorage.instance.ref().child('profile_pictures/${user!.uid}');
    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask.whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await _showConfirmationDialog(
        'Guardar Cambios', '¿Estás seguro de que quieres guardar los cambios?');
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        String? photoUrl = _userPhotoUrl;
        if (_imageFile != null) {
          photoUrl = await _uploadImageToStorage(_imageFile!);
        }

        if (user.email != _emailController.text) {
          await user.verifyBeforeUpdateEmail(_emailController.text);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Se ha enviado un correo de verificación a ${_emailController.text}. Por favor, verifica tu nuevo correo para completar el cambio.'),
              duration: const Duration(seconds: 5),
            ));
          }
        }

        await FirebaseDatabase.instance.ref('users/${user.uid}').update({
          'fullName': _nameController.text,
          'phone': _phoneController.text,
          'office': _officeController.text,
          'bio': _bioController.text,
          'location': _locationController.text,
          'dateOfBirth': _dobController.text,
          'profileImageUrl': photoUrl,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Perfil actualizado con éxito')));
        }

        setState(() {
          _isEditing = false;
          _userPhotoUrl = photoUrl;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error al actualizar el perfil: ${e.toString()}')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deactivateAccount() async {
    final confirmed = await _showConfirmationDialog('Desactivar Cuenta',
        'Esta acción es irreversible. ¿Estás seguro de que quieres desactivar tu cuenta?',
        isDestructive: true);
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<bool?> _showConfirmationDialog(String title, String content,
      {bool isDestructive = false}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(isDestructive ? 'Desactivar' : 'Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProfileImage() async {
    final confirmed = await _showConfirmationDialog('Eliminar Foto',
        '¿Estás seguro de que quieres eliminar tu foto de perfil?',
        isDestructive: true);
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _userPhotoUrl != null) {
      try {
        // Delete from Firebase Storage
        final storageRef = FirebaseStorage.instance.refFromURL(_userPhotoUrl!);
        await storageRef.delete();

        // Update Firebase Realtime Database
        await FirebaseDatabase.instance.ref('users/${user.uid}').update({
          'profileImageUrl': null,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Foto de perfil eliminada con éxito')));
        }

        setState(() {
          _userPhotoUrl = null;
          _imageFile = null;
          _isEditing = true; // Stay in editing mode after deletion
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error al eliminar la foto: ${e.toString()}')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No hay foto de perfil para eliminar.')));
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _viewFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_isEditing) {
            _saveProfile();
          } else {
            setState(() => _isEditing = true);
          }
        },
        child: Icon(_isEditing ? Icons.save : Icons.edit),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Card(
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (_userPhotoUrl != null ||
                                        _imageFile != null) {
                                      _viewFullScreenImage(context,
                                          _imageFile?.path ?? _userPhotoUrl!);
                                    } else if (_isEditing) {
                                      _pickImage();
                                    }
                                  },
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundImage: _imageFile != null
                                        ? FileImage(_imageFile!)
                                        : (_userPhotoUrl != null
                                            ? NetworkImage(_userPhotoUrl!)
                                            : null) as ImageProvider?,
                                    child: _imageFile == null &&
                                            _userPhotoUrl == null
                                        ? const Icon(Icons.person, size: 50)
                                        : null,
                                  ),
                                ),
                                if (_isEditing &&
                                    (_userPhotoUrl != null ||
                                        _imageFile != null))
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.red,
                                      radius: 18,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.white, size: 20),
                                        onPressed: _deleteProfileImage,
                                      ),
                                    ),
                                  ),
                                if (_isEditing &&
                                    _userPhotoUrl == null &&
                                    _imageFile == null)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      radius: 18,
                                      child: IconButton(
                                        icon: const Icon(Icons.add_a_photo,
                                            color: Colors.white, size: 20),
                                        onPressed: _pickImage,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: _nameController,
                                decoration:
                                    const InputDecoration(labelText: 'Nombre'),
                                enabled: _isEditing,
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: _emailController,
                                decoration:
                                    const InputDecoration(labelText: 'Email'),
                                enabled: _isEditing,
                                validator: (v) => v!.isEmpty || !v.contains('@')
                                    ? 'Email inválido'
                                    : null),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: _dobController,
                                decoration: const InputDecoration(
                                    labelText: 'Fecha de Nacimiento'),
                                enabled: _isEditing,
                                readOnly: true,
                                onTap: _isEditing ? _selectDate : null),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                    labelText: 'Teléfono'),
                                enabled: _isEditing),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: _officeController,
                                decoration:
                                    const InputDecoration(labelText: 'Oficina'),
                                enabled: _isEditing),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: _locationController,
                                decoration: const InputDecoration(
                                    labelText: 'Ubicación'),
                                enabled: _isEditing),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: _bioController,
                                decoration: const InputDecoration(
                                    labelText: 'Biografía'),
                                enabled: _isEditing,
                                maxLines: 3),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0)),
                      child: Column(
                        children: [
                          ListTile(
                              leading: const Icon(Icons.work),
                              title: const Text('Rol'),
                              subtitle: Text(_userRole)),
                          ListTile(
                              leading: const Icon(Icons.school),
                              title: const Text('Plantel'),
                              subtitle: Text(_userCampus)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isEditing)
                      Card(
                        elevation: 2.0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0)),
                        color: Colors.red[50],
                        child: ListTile(
                          leading: const Icon(Icons.delete_forever,
                              color: Colors.red),
                          title: const Text('Desactivar Cuenta',
                              style: TextStyle(color: Colors.red)),
                          onTap: _deactivateAccount,
                        ),
                      ),
                    // Add padding to the bottom to avoid the FAB
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}
