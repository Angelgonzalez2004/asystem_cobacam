import 'package:asystem_cobacam/services/access_code_service.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';

class ManageAccessCodesScreen extends StatefulWidget {
  final String? campus;
  final bool isGeneralAdmin;

  const ManageAccessCodesScreen({
    super.key,
    this.campus,
    this.isGeneralAdmin = false,
  });

  @override
  State<ManageAccessCodesScreen> createState() =>
      _ManageAccessCodesScreenState();
}

class _ManageAccessCodesScreenState extends State<ManageAccessCodesScreen> {
  final AccessCodeService _codeService = AccessCodeService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Llaves de Registro'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => UiHelpers.showSnackBar(
                context, 'Estos códigos son fijos por ciclo escolar.'),
          )
        ],
      ),
      body: widget.isGeneralAdmin ? _buildGeneralView() : _buildCampusView(),
    );
  }

  // Vista para Admin de Plantel (Solo sus roles)
  Widget _buildCampusView() {
    if (widget.campus == null)
      return const Center(child: Text("Identificando plantel..."));

    return StreamBuilder<Map<dynamic, dynamic>>(
      stream: _codeService.getCampusCodesStream(widget.campus!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final codes = snapshot.data ?? {};
        if (codes.isEmpty) return _buildNoDataPlaceholder();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildCampusSection(widget.campus!, codes, isOpen: true),
          ],
        );
      },
    );
  }

  // Vista para Admin General (Todos los planteles + General)
  Widget _buildGeneralView() {
    return StreamBuilder<Map<dynamic, dynamic>>(
      stream: _codeService.getAllCodesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final allData = snapshot.data ?? {};

        // Convertir a lista y ordenar alfabéticamente
        final sortedKeys = allData.keys.toList()..sort();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // SECCIÓN ADMINISTRADOR GENERAL (SOLO PARA ADMIN GENERAL)
            _buildGeneralAdminSection(),
            const SizedBox(height: 24),
            const Text('LLAVES POR PLANTEL',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            if (allData.isEmpty) _buildNoDataPlaceholder(),
            ...sortedKeys.map((campusName) {
              Map campusCodes = Map.from(allData[campusName] as Map);
              return _buildCampusSection(campusName, campusCodes);
            }),
          ],
        );
      },
    );
  }

  Widget _buildGeneralAdminSection() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        title: const Text('ADMINISTRACIÓN GENERAL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading:
            const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              dense: true,
              title: Text('Acceso Administrador General',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Llave maestra del sistema',
                  style: TextStyle(color: Colors.white70)),
              trailing: Text('COBACAM_SUPER_2025',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      fontSize: 14)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCampusSection(String campusName, Map codes,
      {bool isOpen = false}) {
    final theme = Theme.of(context);

    // Preparar lista de widgets
    List<Widget> children = codes.entries.map((e) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          dense: true,
          title: Text(e.key.toString(),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Código de acceso oficial'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              e.value.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace'),
            ),
          ),
        ),
      );
    }).toList();

    // Añadir espaciado final
    children.add(const SizedBox(height: 12));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isOpen,
        shape: const Border(),
        title: Text(campusName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle),
          child: Icon(Icons.school_rounded,
              color: theme.colorScheme.primary, size: 20),
        ),
        children: children,
      ),
    );
  }

  Widget _buildNoDataPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.vpn_key_off_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No hay llaves registradas en la nube.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
