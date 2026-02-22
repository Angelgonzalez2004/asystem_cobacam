import 'package:asystem_cobacam/services/faq_service.dart';
import 'package:flutter/material.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  // State variables for UI controls
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Todas';

  // Service instance
  final FaqService _faqService = FaqService();

  // Data lists
  final List<String> _categories = [
    'Todas',
    'Alumnos',
    'Académica',
    'Prefectura',
    'Administrativo',
    'Sistema'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getIconData(String? iconName) {
    // This function remains the same as before
    switch (iconName) {
      case 'timer_outlined': return Icons.timer_outlined;
      case 'phone_android_outlined': return Icons.phone_android_outlined;
      case 'event_busy_outlined': return Icons.event_busy_outlined;
      case 'badge_outlined': return Icons.badge_outlined;
      case 'checkroom_outlined': return Icons.checkroom_outlined;
      case 'grading_outlined': return Icons.grading_outlined;
      case 'record_voice_over_outlined': return Icons.record_voice_over_outlined;
      case 'exit_to_app_outlined': return Icons.exit_to_app_outlined;
      case 'rule_outlined': return Icons.rule_outlined;
      case 'sports_basketball_outlined': return Icons.sports_basketball_outlined;
      case 'school_outlined': return Icons.school_outlined;
      case 'shield_outlined': return Icons.shield_outlined;
      case 'fastfood_outlined': return Icons.fastfood_outlined;
      case 'work_history_outlined': return Icons.work_history_outlined;
      case 'sports_soccer_outlined': return Icons.sports_soccer_outlined;
      case 'chair_outlined': return Icons.chair_outlined;
      case 'description_outlined': return Icons.description_outlined;
      case 'lock_outline': return Icons.lock_outline;
      case 'sick_outlined': return Icons.sick_outlined;
      case 'face_retouching_natural_outlined': return Icons.face_retouching_natural_outlined;
      case 'edit_calendar_outlined': return Icons.edit_calendar_outlined;
      case 'visibility_off_outlined': return Icons.visibility_off_outlined;
      case 'build_circle_outlined': return Icons.build_circle_outlined;
      case 'medical_information_outlined': return Icons.medical_information_outlined;
      case 'directions_bus_outlined': return Icons.directions_bus_outlined;
      case 'menu_book_outlined': return Icons.menu_book_outlined;
      case 'event_repeat_outlined': return Icons.event_repeat_outlined;
      case 'no_meeting_room_outlined': return Icons.no_meeting_room_outlined;
      case 'report_problem_outlined': return Icons.report_problem_outlined;
      case 'model_training_outlined': return Icons.model_training_outlined;
      case 'money_off_outlined': return Icons.money_off_outlined;
      case 'psychology_alt_outlined': return Icons.psychology_alt_outlined;
      case 'percent_outlined': return Icons.percent_outlined;
      case 'computer_outlined': return Icons.computer_outlined;
      case 'groups_outlined': return Icons.groups_outlined;
      case 'emergency_outlined': return Icons.emergency_outlined;
      case 'public_outlined': return Icons.public_outlined;
      case 'science_outlined': return Icons.science_outlined;
      case 'business_center_outlined': return Icons.business_center_outlined;
      case 'how_to_vote_outlined': return Icons.how_to_vote_outlined;
      case 'transfer_within_a_station_outlined': return Icons.transfer_within_a_station_outlined;
      case 'sports_kabaddi_outlined': return Icons.sports_kabaddi_outlined;
      case 'phone_locked_outlined': return Icons.phone_locked_outlined;
      case 'edit_note_outlined': return Icons.edit_note_outlined;
      case 'no_drinks_outlined': return Icons.no_drinks_outlined;
      case 'security_outlined': return Icons.security_outlined;
      case 'backpack_outlined': return Icons.backpack_outlined;
      case 'lock_person_outlined': return Icons.lock_person_outlined;
      case 'supervisor_account_outlined': return Icons.supervisor_account_outlined;
      case 'tour_outlined': return Icons.tour_outlined;
      case 'find_in_page_outlined': return Icons.find_in_page_outlined;
      case 'gavel_outlined': return Icons.gavel_outlined;
      case 'person_off_outlined': return Icons.person_off_outlined;
      case 'local_fire_department_outlined': return Icons.local_fire_department_outlined;
      case 'sensor_door_outlined': return Icons.sensor_door_outlined;
      case 'support_agent_outlined': return Icons.support_agent_outlined;
      case 'policy_outlined': return Icons.policy_outlined;
      case 'style_outlined': return Icons.style_outlined;
      case 'local_shipping_outlined': return Icons.local_shipping_outlined;
      case 'vpn_key_outlined': return Icons.vpn_key_outlined;
      case 'analytics_outlined': return Icons.analytics_outlined;
      case 'campaign_outlined': return Icons.campaign_outlined;
      case 'password_outlined': return Icons.password_outlined;
      case 'manage_accounts_outlined': return Icons.manage_accounts_outlined;
      case 'backup_outlined': return Icons.backup_outlined;
      case 'person_remove_outlined': return Icons.person_remove_outlined;
      case 'date_range_outlined': return Icons.date_range_outlined;
      case 'admin_panel_settings_outlined': return Icons.admin_panel_settings_outlined;
      case 'history_edu_outlined': return Icons.history_edu_outlined;
      case 'payment_outlined': return Icons.payment_outlined;
      case 'file_download_outlined': return Icons.file_download_outlined;
      case 'edit_outlined': return Icons.edit_outlined;
      case 'event_available_outlined': return Icons.event_available_outlined;
      case 'notifications_active_outlined': return Icons.notifications_active_outlined;
      case 'draw_outlined': return Icons.draw_outlined;
      case 'add_to_photos_outlined': return Icons.add_to_photos_outlined;
      case 'copy_all_outlined': return Icons.copy_all_outlined;
      case 'lan_outlined': return Icons.lan_outlined;
      case 'fact_check_outlined': return Icons.fact_check_outlined;
      case 'wifi_off_outlined': return Icons.wifi_off_outlined;
      case 'signal_cellular_alt_outlined': return Icons.signal_cellular_alt_outlined;
      case 'system_update_alt_outlined': return Icons.system_update_alt_outlined;
      case 'verified_user_outlined': return Icons.verified_user_outlined;
      case 'tablet_mac_outlined': return Icons.tablet_mac_outlined;
      case 'brightness_6_outlined': return Icons.brightness_6_outlined;
      case 'sync_problem_outlined': return Icons.sync_problem_outlined;
      case 'cleaning_services_outlined': return Icons.cleaning_services_outlined;
      case 'psychology_outlined': return Icons.psychology_outlined;
      case 'perm_device_information_outlined': return Icons.perm_device_information_outlined;
      case 'devices_other_outlined': return Icons.devices_other_outlined;
      case 'cloud_done_outlined': return Icons.cloud_done_outlined;
      case 'feedback_outlined': return Icons.feedback_outlined;
      case 'airplanemode_active_outlined': return Icons.airplanemode_active_outlined;
      case 'desktop_windows_outlined': return Icons.desktop_windows_outlined;
      case 'fingerprint_outlined': return Icons.fingerprint_outlined;
      case 'phone_iphone_outlined': return Icons.phone_iphone_outlined;
      case 'screen_rotation_outlined': return Icons.screen_rotation_outlined;
      case 'mail_outline': return Icons.mail_outline;
      case 'code_outlined': return Icons.code_outlined;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search and Filter UI remains the same
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar en el manual...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _categories.map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (selected) => setState(() => _selectedCategory = category),
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: _selectedCategory == category
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 20, thickness: 1, indent: 12, endIndent: 12),
          
          // StreamBuilder to get live data from Firebase
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _faqService.getFaqsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay preguntas en el manual.'));
                }

                final faqList = snapshot.data!;
                final filteredList = faqList.where((faq) {
                  final categoryMatch = _selectedCategory == 'Todas' || faq['c'] == _selectedCategory;
                  final queryMatch = _searchQuery.isEmpty ||
                      (faq['q'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (faq['a'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
                  return categoryMatch && queryMatch;
                }).toList();

                if (filteredList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No se encontraron resultados.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final faq = filteredList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      elevation: 2,
                      child: ExpansionTile(
                        shape: Border.all(color: Colors.transparent),
                        leading: Icon(_getIconData(faq['icon'] as String?),
                            color: Theme.of(context).colorScheme.secondary),
                        title: Text('${index + 1}. ${faq['q']}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              faq['a'],
                              textAlign: TextAlign.justify,
                            ),
                          ),
                        ],
                      ),
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
}
