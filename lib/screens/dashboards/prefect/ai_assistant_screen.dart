import 'package:asystem_cobacam/services/ai_service.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = []; // {role: 'user'|'bot', text: '...'}
  
  bool _isLoading = false;
  bool _isInitializing = true;
  
  AIService? _aiService;
  String? _currentCycle;

  @override
  void initState() {
    super.initState();
    _initAI();
  }

  Future<void> _initAI() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseDatabase.instance.ref('users/${user.uid}/campus').get();
        final campus = snap.value?.toString();
        
        if (campus != null) {
          _aiService = AIService(campus);
          
          // Obtener ciclo
          final appSettings = AppSettingsService(
            Provider.of<HiveService>(context, listen: false), 
            Provider.of<ConnectivityService>(context, listen: false)
          );
          _currentCycle = await appSettings.getCurrentSchoolCycleId();
          
          // Mensaje de bienvenida
          if (mounted) {
            setState(() {
              _messages.add({
                'role': 'bot',
                'text': '¡Hola! Soy tu Asistente Académico Inteligente. 🤖\n\nPuedes preguntarme sobre:\n- Resumen de asistencia de hoy.\n- Incidencias recientes.\n- Alumnos con reportes.\n\n¿En qué te ayudo?'
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
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _aiService!.askAssistant(text, cycle: _currentCycle);
      if (mounted) {
        setState(() {
          _messages.add({'role': 'bot', 'text': response});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'bot', 'text': 'Lo siento, ocurrió un error al procesar tu solicitud.'});
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 8),
            Text('Asistente IA'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Limpiar Chat',
            onPressed: () => setState(() => _messages.clear()),
          )
        ],
      ),
      body: _isInitializing 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // CHAT AREA
              Expanded(
                child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('Escribe una pregunta para comenzar', style: TextStyle(color: theme.hintColor)),
                          const SizedBox(height: 24),
                          // Sugerencias
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _suggestionChip('¿Resumen de hoy?'),
                              _suggestionChip('¿Últimas incidencias?'),
                              _suggestionChip('¿Quién tiene retardos?'),
                            ],
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser ? theme.primaryColor : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                                bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                              ),
                            ),
                            child: isUser 
                              ? Text(msg['text']!, style: const TextStyle(color: Colors.white))
                              : MarkdownBody(
                                  data: msg['text']!,
                                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                    p: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                          ),
                        );
                      },
                    ),
              ),

              // LOADING INDICATOR
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              // INPUT AREA
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Pregunta algo...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      mini: true,
                      onPressed: () => _sendMessage(_controller.text),
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _suggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () => _sendMessage(text),
      backgroundColor: Theme.of(context).cardColor,
    );
  }
}
