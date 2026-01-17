import 'package:asystem_cobacam/services/ai_service.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = []; // {role, text, time}

  bool _isLoading = false;
  bool _isInitializing = true;

  AIService? _aiService;
  String? _currentCycle;

  // Animaciones
  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
    _initAI();
  }

  @override
  void dispose() {
    _typingController.dispose();
    super.dispose();
  }

  Future<void> _initAI() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseDatabase.instance
            .ref('users/${user.uid}/campus')
            .get();
        final campus = snap.value?.toString();

        if (campus != null) {
          _aiService = AIService(campus);

          final appSettings = AppSettingsService(
              Provider.of<HiveService>(context, listen: false),
              Provider.of<ConnectivityService>(context, listen: false));
          _currentCycle = await appSettings.getCurrentSchoolCycleId();

          if (mounted) {
            setState(() {
              _messages.add({
                'role': 'bot',
                'text':
                    '¡Hola! 👋 Soy AsystemBot.\nAnalizo la asistencia y conducta en tiempo real.\n\nPrueba preguntarme:\n👉 "¿Quién faltó hoy?"\n👉 "Haz un reporte de incidencias"',
                'time': DateTime.now(),
              });
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error init AI: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _aiService == null) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text, 'time': DateTime.now()});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response =
          await _aiService!.askAssistant(text, cycle: _currentCycle);
      if (mounted) {
        setState(() {
          _messages
              .add({'role': 'bot', 'text': response, 'time': DateTime.now()});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'bot',
            'text':
                '⚠️ Lo siento, no pude procesar tu solicitud en este momento.',
            'time': DateTime.now()
          });
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA),
      ),
      child: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // MESSAGES LIST
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          itemCount: _messages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return _buildTypingIndicator(theme);
                            }
                            final msg = _messages[index];
                            return _buildMessageBubble(msg, theme, isDark);
                          },
                        ),
                ),

                // SUGGESTIONS CHIPS
                if (!_isLoading)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _suggestionChip('📊 Resumen de hoy', theme),
                        _suggestionChip('⚠️ Alumnos con reportes', theme),
                        _suggestionChip('🕒 Retardos recientes', theme),
                        _suggestionChip('📝 Generar reporte breve', theme),
                      ],
                    ),
                  ),

                // INPUT AREA
                _buildInputArea(theme, isDark),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Opacity(
        opacity: 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_mosaic_rounded,
                size: 80, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text('¡Pregúntame lo que necesites!',
                style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> msg, ThemeData theme, bool isDark) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.primaryColor
              : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            if (!isUser)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(msg['text'],
                  style: const TextStyle(color: Colors.white, fontSize: 15))
            else
              MarkdownBody(
                data: msg['text'],
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: TextStyle(
                      color:
                          isDark ? Colors.grey[200] : const Color(0xFF334155),
                      fontSize: 15),
                  strong: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold),
                  listBullet: TextStyle(color: theme.primaryColor),
                ),
              ),

            const SizedBox(height: 4),
            // Timestamp tiny
            // Align(
            //   alignment: Alignment.bottomRight,
            //   child: Text(
            //     "Justo ahora",
            //     style: TextStyle(fontSize: 10, color: isUser ? Colors.white70 : Colors.grey),
            //   )
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: theme.primaryColor)),
            const SizedBox(width: 8),
            Text("Analizando datos...",
                style: TextStyle(color: theme.hintColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Escribe tu consulta...',
                  hintStyle: TextStyle(color: theme.hintColor),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: () => _sendMessage(_controller.text),
              backgroundColor: theme.primaryColor,
              elevation: 2,
              mini: true,
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
      child: ActionChip(
        label: Text(text),
        onPressed: () => _sendMessage(text),
        avatar: Icon(Icons.auto_awesome, size: 14, color: theme.primaryColor),
        backgroundColor: theme.cardColor,
        elevation: 1,
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle:
            TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}
