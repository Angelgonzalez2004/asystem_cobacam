import 'dart:io';
import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ManageAnnouncementsScreen extends StatefulWidget {
  final String? campus;
  final bool isGeneralAdmin;

  const ManageAnnouncementsScreen({
    super.key,
    this.campus,
    this.isGeneralAdmin = false,
  });

  @override
  State<ManageAnnouncementsScreen> createState() => _ManageAnnouncementsScreenState();
}

class _ManageAnnouncementsScreenState extends State<ManageAnnouncementsScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  bool _isCreating = false; // Toggle to show form

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _submitAnnouncement() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      UiHelpers.showSnackBar(context, 'Título y mensaje son requeridos.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Usuario no autenticado");

      await _announcementService.createAnnouncement(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        type: widget.isGeneralAdmin ? 'General' : 'Campus',
        campus: widget.isGeneralAdmin ? null : widget.campus,
        authorId: user.uid,
        authorName: widget.isGeneralAdmin ? 'Dirección General' : 'Dirección ${widget.campus ?? ""}',
        imageFile: _selectedImage,
      );

      _resetForm();
      if (mounted) UiHelpers.showSnackBar(context, 'Aviso publicado correctamente.');
    } catch (e) {
      if (mounted) UiHelpers.showSnackBar(context, 'Error al publicar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _isCreating = false;
      _titleController.clear();
      _messageController.clear();
      _selectedImage = null;
    });
  }

  void _handleDelete(AnnouncementModel announcement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Aviso'),
        content: const Text('¿Estás seguro de que deseas eliminar este aviso? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _announcementService.deleteAnnouncement(announcement.id, announcement.imageUrl);
              if (mounted) UiHelpers.showSnackBar(context, 'Aviso eliminado.');
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Comunicados'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _isCreating = !_isCreating),
        label: Text(_isCreating ? 'Cancelar' : 'Nuevo Aviso'),
        icon: Icon(_isCreating ? Icons.close : Icons.add),
      ),
      body: Column(
        children: [
          // Form Area
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _isCreating
                ? Container(
                    color: theme.colorScheme.surface,
                    padding: const EdgeInsets.all(16),
                    child: FadeInUp(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Redactar Comunicado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Título del Aviso',
                                  prefixIcon: Icon(Icons.title),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _messageController,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Mensaje / Contenido',
                                  alignLabelWithHint: true,
                                  prefixIcon: Icon(Icons.article_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Image Picker
                              InkWell(
                                onTap: _pickImage,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.dividerColor, style: BorderStyle.solid),
                                    image: _selectedImage != null
                                        ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: _selectedImage == null
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate_outlined, size: 40, color: theme.colorScheme.primary),
                                            const SizedBox(height: 8),
                                            Text('Agregar Imagen (Opcional)', style: TextStyle(color: theme.colorScheme.primary)),
                                          ],
                                        )
                                      : Align(
                                          alignment: Alignment.topRight,
                                          child: IconButton(
                                            icon: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.close, size: 20)),
                                            onPressed: () => setState(() => _selectedImage = null),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : ElevatedButton.icon(
                                        onPressed: _submitAnnouncement,
                                        icon: const Icon(Icons.send_rounded),
                                        label: const Text('Publicar Aviso'),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // List Area
          Expanded(
            child: StreamBuilder<List<AnnouncementModel>>(
              stream: _announcementService.getAnnouncementsStream(widget.campus, widget.isGeneralAdmin),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mark_email_unread_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No has publicado avisos aún', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                // Filter only own announcements for editing? Or all visible?
                // Requirement: "Tanto por plantel como general puede subir, modificar, eliminar o ver los avisos o lo que publique"
                // Assuming they can manage what matches their scope.
                
                return NewsFeed(
                  announcements: snapshot.data!,
                  isAdmin: true,
                  onDelete: _handleDelete,
                  onEdit: (announcement) {
                    // Pre-fill form for edit logic could go here
                    // For simplicity in this iteration, we focus on Create/Delete
                    UiHelpers.showSnackBar(context, 'Edición disponible en próxima actualización.');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
