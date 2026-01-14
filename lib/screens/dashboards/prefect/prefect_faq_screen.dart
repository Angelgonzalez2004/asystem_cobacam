import 'package:asystem_cobacam/utils/animations.dart';
import 'package:flutter/material.dart';

class PrefectFaqScreen extends StatefulWidget {
  const PrefectFaqScreen({super.key});

  @override
  State<PrefectFaqScreen> createState() => _PrefectFaqScreenState();
}

class _PrefectFaqScreenState extends State<PrefectFaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Todas';

  // Categorías (30 preguntas cada una = 150 Total)
  final List<String> _categories = [
    'Todas',
    'Alumnos',
    'Académica',
    'Administrativo',
    'Prefectura',
    'Sistema'
  ];

  // BASE DE CONOCIMIENTO (150 Preguntas)
  final List<Map<String, dynamic>> _faqList = [
    // --- 1. ROL: ALUMNOS (30 Preguntas) ---
    {'q': '¿Cuál es la tolerancia de entrada para alumnos?', 'a': '15 minutos de tolerancia. De 16 a 20 min es retardo. Más de 20 min requiere pase de dirección.', 'c': 'Alumnos', 'icon': Icons.timer_outlined},
    {'q': '¿Reglamento sobre uso de celulares?', 'a': 'Prohibido en clase salvo fin didáctico. 1° aviso: verbal. 2° aviso: decomiso y reporte en sistema.', 'c': 'Alumnos', 'icon': Icons.phone_locked_outlined},
    {'q': '¿Protocolo de salida anticipada por salud?', 'a': 'Requiere valoración. Se contacta al tutor y se registra en la App como "Salida - Salud".', 'c': 'Alumnos', 'icon': Icons.sick_outlined},
    {'q': '¿Código de vestimenta y uniforme?', 'a': 'Obligatorio completo. Falda a la rodilla, zapatos escolares. No piercings ni tintes fantasía sin permiso.', 'c': 'Alumnos', 'icon': Icons.checkroom_outlined},
    {'q': '¿Sanción por riña o violencia?', 'a': 'Falta grave. Separación inmediata, aviso a seguridad, reporte de incidencia y citatorio urgente a padres.', 'c': 'Alumnos', 'icon': Icons.front_hand_outlined},
    {'q': '¿Alumnos fuera del aula en clase?', 'a': 'Solo con pase de salida del docente. Si no lo tienen, deben regresar al aula y se anota reporte.', 'c': 'Alumnos', 'icon': Icons.meeting_room_outlined},
    {'q': '¿Pérdida de credencial estudiantil?', 'a': 'El alumno debe reportarlo y tramitar reposición en Caja. Mientras, usa pase temporal de Dirección.', 'c': 'Alumnos', 'icon': Icons.badge_outlined},
    {'q': '¿Consumo de alimentos en aula?', 'a': 'Estrictamente prohibido por higiene. Solo se permite agua simple. Alimentos solo en cafetería/receso.', 'c': 'Alumnos', 'icon': Icons.fastfood_outlined},
    {'q': '¿Uso de gorras o sombreros?', 'a': 'Prohibido dentro de aulas, laboratorios y oficinas. Permitido en áreas libres (canchas) por sol.', 'c': 'Alumnos', 'icon': Icons.wb_sunny_outlined},
    {'q': '¿Justificante por inasistencia personal?', 'a': 'El padre debe acudir a justificar en las primeras 48hrs. El alumno no puede justificar por sí mismo.', 'c': 'Alumnos', 'icon': Icons.personal_injury_outlined},
    {'q': '¿Noviazgos en el plantel?', 'a': 'Se permite la convivencia respetuosa. Besos excesivos o contacto inapropiado son motivo de amonestación.', 'c': 'Alumnos', 'icon': Icons.favorite_border_outlined},
    {'q': '¿Uso de audífonos en pasillos?', 'a': 'Permitido en receso. Prohibido durante cambios de hora o en clase si no lo indica el docente.', 'c': 'Alumnos', 'icon': Icons.headphones_outlined},
    {'q': '¿Alumnos en estacionamiento?', 'a': 'Área restringida. Ningún alumno debe permanecer ahí por seguridad y prevención de accidentes.', 'c': 'Alumnos', 'icon': Icons.local_parking_outlined},
    {'q': '¿Venta de productos (dulces)?', 'a': 'Comercio informal prohibido. Se decomisa el producto y se cita al tutor.', 'c': 'Alumnos', 'icon': Icons.store_outlined},
    {'q': '¿Mochilas transparentes?', 'a': 'No es obligatorio, pero se sugiere. Facilita la revisión en operativos "Mochila Segura".', 'c': 'Alumnos', 'icon': Icons.backpack_outlined},
    {'q': '¿Uso de maquillaje?', 'a': 'Discreto y natural permitido. Excesos no acordes al uniforme serán observados.', 'c': 'Alumnos', 'icon': Icons.face_2_outlined},
    {'q': '¿Cabello largo en varones?', 'a': 'Debe estar limpio y peinado. Si interfiere en laboratorios, debe recogerse obligatoriamente.', 'c': 'Alumnos', 'icon': Icons.face_outlined},
    {'q': '¿Fumar/Vapear en baños?', 'a': 'Falta muy grave. Suspensión temporal inmediata y condicionamiento de matrícula.', 'c': 'Alumnos', 'icon': Icons.smoke_free_outlined},
    {'q': '¿Tareas no entregadas?', 'a': 'Es tema académico, pero si el alumno se niega a trabajar sistemáticamente, se reporta a Orientación.', 'c': 'Alumnos', 'icon': Icons.assignment_late_outlined},
    {'q': '¿Embarazo estudiantil?', 'a': 'Se brinda apoyo y facilidades. No es motivo de baja. Se activa protocolo de salud y seguimiento.', 'c': 'Alumnos', 'icon': Icons.pregnant_woman_outlined},
    {'q': '¿Ciberacoso entre alumnos?', 'a': 'Misma gravedad que presencial. Capturas de pantalla sirven de evidencia para sanciones según reglamento.', 'c': 'Alumnos', 'icon': Icons.screenshot_monitor_outlined},
    {'q': '¿Transporte escolar (Bicicletas/Motos)?', 'a': 'Deben dejarse encadenadas en la zona designada. El plantel no se hace responsable por daños o robos.', 'c': 'Alumnos', 'icon': Icons.pedal_bike_outlined},
    {'q': '¿Pérdida de libros de biblioteca?', 'a': 'El alumno debe reponer el material físico (mismo título/autor) para liberar su carta de no adeudo.', 'c': 'Alumnos', 'icon': Icons.import_contacts_outlined},
    {'q': '¿Uso de patinetas en pasillos?', 'a': 'Prohibido por riesgo de accidentes. Deben guardarse al entrar al plantel.', 'c': 'Alumnos', 'icon': Icons.skateboarding_outlined},
    {'q': '¿Tatuajes visibles?', 'a': 'No están prohibidos, pero se pide discreción y evitar símbolos ofensivos o contrarios a los valores institucionales.', 'c': 'Alumnos', 'icon': Icons.draw_outlined},
    {'q': '¿Traer mascotas al plantel?', 'a': 'Prohibido por higiene y seguridad. Excepciones solo para perros guía con documentación.', 'c': 'Alumnos', 'icon': Icons.pets_outlined},
    {'q': '¿Venta de boletos/rifas?', 'a': 'Prohibido realizar sorteos o colectas sin autorización explícita de la Dirección General.', 'c': 'Alumnos', 'icon': Icons.confirmation_number_outlined},
    {'q': '¿Lenguaje inapropiado?', 'a': 'El uso de groserías o lenguaje soez se sanciona con amonestación verbal. Reincidencia genera reporte.', 'c': 'Alumnos', 'icon': Icons.record_voice_over_outlined},
    {'q': '¿Grupos de WhatsApp de salón?', 'a': 'No son canales oficiales. La escuela no regula lo que sucede en chats privados externos.', 'c': 'Alumnos', 'icon': Icons.chat_outlined},
    {'q': '¿Juegos de azar (baraja/dados)?', 'a': 'Prohibidos dentro de las instalaciones por fomentar apuestas y ludopatía.', 'c': 'Alumnos', 'icon': Icons.casino_outlined},

    // --- 2. ROL: ACADÉMICA (30 Preguntas) ---
    {'q': '¿Ausencia imprevista de un docente?', 'a': 'El grupo debe permanecer en el aula o biblioteca. Prefectura toma asistencia y custodia el orden.', 'c': 'Académica', 'icon': Icons.person_off_outlined},
    {'q': '¿Solicitud de cambio de salón?', 'a': 'Debe ser autorizado por Subdirección Académica. Prefectura verifica el traslado ordenado del grupo.', 'c': 'Académica', 'icon': Icons.swap_horiz_outlined},
    {'q': '¿Entrega de listas físicas?', 'a': 'Las listas oficiales se generan en Control Escolar. El docente debe firmar su asistencia en la bitácora diaria.', 'c': 'Académica', 'icon': Icons.assignment_outlined},
    {'q': '¿Uso de laboratorio y equipos?', 'a': 'Requiere reservación previa. El docente es responsable de revisar el estado del material al entrar y salir.', 'c': 'Académica', 'icon': Icons.science_outlined},
    {'q': '¿Reporte de conducta por el docente?', 'a': 'El docente puede solicitar al Prefecto el levantamiento de un reporte digital si la conducta interrumpe la clase.', 'c': 'Académica', 'icon': Icons.gavel_outlined},
    {'q': '¿Horarios de exámenes parciales?', 'a': 'Se publican en el tablero oficial. No se permiten salidas al baño durante la evaluación salvo emergencia.', 'c': 'Académica', 'icon': Icons.quiz_outlined},
    {'q': '¿Justificantes grupales (Deportes)?', 'a': 'La Dirección Académica emite un oficio listando a los alumnos. En la App, se marca como "Justificado-Evento".', 'c': 'Académica', 'icon': Icons.sports_outlined},
    {'q': '¿Material didáctico (Proyectores)?', 'a': 'Se solicitan en la coordinación. El prefecto puede apoyar en la logística de entrega y recepción.', 'c': 'Académica', 'icon': Icons.cable_outlined},
    {'q': '¿Retardo del docente?', 'a': 'Se da tolerancia de 10 min. Si no llega, el jefe de grupo avisa a Prefectura para activar guardia.', 'c': 'Académica', 'icon': Icons.watch_later_outlined},
    {'q': '¿Salida anticipada del docente?', 'a': 'Debe tener pase de salida firmado por Dirección. El grupo no sale antes salvo indicación oficial.', 'c': 'Académica', 'icon': Icons.exit_to_app_outlined},
    {'q': '¿Ingreso de padres al aula?', 'a': 'Prohibido durante clase. Deben esperar en recepción a que el docente tenga hora libre o cita.', 'c': 'Académica', 'icon': Icons.family_restroom_outlined},
    {'q': '¿Uso de biblioteca por grupo?', 'a': 'El docente debe acompañar al grupo y supervisar el silencio y cuidado de los libros.', 'c': 'Académica', 'icon': Icons.menu_book_outlined},
    {'q': '¿Evaluaciones extemporáneas?', 'a': 'Solo con justificante autorizado por Académica. El docente acuerda la nueva fecha.', 'c': 'Académica', 'icon': Icons.event_repeat_outlined},
    {'q': '¿Cambio de horario semestral?', 'a': 'Se notifica oficialmente. Prefectura debe actualizar las sábanas de horarios en cada aula.', 'c': 'Académica', 'icon': Icons.calendar_month_outlined},
    {'q': '¿Reporte de mobiliario por docente?', 'a': 'Si nota butacas rotas al inicio de clase, debe reportarlo para no ser responsabilizado.', 'c': 'Académica', 'icon': Icons.chair_alt_outlined},
    {'q': '¿Actividades fuera del aula?', 'a': 'Ensayos o prácticas en canchas requieren permiso escrito para no contar como inasistencia.', 'c': 'Académica', 'icon': Icons.nature_people_outlined},
    {'q': '¿Prohibición de venta a alumnos?', 'a': 'Los docentes no pueden vender folletos, libros o alimentos a los alumnos por reglamento.', 'c': 'Académica', 'icon': Icons.sell_outlined},
    {'q': '¿Uso del celular por docente?', 'a': 'Debe limitarse a emergencias o fines pedagógicos. No usar redes sociales durante la clase.', 'c': 'Académica', 'icon': Icons.mobile_off_outlined},
    {'q': '¿Limpieza del aula al salir?', 'a': 'El docente debe instruir al grupo a dejar limpia el aula (basura en su lugar) al terminar el módulo.', 'c': 'Académica', 'icon': Icons.cleaning_services_outlined},
    {'q': '¿Asistencia a Honores?', 'a': 'Obligatoria para todo el personal docente en turno. Deben acompañar a su grupo.', 'c': 'Académica', 'icon': Icons.flag_outlined},
    {'q': '¿Entrega de Planeaciones?', 'a': 'Los docentes las entregan a Coordinación Académica. Prefectura no recibe documentos pedagógicos.', 'c': 'Académica', 'icon': Icons.topic_outlined},
    {'q': '¿Visitas de supervisión áulica?', 'a': 'El personal directivo puede entrar a observar clase sin previo aviso. Prefectura apoya si se solicita.', 'c': 'Académica', 'icon': Icons.visibility_outlined},
    {'q': '¿Concursos académicos externos?', 'a': 'Los alumnos seleccionados tienen justificación automática. Coordinación informa la lista oficial.', 'c': 'Académica', 'icon': Icons.emoji_events_outlined},
    {'q': '¿Reprobación masiva de grupo?', 'a': 'Si más del 50% reprueba, se cita al docente y padres para analizar estrategias de recuperación.', 'c': 'Académica', 'icon': Icons.group_off_outlined},
    {'q': '¿Horarios de asesorías?', 'a': 'Los docentes tienen horas de descarga para asesorar. El alumno debe agendar en sala de maestros.', 'c': 'Académica', 'icon': Icons.help_center_outlined},
    {'q': '¿Semana de la Ciencia/Cultura?', 'a': 'Se suspenden clases regulares por actividades. Prefectura controla asistencia en los eventos.', 'c': 'Académica', 'icon': Icons.biotech_outlined},
    {'q': '¿Funciones del Jefe de Grupo?', 'a': 'Enlace oficial docente-alumnos. Reporta ausencias del maestro y cuida la disciplina inicial.', 'c': 'Académica', 'icon': Icons.badge_outlined},
    {'q': '¿Becas de Excelencia?', 'a': 'Basadas en promedio. Académica publica el ranking. Prefectura no gestiona el trámite, solo informa.', 'c': 'Académica', 'icon': Icons.star_outline_outlined},
    {'q': '¿Quejas por acoso docente?', 'a': 'Protocolo de máxima prioridad. Se levanta acta confidencial y se turna a jurídico inmediato.', 'c': 'Académica', 'icon': Icons.back_hand_outlined},
    {'q': '¿Cambio de docente asignado?', 'a': 'Solo por causas de fuerza mayor (salud, renuncia). No se cambia por petición de alumnos.', 'c': 'Académica', 'icon': Icons.switch_account_outlined},

    // --- 3. ROL: ADMINISTRATIVO (30 Preguntas) ---
    {'q': '¿Dónde se pagan los trámites?', 'a': 'Únicamente en la Caja del plantel o vía depósito bancario referenciado. No recibir efectivo en prefectura.', 'c': 'Administrativo', 'icon': Icons.attach_money_outlined},
    {'q': '¿Trámite de Constancias de Estudio?', 'a': 'El alumno la solicita en Control Escolar con 2 días de anticipación y fotos tamaño infantil.', 'c': 'Administrativo', 'icon': Icons.description_outlined},
    {'q': '¿Alta en Seguro Facultativo (IMSS)?', 'a': 'Es un derecho del alumno. Se gestiona en Servicios Escolares al inicio del semestre con su CURP.', 'c': 'Administrativo', 'icon': Icons.health_and_safety_outlined},
    {'q': '¿Reporte de fallas de mantenimiento?', 'a': 'Avisar a la Administración (Aires acondicionados, luces, baños). Usar el formato de requisición de servicio.', 'c': 'Administrativo', 'icon': Icons.build_outlined},
    {'q': '¿Gestión de Becas Benito Juárez?', 'a': 'El plantel solo valida matrícula. Todo trámite de cobro es directo entre el alumno y la plataforma federal.', 'c': 'Administrativo', 'icon': Icons.school_outlined},
    {'q': '¿Procedimiento de Baja Temporal?', 'a': 'El tutor debe firmar la solicitud en Dirección. El alumno deja de aparecer en listas tras la actualización.', 'c': 'Administrativo', 'icon': Icons.person_remove_outlined},
    {'q': '¿Solicitud de insumos (Papelería)?', 'a': 'Llenar vale de salida en almacén. Solo para uso oficial de las actividades de prefectura.', 'c': 'Administrativo', 'icon': Icons.inventory_2_outlined},
    {'q': '¿Horario de atención a padres?', 'a': 'De 8:00 AM a 2:00 PM previa cita. Los padres no deben interrumpir clases para hablar con docentes.', 'c': 'Administrativo', 'icon': Icons.schedule_send_outlined},
    {'q': '¿Entrega de Boletas?', 'a': 'Se realiza en reunión bimestral con padres. No se entregan a alumnos salvo autorización escrita.', 'c': 'Administrativo', 'icon': Icons.file_copy_outlined},
    {'q': '¿Duplicado de certificado?', 'a': 'Trámite con costo estatal. Tarda de 15 a 30 días hábiles. Requiere acta de extravío.', 'c': 'Administrativo', 'icon': Icons.copy_all_outlined},
    {'q': '¿Servicio Social?', 'a': 'Obligatorio en 5to semestre (480 hrs). Se gestiona en Vinculación. Sin él no hay certificado.', 'c': 'Administrativo', 'icon': Icons.volunteer_activism_outlined},
    {'q': '¿Cambio de turno?', 'a': 'Sujeto a cupo y promedio. Se solicita al final del semestre en Control Escolar.', 'c': 'Administrativo', 'icon': Icons.compare_arrows_outlined},
    {'q': '¿Reinscripción extemporánea?', 'a': 'Genera recargos. Depende de la disponibilidad de sistema y autorización del Director.', 'c': 'Administrativo', 'icon': Icons.warning_amber_outlined},
    {'q': '¿Quejas sobre personal?', 'a': 'Se presentan por escrito en Dirección. Se garantiza anonimato si se requiere.', 'c': 'Administrativo', 'icon': Icons.feedback_outlined},
    {'q': '¿Seguro de vida escolar?', 'a': 'Cubre accidentes en trayecto casa-escuela y dentro del plantel. Reportar inmediato a Dirección.', 'c': 'Administrativo', 'icon': Icons.security_update_good_outlined},
    {'q': '¿Préstamo de instalaciones?', 'a': 'Auditorio o canchas para externos requieren pago de cuota de recuperación y contrato.', 'c': 'Administrativo', 'icon': Icons.stadium_outlined},
    {'q': '¿Acceso a vehículos?', 'a': 'Solo personal autorizado con tarjetón. Alumnos no pueden meter vehículos al plantel.', 'c': 'Administrativo', 'icon': Icons.directions_car_outlined},
    {'q': '¿Vendedores externos?', 'a': 'Prohibida la entrada. Solo concesionarios de cafetería tienen permiso de venta.', 'c': 'Administrativo', 'icon': Icons.block_outlined},
    {'q': '¿Sanitización de aulas?', 'a': 'Programa periódico de intendencia. Reportar aula sucia en Administración.', 'c': 'Administrativo', 'icon': Icons.cleaning_services_outlined},
    {'q': '¿Inventario de aula?', 'a': 'Al inicio de ciclo se firma resguardo. Al final se coteja. Faltantes se cobran al grupo responsable.', 'c': 'Administrativo', 'icon': Icons.checklist_outlined},
    {'q': '¿Cuotas voluntarias?', 'a': 'Se gestionan a través de la Asociación de Padres. El personal del plantel no maneja este dinero.', 'c': 'Administrativo', 'icon': Icons.monetization_on_outlined},
    {'q': '¿Facturación de pagos?', 'a': 'Solicitar en Caja al momento del pago. Se requiere constancia de situación fiscal actualizada.', 'c': 'Administrativo', 'icon': Icons.receipt_long_outlined},
    {'q': '¿Acceso de proveedores?', 'a': 'Por la entrada de servicio. Deben registrarse en bitácora de vigilancia con identificación.', 'c': 'Administrativo', 'icon': Icons.local_shipping_outlined},
    {'q': '¿Auditorías internas?', 'a': 'El Órgano de Control realiza revisiones periódicas. Toda documentación debe estar archivada y lista.', 'c': 'Administrativo', 'icon': Icons.find_in_page_outlined},
    {'q': '¿Plan de Protección Civil?', 'a': 'Responsabilidad administrativa. Prefectura ejecuta los simulacros, Admin gestiona señalética.', 'c': 'Administrativo', 'icon': Icons.health_and_safety_outlined},
    {'q': '¿Días económicos del personal?', 'a': 'Derecho laboral. Se solicitan con 72 hrs de antelación en Recursos Humanos.', 'c': 'Administrativo', 'icon': Icons.event_available_outlined},
    {'q': '¿Incapacidades médicas?', 'a': 'Entregar copia de la licencia médica del ISSSTE en RH máximo 48 hrs después de la expedición.', 'c': 'Administrativo', 'icon': Icons.medical_information_outlined},
    {'q': '¿Permisos de paternidad?', 'a': 'Acorde a la ley vigente. Tramitar en Administrativo con el acta de nacimiento.', 'c': 'Administrativo', 'icon': Icons.baby_changing_station_outlined},
    {'q': '¿Trámite de jubilación?', 'a': 'Se inicia en oficinas centrales. El plantel expide la hoja de servicios cuando se solicita.', 'c': 'Administrativo', 'icon': Icons.elderly_outlined},
    {'q': '¿Representante Sindical?', 'a': 'Enlace para conflictos laborales. La oficina administrativa mantiene relación institucional.', 'c': 'Administrativo', 'icon': Icons.groups_2_outlined},

    // --- 4. ROL: PREFECTURA (30 Preguntas) ---
    {'q': '¿Cuándo debo pasar lista?', 'a': 'En los primeros 15 minutos de cada módulo. Es vital para la estadística de "Alumnos en Plantel".', 'c': 'Prefectura', 'icon': Icons.checklist_rtl_outlined},
    {'q': '¿Cómo reportar una incidencia grave?', 'a': 'Usar el botón rojo "Reportar Incidencia" en la App. Adjuntar foto si es posible (daños/evidencia).', 'c': 'Prefectura', 'icon': Icons.report_problem_outlined},
    {'q': '¿Protocolo de sismo/incendio?', 'a': 'Liderar evacuación del edificio asignado. Verificar que nadie quede en aulas o baños. Dirigir al punto de reunión.', 'c': 'Prefectura', 'icon': Icons.warning_amber_outlined},
    {'q': '¿Puedo justificar faltas?', 'a': 'No. El prefecto registra la falta. Solo el Administrativo cambia el estatus a "Justificado" con documento.', 'c': 'Prefectura', 'icon': Icons.edit_off_outlined},
    {'q': '¿Guardias en receso?', 'a': 'Vigilar puntos ciegos (baños, traspatio). Dispersar aglomeraciones inusuales y prevenir bullying.', 'c': 'Prefectura', 'icon': Icons.security_outlined},
    {'q': '¿Manejo de objetos perdidos?', 'a': 'Resguardar en oficina de prefectura, anotar en bitácora (fecha/descripción). No entregar sin identificar propiedad.', 'c': 'Prefectura', 'icon': Icons.find_in_page_outlined},
    {'q': '¿Uso del radio/comunicación?', 'a': 'Canal 1 para general, Canal 2 para emergencias. Lenguaje breve y claro. Claves de seguridad vigentes.', 'c': 'Prefectura', 'icon': Icons.radio_outlined},
    {'q': '¿Mi horario y asistencia?', 'a': 'Registrar entrada y salida biométrica en Dirección. Portar chaleco/gafete distintivo siempre.', 'c': 'Prefectura', 'icon': Icons.access_time_filled_outlined},
    {'q': '¿Revisión de uniformes?', 'a': 'Diaria en la entrada. Anotar nombres de infractores. 3 reportes = citatorio a padres.', 'c': 'Prefectura', 'icon': Icons.accessibility_new_outlined},
    {'q': '¿Entrada de alumnos tarde?', 'a': 'Registrar en bitácora de retardos. Si es frecuente, hablar con el alumno. No negar acceso (derecho a educación) pero reportar.', 'c': 'Prefectura', 'icon': Icons.lock_open_outlined},
    {'q': '¿Alumnos enfermos en aula?', 'a': 'Retirar del grupo, llevar a zona ventilada, tomar temperatura y llamar al tutor. No medicar.', 'c': 'Prefectura', 'icon': Icons.medication_liquid_outlined},
    {'q': '¿Conflicto con docente?', 'a': 'Actuar como mediador neutral. No desautorizar al docente frente al grupo. Reportar a Dirección.', 'c': 'Prefectura', 'icon': Icons.handshake_outlined},
    {'q': '¿Uso de "Asistencia Masiva"?', 'a': 'Solo al final del día. Marca salida a todos los que entraron. Ahorra tiempo en la salida general.', 'c': 'Prefectura', 'icon': Icons.groups_outlined},
    {'q': '¿Bitácora de novedades?', 'a': 'Llenado obligatorio al final del turno. Reportar anomalías, visitas y pendientes para el siguiente turno.', 'c': 'Prefectura', 'icon': Icons.book_outlined},
    {'q': '¿Control de llaves?', 'a': 'No prestar llaves de aulas a alumnos. Solo al jefe de grupo bajo resguardo o al docente.', 'c': 'Prefectura', 'icon': Icons.vpn_key_outlined},
    {'q': '¿Permisos de baño?', 'a': 'Controlar que no salgan más de 2 alumnos por grupo simultáneamente. Usar pase de pasillo.', 'c': 'Prefectura', 'icon': Icons.wc_outlined},
    {'q': '¿Detección de drogas/armas?', 'a': 'Código Rojo. Aislar zona, no tocar evidencia, llamar a Dirección y Seguridad Pública. Discreción total.', 'c': 'Prefectura', 'icon': Icons.policy_outlined},
    {'q': '¿Apoyo en eventos cívicos?', 'a': 'Organizar filas, vigilar disciplina y silencio. Controlar salida ordenada al terminar.', 'c': 'Prefectura', 'icon': Icons.flag_circle_outlined},
    {'q': '¿Padres agresivos?', 'a': 'Mantener la calma, no discutir. Dirigirlos a Dirección. Si hay riesgo, solicitar apoyo de seguridad.', 'c': 'Prefectura', 'icon': Icons.record_voice_over_outlined},
    {'q': '¿Falla de mi celular/App?', 'a': 'Usar formatos impresos de emergencia. Capturar datos en sistema en cuanto sea posible.', 'c': 'Prefectura', 'icon': Icons.phonelink_erase_outlined},
    {'q': '¿Reporte anónimo?', 'a': 'Si un alumno denuncia algo grave en secreto, proteger su identidad y canalizar directo a Orientación.', 'c': 'Prefectura', 'icon': Icons.visibility_off_outlined},
    {'q': '¿Manejo del estrés?', 'a': 'Si la situación te rebasa, solicita relevo temporal a tu coordinador. La salud mental es prioridad.', 'c': 'Prefectura', 'icon': Icons.self_improvement_outlined},
    {'q': '¿Capacitación constante?', 'a': 'Asistir a cursos de Derechos Humanos y Primeros Auxilios cuando el colegio convoque.', 'c': 'Prefectura', 'icon': Icons.model_training_outlined},
    {'q': '¿Botiquín de primeros auxilios?', 'a': 'Verificar existencias semanalmente. Solicitar reposición de gasas/alcohol a Administración.', 'c': 'Prefectura', 'icon': Icons.medical_services_outlined},
    {'q': '¿Legalidad de revisión mochilas?', 'a': 'Siempre con presencia de padres o comité. Nunca meter mano, pedir al alumno que saque las cosas.', 'c': 'Prefectura', 'icon': Icons.balance_outlined},
    {'q': '¿Trato con prensa/externos?', 'a': 'No dar declaraciones. Remitir cualquier entrevista a la Dirección del plantel.', 'c': 'Prefectura', 'icon': Icons.mic_off_outlined},
    {'q': '¿Confidencialidad de datos?', 'a': 'Prohibido compartir teléfonos o direcciones de alumnos con terceros ajenos a la institución.', 'c': 'Prefectura', 'icon': Icons.folder_shared_outlined},
    {'q': '¿Cámaras de vigilancia?', 'a': 'Solo Dirección tiene acceso a grabaciones. Solicitar revisión por escrito con hora exacta.', 'c': 'Prefectura', 'icon': Icons.videocam_outlined},
    {'q': '¿Apoyo a intendencia?', 'a': 'Reportar zonas sucias. No es función del prefecto limpiar, pero sí gestionar que se haga.', 'c': 'Prefectura', 'icon': Icons.cleaning_services_outlined},
    {'q': '¿Evaluación de desempeño?', 'a': 'Semestral. Se evalúa puntualidad, manejo de grupos y uso correcto de la App.', 'c': 'Prefectura', 'icon': Icons.assessment_outlined},

    // --- 5. ROL: SISTEMA (30 Preguntas) ---
    {'q': '¿Qué hago si no tengo internet?', 'a': 'La App entra en "Modo Offline". Sigue trabajando normal. Los datos se subirán solos al conectar WiFi.', 'c': 'Sistema', 'icon': Icons.wifi_off_outlined},
    {'q': '¿Error "Credencial Inválida"?', 'a': 'Limpia la cámara. Si persiste, busca al alumno por nombre/matrícula manual. Reporta el QR dañado.', 'c': 'Sistema', 'icon': Icons.qr_code_scanner_outlined},
    {'q': '¿Cómo actualizo la lista de alumnos?', 'a': 'Ve a "Gestión de Grupos" y desliza hacia abajo (Pull-to-refresh) para bajar los últimos cambios.', 'c': 'Sistema', 'icon': Icons.system_update_outlined},
    {'q': '¿Olvido de contraseña personal?', 'a': 'Usa la opción "Recuperar Contraseña" en el Login o pide al Admin de TI que resetee tu acceso.', 'c': 'Sistema', 'icon': Icons.lock_reset_outlined},
    {'q': '¿La App está muy lenta?', 'a': 'Cierra otras aplicaciones. Ve a Ajustes del teléfono -> Apps -> Asystem -> Borrar Caché.', 'c': 'Sistema', 'icon': Icons.speed_outlined},
    {'q': '¿Puedo instalarla en mi iPhone?', 'a': 'Sí. Abre Safari, entra a la web y dale a "Compartir" -> "Agregar a Inicio". Funciona como App nativa.', 'c': 'Sistema', 'icon': Icons.apple_outlined},
    {'q': '¿Seguridad de los datos?', 'a': 'Toda la info viaja encriptada. No compartir tu contraseña con alumnos ni otros docentes.', 'c': 'Sistema', 'icon': Icons.security_outlined},
    {'q': '¿Soporte Técnico directo?', 'a': 'Envía captura de pantalla del error al correo soporte@cobacam.edu.mx o vía WhatsApp al TI del plantel.', 'c': 'Sistema', 'icon': Icons.support_agent_outlined},
    {'q': '¿Significado de icono nube roja?', 'a': 'Indica "Sin Conexión". Tienes datos pendientes de subir. No cierres sesión hasta que se ponga verde.', 'c': 'Sistema', 'icon': Icons.cloud_off_outlined},
    {'q': '¿Cómo cerrar sesión seguramente?', 'a': 'Menú lateral -> Cerrar Sesión. Confirma que la nube esté verde antes de hacerlo para no perder datos.', 'c': 'Sistema', 'icon': Icons.logout_outlined},
    {'q': '¿Modo Oscuro?', 'a': 'La App detecta el tema de tu sistema. Activa "Modo Oscuro" en tu Android/iOS para descansar la vista.', 'c': 'Sistema', 'icon': Icons.dark_mode_outlined},
    {'q': '¿Exportar reportes a Excel?', 'a': 'Disponible en panel Web o Tablet. En celular solo visualización por tamaño de pantalla.', 'c': 'Sistema', 'icon': Icons.table_view_outlined},
    {'q': '¿Notificaciones no llegan?', 'a': 'Verifica permisos de la App. Asegúrate de no tener activado "No Molestar" o ahorro de batería estricto.', 'c': 'Sistema', 'icon': Icons.notifications_off_outlined},
    {'q': '¿Actualización de la App?', 'a': 'En Web es automática. En Android, si sale aviso "Nueva Versión", acepta descargar e instalar el APK.', 'c': 'Sistema', 'icon': Icons.update_outlined},
    {'q': '¿Error "Usuario Bloqueado"?', 'a': 'Ocurre tras 5 intentos fallidos de login. Espera 30 minutos o pide desbloqueo manual a TI.', 'c': 'Sistema', 'icon': Icons.lock_clock_outlined},
    {'q': '¿Puedo usarla en dos dispositivos?', 'a': 'Sí, pero se recomienda cerrar sesión en uno para evitar conflictos de sincronización de datos.', 'c': 'Sistema', 'icon': Icons.devices_outlined},
    {'q': '¿Fotos no cargan?', 'a': 'Posible internet lento. Las imágenes pesan. Verifica tu conexión WiFi o datos 4G.', 'c': 'Sistema', 'icon': Icons.image_not_supported_outlined},
    {'q': '¿Registro de huella dactilar?', 'a': 'Si tu celular lo soporta, puedes activar "Login Biométrico" en Ajustes de la App para entrar rápido.', 'c': 'Sistema', 'icon': Icons.fingerprint_outlined},
    {'q': '¿Permisos de cámara denegados?', 'a': 'Ve a Ajustes -> Aplicaciones -> Asystem -> Permisos -> Cámara -> Permitir siempre.', 'c': 'Sistema', 'icon': Icons.camera_alt_outlined},
    {'q': '¿Borrar datos locales?', 'a': 'Solo si TI lo indica. Borrará los registros offline no subidos. Usar con extrema precaución.', 'c': 'Sistema', 'icon': Icons.delete_forever_outlined},
    {'q': '¿Eliminar mi cuenta?', 'a': 'Por seguridad, solo el Admin General puede dar de baja cuentas. Solicítalo por escrito.', 'c': 'Sistema', 'icon': Icons.no_accounts_outlined},
    {'q': '¿Política de Privacidad?', 'a': 'Disponible en el menú "Ajustes". Detalla el uso exclusivo académico de los datos.', 'c': 'Sistema', 'icon': Icons.privacy_tip_outlined},
    {'q': '¿Qué son las cookies?', 'a': 'Archivos temporales para mantener tu sesión activa. Deben estar habilitadas en tu navegador.', 'c': 'Sistema', 'icon': Icons.cookie_outlined},
    {'q': '¿Diferencia Web vs App?', 'a': 'La Web es para pantallas grandes (reportes). La App Móvil es para escaneo rápido y portabilidad.', 'c': 'Sistema', 'icon': Icons.compare_outlined},
    {'q': '¿Notificaciones Push fallidas?', 'a': 'A veces Google Play Services tarda. Abre la app para forzar la actualización de avisos.', 'c': 'Sistema', 'icon': Icons.notifications_paused_outlined},
    {'q': '¿Modo Avión interrumpe?', 'a': 'Sí, corta la subida de datos. La App pasará a modo offline hasta que restablezcas la red.', 'c': 'Sistema', 'icon': Icons.airplanemode_active_outlined},
    {'q': '¿Sincronización lenta?', 'a': 'Si tienes muchos alumnos, puede tardar. Mantén la pantalla encendida mientras la nube gira.', 'c': 'Sistema', 'icon': Icons.sync_problem_outlined},
    {'q': '¿Exportar a PDF?', 'a': 'Usa el botón "Imprimir" en reportes web y selecciona "Guardar como PDF" en el destino.', 'c': 'Sistema', 'icon': Icons.picture_as_pdf_outlined},
    {'q': '¿Imprimir desde celular?', 'a': 'Requiere impresora WiFi configurada en tu red local y el plugin de servicio de impresión.', 'c': 'Sistema', 'icon': Icons.print_outlined},
    {'q': '¿Contacto con desarrollador?', 'a': 'Sugerencias de mejora se envían al correo dev@cobacam.edu.mx. Feedback bienvenido.', 'c': 'Sistema', 'icon': Icons.developer_mode_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredList = _faqList.where((item) {
      final q = item['q'].toString().toLowerCase();
      final a = item['a'].toString().toLowerCase();
      final s = _searchQuery.toLowerCase();
      
      final matchesSearch = q.contains(s) || a.contains(s);
      final matchesCategory = _selectedCategory == 'Todas' || item['c'] == _selectedCategory;
      
      return matchesSearch && matchesCategory;
    }).toList();

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // HEADER BUSCADOR
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05), 
                  blurRadius: 10, 
                  offset: const Offset(0, 4)
                )
              ],
            ),
            child: Column(
              children: [
                // SEARCH BAR
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar en el manual operativo...',
                    prefixIcon: Icon(Icons.search_rounded, color: theme.primaryColor),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: Colors.grey),
                          tooltip: 'Borrar búsqueda',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          })
                      : null,
                    filled: true,
                    fillColor: isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), 
                      borderSide: BorderSide.none
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                // CATEGORY CHIPS
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _selectedCategory = cat),
                          selectedColor: theme.primaryColor.withOpacity(0.2),
                          checkmarkColor: theme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                          ),
                          backgroundColor: isDark ? null : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20), 
                            side: BorderSide(color: isSelected ? theme.primaryColor : Colors.grey.withOpacity(0.2))
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // LISTA DE PREGUNTAS
          Expanded(
            child: filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.manage_search_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No se encontraron resultados para\n"$_searchQuery"', 
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey)
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: (index * 30).clamp(0, 500)), 
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(item['c']).withOpacity(0.1),
                                shape: BoxShape.circle
                              ),
                              child: Icon(item['icon'], color: _getCategoryColor(item['c']), size: 22),
                            ),
                            title: Text(
                              item['q'],
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(item['c']).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6)
                                    ),
                                    child: Text(
                                      item['c'].toUpperCase(),
                                      style: TextStyle(color: _getCategoryColor(item['c']), fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black12 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.withOpacity(0.1))
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 20, color: theme.primaryColor),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item['a'],
                                        style: TextStyle(fontSize: 14, height: 1.5, color: theme.textTheme.bodyMedium?.color),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Alumnos': return Colors.blue;
      case 'Académica': return Colors.teal;
      case 'Administrativo': return Colors.orange;
      case 'Prefectura': return Colors.indigo;
      case 'Sistema': return Colors.purple;
      default: return Colors.grey;
    }
  }
}