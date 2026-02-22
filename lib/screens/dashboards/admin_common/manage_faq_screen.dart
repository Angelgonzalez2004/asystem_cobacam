import 'package:asystem_cobacam/services/faq_service.dart';
import 'package:asystem_cobacam/utils/ui_helpers.dart';
import 'package:flutter/material.dart';

// Helper map to convert string back to IconData
const Map<String, IconData> iconMap = {
  'timer_outlined': Icons.timer_outlined,
  'phone_android_outlined': Icons.phone_android_outlined,
  'event_busy_outlined': Icons.event_busy_outlined,
  'badge_outlined': Icons.badge_outlined,
  'checkroom_outlined': Icons.checkroom_outlined,
  'grading_outlined': Icons.grading_outlined,
  'record_voice_over_outlined': Icons.record_voice_over_outlined,
  'exit_to_app_outlined': Icons.exit_to_app_outlined,
  'rule_outlined': Icons.rule_outlined,
  'sports_basketball_outlined': Icons.sports_basketball_outlined,
  'school_outlined': Icons.school_outlined,
  'shield_outlined': Icons.shield_outlined,
  'fastfood_outlined': Icons.fastfood_outlined,
  'work_history_outlined': Icons.work_history_outlined,
  'sports_soccer_outlined': Icons.sports_soccer_outlined,
  'chair_outlined': Icons.chair_outlined,
  'description_outlined': Icons.description_outlined,
  'lock_outline': Icons.lock_outline,
  'sick_outlined': Icons.sick_outlined,
  'face_retouching_natural_outlined': Icons.face_retouching_natural_outlined,
  'edit_calendar_outlined': Icons.edit_calendar_outlined,
  'visibility_off_outlined': Icons.visibility_off_outlined,
  'build_circle_outlined': Icons.build_circle_outlined,
  'medical_information_outlined': Icons.medical_information_outlined,
  'directions_bus_outlined': Icons.directions_bus_outlined,
  'menu_book_outlined': Icons.menu_book_outlined,
  'event_repeat_outlined': Icons.event_repeat_outlined,
  'no_meeting_room_outlined': Icons.no_meeting_room_outlined,
  'report_problem_outlined': Icons.report_problem_outlined,
  'model_training_outlined': Icons.model_training_outlined,
  'money_off_outlined': Icons.money_off_outlined,
  'psychology_alt_outlined': Icons.psychology_alt_outlined,
  'percent_outlined': Icons.percent_outlined,
  'computer_outlined': Icons.computer_outlined,
  'groups_outlined': Icons.groups_outlined,
  'emergency_outlined': Icons.emergency_outlined,
  'public_outlined': Icons.public_outlined,
  'science_outlined': Icons.science_outlined,
  'business_center_outlined': Icons.business_center_outlined,
  'how_to_vote_outlined': Icons.how_to_vote_outlined,
  'transfer_within_a_station_outlined': Icons.transfer_within_a_station_outlined,
  'sports_kabaddi_outlined': Icons.sports_kabaddi_outlined,
  'phone_locked_outlined': Icons.phone_locked_outlined,
  'edit_note_outlined': Icons.edit_note_outlined,
  'no_drinks_outlined': Icons.no_drinks_outlined,
  'security_outlined': Icons.security_outlined,
  'backpack_outlined': Icons.backpack_outlined,
  'lock_person_outlined': Icons.lock_person_outlined,
  'supervisor_account_outlined': Icons.supervisor_account_outlined,
  'tour_outlined': Icons.tour_outlined,
  'find_in_page_outlined': Icons.find_in_page_outlined,
  'gavel_outlined': Icons.gavel_outlined,
  'person_off_outlined': Icons.person_off_outlined,
  'local_fire_department_outlined': Icons.local_fire_department_outlined,
  'sensor_door_outlined': Icons.sensor_door_outlined,
  'support_agent_outlined': Icons.support_agent_outlined,
  'policy_outlined': Icons.policy_outlined,
  'style_outlined': Icons.style_outlined,
  'local_shipping_outlined': Icons.local_shipping_outlined,
  'vpn_key_outlined': Icons.vpn_key_outlined,
  'analytics_outlined': Icons.analytics_outlined,
  'campaign_outlined': Icons.campaign_outlined,
  'password_outlined': Icons.password_outlined,
  'manage_accounts_outlined': Icons.manage_accounts_outlined,
  'backup_outlined': Icons.backup_outlined,
  'person_remove_outlined': Icons.person_remove_outlined,
  'date_range_outlined': Icons.date_range_outlined,
  'admin_panel_settings_outlined': Icons.admin_panel_settings_outlined,
  'history_edu_outlined': Icons.history_edu_outlined,
  'payment_outlined': Icons.payment_outlined,
  'file_download_outlined': Icons.file_download_outlined,
  'edit_outlined': Icons.edit_outlined,
  'event_available_outlined': Icons.event_available_outlined,
  'notifications_active_outlined': Icons.notifications_active_outlined,
  'draw_outlined': Icons.draw_outlined,
  'add_to_photos_outlined': Icons.add_to_photos_outlined,
  'copy_all_outlined': Icons.copy_all_outlined,
  'lan_outlined': Icons.lan_outlined,
  'fact_check_outlined': Icons.fact_check_outlined,
  'wifi_off_outlined': Icons.wifi_off_outlined,
  'signal_cellular_alt_outlined': Icons.signal_cellular_alt_outlined,
  'system_update_alt_outlined': Icons.system_update_alt_outlined,
  'verified_user_outlined': Icons.verified_user_outlined,
  'tablet_mac_outlined': Icons.tablet_mac_outlined,
  'brightness_6_outlined': Icons.brightness_6_outlined,
  'sync_problem_outlined': Icons.sync_problem_outlined,
  'cleaning_services_outlined': Icons.cleaning_services_outlined,
  'psychology_outlined': Icons.psychology_outlined,
  'perm_device_information_outlined': Icons.perm_device_information_outlined,
  'devices_other_outlined': Icons.devices_other_outlined,
  'cloud_done_outlined': Icons.cloud_done_outlined,
  'feedback_outlined': Icons.feedback_outlined,
  'airplanemode_active_outlined': Icons.airplanemode_active_outlined,
  'desktop_windows_outlined': Icons.desktop_windows_outlined,
  'fingerprint_outlined': Icons.fingerprint_outlined,
  'phone_iphone_outlined': Icons.phone_iphone_outlined,
  'screen_rotation_outlined': Icons.screen_rotation_outlined,
  'mail_outline': Icons.mail_outline,
  'code_outlined': Icons.code_outlined,
};

class ManageFaqScreen extends StatefulWidget {
  const ManageFaqScreen({super.key});

  @override
  State<ManageFaqScreen> createState() => _ManageFaqScreenState();
}

class _ManageFaqScreenState extends State<ManageFaqScreen> {
  final FaqService _faqService = FaqService();

  void _showFaqFormDialog({Map<String, dynamic>? faq}) {
    final formKey = GlobalKey<FormState>();
    final qController = TextEditingController(text: faq?['q'] ?? '');
    final aController = TextEditingController(text: faq?['a'] ?? '');
    String? selectedCategory = faq?['c'];
    String? selectedIcon = faq?['icon'];

    final categories = ['Alumnos', 'Académica', 'Prefectura', 'Administrativo', 'Sistema'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(faq == null ? 'Nueva Pregunta' : 'Editar Pregunta'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: qController,
                    decoration: const InputDecoration(labelText: 'Pregunta', border: OutlineInputBorder()),
                    validator: (val) => val!.isEmpty ? 'La pregunta no puede estar vacía' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: aController,
                    decoration: const InputDecoration(labelText: 'Respuesta', border: OutlineInputBorder()),
                    maxLines: 5,
                    minLines: 3,
                    validator: (val) => val!.isEmpty ? 'La respuesta no puede estar vacía' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => selectedCategory = val,
                    validator: (val) => val == null ? 'Debe seleccionar una categoría' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedIcon,
                    decoration: const InputDecoration(labelText: 'Ícono', border: OutlineInputBorder()),
                    isExpanded: true,
                    items: iconMap.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(entry.value),
                            const SizedBox(width: 10),
                            Expanded(child: Text(entry.key, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => selectedIcon = val,
                    validator: (val) => val == null ? 'Debe seleccionar un ícono' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final faqData = {
                    'q': qController.text,
                    'a': aController.text,
                    'c': selectedCategory,
                    'icon': selectedIcon,
                  };
                  if (faq == null) {
                    _faqService.addFaq(faqData);
                  } else {
                    _faqService.updateFaq(faq['key'], faqData);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Manual'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _faqService.getFaqsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay preguntas. Añade una para empezar.'));
          }

          final faqs = snapshot.data!;
          return ListView.builder(
            itemCount: faqs.length,
            itemBuilder: (context, index) {
              final faq = faqs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Icon(iconMap[faq['icon']] ?? Icons.help_outline),
                  title: Text(faq['q'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(faq['c'], style: TextStyle(color: Colors.grey.shade600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showFaqFormDialog(faq: faq),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await UiHelpers.showConfirmationDialog(
                            context,
                            title: 'Confirmar Eliminación',
                            content: '¿Estás seguro de que quieres eliminar esta pregunta?',
                          );
                          if (confirm) {
                            _faqService.deleteFaq(faq['key']);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFaqFormDialog(),
        tooltip: 'Añadir Nueva Pregunta',
        child: const Icon(Icons.add),
      ),
    );
  }
}
