import 'package:asystem_cobacam/models/student_model.dart';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';

class CredentialCardContent extends StatelessWidget {
  final Student student;
  final String campus;
  const CredentialCardContent({super.key, required this.student, required this.campus});

  @override
  Widget build(BuildContext context) {
    // Colores Institucionales Profesionales
    const primaryColor = Color(0xFF1B396A); // Azul Marino Institucional
    const accentColor = Color(0xFFD4AF37); // Dorado Metálico
    const bgColor = Color(0xFFF8F9FA); // Blanco Humo

    return Container(
      width: 324, // Adjusted for CR-80 standard (approx 85.6mm at 96dpi)
      height: 204, // Adjusted for CR-80 standard (approx 54mm at 96dpi)
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Stack(
        children: [
          // --- FONDO DECORATIVO ---
          Positioned(
            bottom: -50,
            right: -50,
            child: Opacity(
              opacity: 0.05,
              child: Image.asset('assets/images/logo1.png',
                  width: 250, height: 250),
            ),
          ),

          Column(
            children: [
              // --- HEADER ---
              Container(
                height: 48, // Adjusted height
                padding: const EdgeInsets.symmetric(horizontal: 10), // Adjusted padding
                decoration: const BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: ClipOval(
                          child: Image.asset('assets/images/logo1.png',
                              width: 32, height: 32)), // Adjusted logo size
                    ),
                    const SizedBox(width: 8), // Adjusted spacing
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COLEGIO DE BACHILLERES DEL ESTADO DE CAMPECHE',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 8.0), // Adjusted font size
                            maxLines: 1,
                          ),
                          SizedBox(height: 1),
                          Text(
                            'CREDENCIAL PARA ASISTENCIAS',
                            style: TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold,
                                fontSize: 10.0, // Adjusted font size
                                letterSpacing: 0.5), // Moved inside TextStyle
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- CINTA DORADA SEPARADORA ---
              Container(height: 4, width: double.infinity, color: accentColor),

              // --- CUERPO ---
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Adjusted padding
                  child: Row(
                    children: [
                      // COLUMNA IZQUIERDA: FOTO
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 74, // Adjusted width
                            height: 88, // Adjusted height
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              border: Border.all(color: primaryColor, width: 2),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Icon(
                                (student.gender.toUpperCase().startsWith('F') ||
                                        student.gender
                                            .toUpperCase()
                                            .contains('MUJER'))
                                    ? Icons.woman
                                    : Icons.man,
                                size: 55, // Adjusted icon size
                                color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 4), // Adjusted spacing
                          Text(student.schoolCycle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: primaryColor)),
                          const Text('VIGENCIA',
                              style:
                                  TextStyle(fontSize: 6, color: Colors.grey)),
                        ],
                      ),

                      const SizedBox(width: 14),

                      // COLUMNA DERECHA: DATOS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // NOMBRE DEL ALUMNO
                            Text(
                              student.fullName.toUpperCase(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.1),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                                (student.gender.toUpperCase().startsWith('F') ||
                                        student.gender
                                            .toUpperCase()
                                            .contains('MUJER'))
                                    ? 'ALUMNA'
                                    : 'ALUMNO',
                                style: const TextStyle(
                                    fontSize: 7,
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),

                            const SizedBox(height: 8),

                            // GRID DE DATOS
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _dataField('MATRÍCULA', student.studentId,
                                    primaryColor,
                                    isLarge: true),
                                const SizedBox(width: 12),
                                _dataField(
                                    'GRUPO', student.group, Colors.black87),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _dataField('NSS', student.nss ?? 'N/A',
                                    Colors.black54),
                                const SizedBox(width: 12),
                                _dataField('PLANTEL', campus, Colors.black54),
                              ],
                            ),

                            const SizedBox(height: 6), // Adjusted spacing

                            // CÓDIGO DE BARRAS
                            SizedBox(
                              width: double.infinity,
                              height: 25, // Adjusted height
                              child: BarcodeWidget(
                                barcode: Barcode.code128(),
                                data: student.studentId,
                                drawText: false,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- FOOTER ---
              Container(
                height: 10, // Adjusted height
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataField(String label, String value, Color color,
      {bool isLarge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 6, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(
          value.toUpperCase(),
          style: TextStyle(
              fontSize: isLarge ? 12 : 9,
              fontWeight: FontWeight.bold,
              color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
