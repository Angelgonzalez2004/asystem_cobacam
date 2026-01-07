import 'dart:io';
import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/services/announcement_service.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:asystem_cobacam/widgets/announcement_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
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
  
  // Múltiples imágenes
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
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

      // Usar el servicio corregido para Web/Móvil y múltiples imágenes
      await _announcementService.publishAnnouncement(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        type: widget.isGeneralAdmin ? 'General' : 'Campus',
        campus: widget.isGeneralAdmin ? null : widget.campus,
        authorId: user.uid,
        authorName: widget.isGeneralAdmin ? 'Dirección General' : 'Dirección ${widget.campus ?? ""}',
        images: _selectedImages,
      );

      _resetForm();
      if (mounted) UiHelpers.showSnackBar(context, '¡Aviso publicado exitosamente!');
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
      _selectedImages.clear();
    });
  }

  void _handleDelete(AnnouncementModel announcement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que deseas eliminar este comunicado? Se borrarán también las imágenes asociadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _announcementService.deleteAnnouncement(announcement);
                if (mounted) UiHelpers.showSnackBar(context, 'Comunicado eliminado correctamente.');
              } catch (e) {
                if (mounted) UiHelpers.showSnackBar(context, 'Error al eliminar: $e', isError: true);
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Eliminar definitivamente', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
        label: Text(_isCreating ? 'Cerrar' : 'Nuevo Aviso'),
        icon: Icon(_isCreating ? Icons.close : Icons.add_comment_rounded),
      ),
      body: Column(
        children: [
          // Formulario
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _isCreating
                ? Container(
                    color: theme.colorScheme.surface,
                    padding: const EdgeInsets.all(16),
                    child: FadeInUp(
                      child: Card(
                        elevation: 4,
                        shadowColor: Colors.black12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Redactar Nuevo Comunicado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _titleController,
                                decoration: _buildInputDecoration('Título del Aviso', Icons.title_rounded),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _messageController,
                                maxLines: 3,
                                decoration: _buildInputDecoration('Mensaje / Contenido', Icons.article_outlined),
                              ),
                              const SizedBox(height: 20),
                              
                              // Galería de Imágenes Seleccionadas
                              _buildImageSelector(theme),
                              
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : ElevatedButton.icon(
                                        onPressed: _submitAnnouncement,
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        icon: const Icon(Icons.send_rounded),
                                        label: const Text('PUBLICAR AHORA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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

          // Lista de Avisos
          Expanded(
            child: StreamBuilder<List<AnnouncementModel>>(
              stream: _announcementService.getAnnouncementsStream(widget.campus, widget.isGeneralAdmin),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final announcements = snapshot.data ?? [];
                
                if (announcements.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_stories_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No hay comunicados publicados aún.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    final announcement = announcements[index];
                    return AnnouncementCard(
                      announcement: announcement,
                      isAdmin: true,
                      onDelete: () => _handleDelete(announcement),
                      onEdit: () => UiHelpers.showSnackBar(context, 'Edición rápida disponible pronto.'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Imágenes Adjuntas (${_selectedImages.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            TextButton.icon(
              onPressed: _pickImages, 
              icon: const Icon(Icons.add_a_photo_rounded, size: 18), 
              label: const Text('Agregar')
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb 
                          ? Image.network(_selectedImages[index].path, width: 80, height: 80, fit: BoxFit.cover)
                          : Image.file(File(_selectedImages[index].path), width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 0, right: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImages.removeAt(index)),
                          child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor, style: BorderStyle.solid),
            ),
            child: const Center(child: Text('Sin imágenes seleccionadas', style: TextStyle(color: Colors.grey, fontSize: 12))),
          ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}