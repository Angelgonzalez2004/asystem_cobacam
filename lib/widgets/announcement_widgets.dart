import 'dart:io';
import 'dart:ui';
import 'package:asystem_cobacam/models/announcement_model.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/web_downloader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// --- WIDGET PRINCIPAL DE LA TARJETA ---

class AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final String? currentUserId;
  final String? currentUserRole;
  final String? currentUserCampus;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.currentUserId,
    this.currentUserRole,
    this.currentUserCampus,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final date = DateTime.fromMillisecondsSinceEpoch(announcement.timestamp);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    
    // LÓGICA AVANZADA DE PERMISOS (COLABORATIVA)
    bool canManage = false;

    // 1. El autor siempre tiene permiso
    if (currentUserId != null && currentUserId == announcement.authorId) {
      canManage = true;
    } 
    // 2. Lógica para Admin General (Puede gestionar cualquier aviso General)
    else if (currentUserRole == 'Personal Administrativo General' && announcement.type == 'General') {
      canManage = true;
    }
    // 3. Lógica para Admin Plantel (Puede gestionar cualquier aviso de SU plantel)
    else if (currentUserRole == 'Personal Administrativo por Plantel' && 
             announcement.campus == currentUserCampus && 
             currentUserCampus != null) {
      canManage = true;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
      decoration: BoxDecoration(
        color: isDark ? theme.cardTheme.color : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildAvatar(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(announcement.authorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(formattedDate,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                if (announcement.type == 'General')
                  _buildTag('OFICIAL', Colors.orange),
                if (canManage) _buildAdminMenu(),
              ],
            ),
          ),

          // Contenido de Texto (Título y Mensaje)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  announcement.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // GRID DE IMÁGENES MEJORADO
          if (announcement.imageUrls != null &&
              announcement.imageUrls!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SmartImageGrid(
                images: announcement.imageUrls!,
                heroPrefix: announcement.id,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 2),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        child: Text(
          announcement.authorName.isNotEmpty
              ? announcement.authorName[0].toUpperCase()
              : 'A',
          style: TextStyle(
              color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildAdminMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text('Editar')
            ])),
        const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(color: Colors.red))
            ])),
      ],
    );
  }
}

// --- WIDGET LISTA DE NOTICIAS ---

class NewsFeed extends StatelessWidget {
  final List<AnnouncementModel> announcements;
  final String? currentUserId;
  final String? currentUserRole;
  final String? currentUserCampus;
  final Function(AnnouncementModel)? onDelete;
  final Function(AnnouncementModel)? onEdit;

  const NewsFeed({
    super.key,
    required this.announcements,
    this.currentUserId,
    this.currentUserRole,
    this.currentUserCampus,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feed_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No hay avisos recientes',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: announcements.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: AnnouncementCard(
            announcement: announcements[index],
            currentUserId: currentUserId,
            currentUserRole: currentUserRole,
            currentUserCampus: currentUserCampus,
            onDelete: () => onDelete?.call(announcements[index]),
            onEdit: () => onEdit?.call(announcements[index]),
          ),
        );
      },
    );
  }
}

// --- NUEVO COMPONENTE: GRID INTELIGENTE DE IMÁGENES ---

class SmartImageGrid extends StatelessWidget {
  final List<String> images;
  final String heroPrefix;

  const SmartImageGrid({
    super.key,
    required this.images,
    required this.heroPrefix,
  });

  void _openGallery(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrls: images,
          initialIndex: initialIndex,
          heroPrefix: heroPrefix,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int count = images.length;
    
    // CASO 1: Una sola imagen (Layout adaptable con fondo desenfocado)
    if (count == 1) {
      return GestureDetector(
        onTap: () => _openGallery(context, 0),
        child: Hero(
          tag: '$heroPrefix-0',
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            child: Stack(
              fit: StackFit.loose,
              alignment: Alignment.center,
              children: [
                // Fondo borroso (para rellenar espacio si es vertical)
                Positioned.fill(
                  child: Image.network(
                    images[0],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                ),
                
                // Imagen Principal (Completa)
                Image.network(
                  images[0],
                  fit: BoxFit.contain, // Muestra la imagen completa
                  width: double.infinity,
                  // Dejamos que la altura se ajuste pero con el límite del container
                  errorBuilder: (_, __, ___) => _buildErrorBox(),
                  loadingBuilder: (_, child, loading) {
                    if (loading == null) return child;
                    return Container(
                      height: 250,
                      color: Colors.transparent,
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // CASO 2: Grid 2 o más imágenes
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        // Altura calculada dinámicamente para mantener proporciones
        double height = (count == 2) ? width * 0.6 : width; 
        
        return SizedBox(
          height: height,
          child: _buildGrid(count, context),
        );
      },
    );
  }

  Widget _buildGrid(int count, BuildContext context) {
    if (count == 2) {
      return Row(
        children: [
          Expanded(child: _buildImageTile(context, 0, height: double.infinity)),
          const SizedBox(width: 4),
          Expanded(child: _buildImageTile(context, 1, height: double.infinity)),
        ],
      );
    }
    
    if (count == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: _buildImageTile(context, 0, height: double.infinity)),
          const SizedBox(width: 4),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildImageTile(context, 1, width: double.infinity)),
                const SizedBox(height: 4),
                Expanded(child: _buildImageTile(context, 2, width: double.infinity)),
              ],
            ),
          ),
        ],
      );
    }

    // 4 o más
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImageTile(context, 0, height: double.infinity)),
              const SizedBox(width: 4),
              Expanded(child: _buildImageTile(context, 1, height: double.infinity)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImageTile(context, 2, height: double.infinity)),
              const SizedBox(width: 4),
              Expanded(
                child: count > 4 
                  ? _buildOverlayTile(context, 3, count - 4) 
                  : _buildImageTile(context, 3, height: double.infinity),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile(BuildContext context, int index, {double? width, double? height}) {
    return GestureDetector(
      onTap: () => _openGallery(context, index),
      child: Hero(
        tag: '$heroPrefix-$index',
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
          ),
          child: Image.network(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildErrorBox(),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayTile(BuildContext context, int index, int remaining) {
    return GestureDetector(
      onTap: () => _openGallery(context, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: '$heroPrefix-$index',
            child: Image.network(
              images[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildErrorBox(),
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Text(
                '+$remaining',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}

// --- LIGHTBOX / VISOR A PANTALLA COMPLETA ---

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String heroPrefix;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.heroPrefix,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  Future<void> _saveImage(BuildContext context, String imageUrl) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Descargando imagen...')
          ]),
          duration: Duration(seconds: 10), // Duración larga, se ocultará al terminar
        ),
      );

      // 1. Descargar bytes
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception("Error al descargar");
      final bytes = response.bodyBytes;
      
      // Ocultar SnackBar de carga
      if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // 2. Guardar según plataforma
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // ESCRITORIO: Usar FilePicker
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar imagen como...',
          fileName: 'cobacam_${DateTime.now().millisecondsSinceEpoch}.jpg',
          type: FileType.image,
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Imagen guardada en tu PC'), backgroundColor: Colors.green),
            );
          }
        }
      } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // MÓVIL: Usar Galería (GAL)
        // Pedir permisos explícitamente si es necesario (Gal lo suele manejar, pero por seguridad)
        if (!await Gal.hasAccess()) {
          await Gal.requestAccess();
        }
        
        await Gal.putImageBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Guardada en la Galería'), backgroundColor: Colors.green),
          );
        }
      } else if (kIsWeb) {
        // WEB
        await downloadImageWeb(bytes, 'cobacam_img_${DateTime.now().millisecondsSinceEpoch}.jpg');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Descarga iniciada'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveAllImages(BuildContext context) async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // ESCRITORIO: Seleccionar CARPETA una sola vez
        String? dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Seleccionar carpeta de destino');
        
        if (dirPath == null) return; // Cancelado por usuario

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Guardando ${widget.imageUrls.length} imágenes...'), duration: const Duration(seconds: 2)),
        );

        int count = 0;
        for (int i = 0; i < widget.imageUrls.length; i++) {
          final response = await http.get(Uri.parse(widget.imageUrls[i]));
          if (response.statusCode == 200) {
            final String separator = Platform.pathSeparator;
            // Limpiar path si no tiene separador al final
            final String cleanDir = dirPath.endsWith(separator) ? dirPath : '$dirPath$separator';
            final String filePath = '${cleanDir}cobacam_aviso_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
            
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            count++;
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ $count imágenes guardadas exitosamente'), backgroundColor: Colors.green),
          );
        }

      } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // MÓVIL: Guardar en bucle
        if (!await Gal.hasAccess()) {
           await Gal.requestAccess();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Iniciando descarga masiva...'), duration: Duration(seconds: 2)),
        );

        int count = 0;
        for (var url in widget.imageUrls) {
          try {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              await Gal.putImageBytes(response.bodyBytes);
              count++;
            }
          } catch (e) {
            debugPrint("Error saving one image: $e");
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ $count imágenes guardadas en Galería'), backgroundColor: Colors.green),
          );
        }
      } else if (kIsWeb) {
        // WEB: Descarga masiva (bucle de descargas individuales)
        // Nota: El navegador puede pedir permiso para descargar múltiples archivos
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Procesando descargas...'), duration: Duration(seconds: 2)),
        );
        
        for (int i = 0; i < widget.imageUrls.length; i++) {
          final response = await http.get(Uri.parse(widget.imageUrls[i]));
          if (response.statusCode == 200) {
            await downloadImageWeb(response.bodyBytes, 'cobacam_aviso_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
            // Pequeña pausa para evitar bloqueo del navegador o bloqueadores de popups agresivos
            await Future.delayed(const Duration(milliseconds: 500)); 
          }
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Descargas iniciadas'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
       if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error en descarga masiva: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildMultiDownloadMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 30),
      color: const Color(0xFF1E293B), // Fondo oscuro para coincidir con el tema
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'single') {
          _saveImage(context, widget.imageUrls[_currentIndex]);
        } else if (value == 'all') {
          _saveAllImages(context);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'single',
          child: Row(
            children: [
              Icon(Icons.image_outlined, color: Colors.white70),
              SizedBox(width: 12),
              Text('Guardar imagen actual', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'all',
          child: Row(
            children: [
              const Icon(Icons.copy_all_rounded, color: Colors.white70),
              const SizedBox(width: 12),
              Text('Guardar todas (${widget.imageUrls.length})', style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Visor
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(widget.imageUrls[index]),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                heroAttributes: PhotoViewHeroAttributes(
                  tag: '${widget.heroPrefix}-$index',
                ),
              );
            },
            itemCount: widget.imageUrls.length,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          
          // Botón Cerrar (Izquierda)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Botón de Acción (Guardar)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: widget.imageUrls.length > 1
                ? _buildMultiDownloadMenu(context)
                : IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 30),
                    tooltip: 'Guardar Imagen',
                    onPressed: () => _saveImage(context, widget.imageUrls[_currentIndex]),
                  ),
          ),

          // Indicador de Página
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "${_currentIndex + 1} / ${widget.imageUrls.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- MINI IMPLEMENTACIÓN DE PHOTO VIEW (SIN DEPENDENCIAS EXTERNAS) ---
// Nota: Normalmente usaríamos el paquete 'photo_view', pero para evitar conflictos de dependencias
// y mantener el código autónomo, implementaré una versión simplificada usando InteractiveViewer
// que es nativo de Flutter.

class PhotoViewGallery extends StatelessWidget {
  final ScrollPhysics scrollPhysics;
  final int itemCount;
  final PageController pageController;
  final Function(int) onPageChanged;
  final Widget Function(BuildContext, int) builder;
  final Widget Function(BuildContext, ImageChunkEvent?)? loadingBuilder;

  const PhotoViewGallery.builder({
    super.key,
    required this.scrollPhysics,
    required this.itemCount,
    required this.builder,
    required this.pageController,
    required this.onPageChanged,
    this.loadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      physics: scrollPhysics,
      controller: pageController,
      onPageChanged: onPageChanged,
      itemCount: itemCount,
      itemBuilder: builder,
    );
  }
}

class PhotoViewGalleryPageOptions extends StatelessWidget {
  final ImageProvider imageProvider;
  final dynamic initialScale; // No usado en InteractiveViewer simple pero mantenido por compatibilidad de API mental
  final dynamic minScale;
  final dynamic maxScale;
  final PhotoViewHeroAttributes? heroAttributes;

  const PhotoViewGalleryPageOptions({
    super.key,
    required this.imageProvider,
    this.initialScale,
    this.minScale,
    this.maxScale,
    this.heroAttributes,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image(
      image: imageProvider,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      },
    );

    if (heroAttributes != null) {
      image = Hero(tag: heroAttributes!.tag, child: image);
    }

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(child: image),
    );
  }
}

class PhotoViewHeroAttributes {
  final String tag;
  PhotoViewHeroAttributes({required this.tag});
}

class PhotoViewComputedScale {
  static const contained = 1.0;
  static const covered = 2.0;
}
