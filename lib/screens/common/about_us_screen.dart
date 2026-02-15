import 'package:flutter/material.dart';
import 'package:asystem_cobacam/utils/animations.dart'; // Assuming you have an animations utility

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FadeInUp(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    context,
                    title: 'Colegio de Bachilleres del Estado de Campeche (COBACAM)',
                    children: [
                      Center(
                        child: Image.asset('assets/images/logo1.png', height: 100), // Adjust height as needed
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Image.asset('assets/images/logo2.jpg', height: 100), // Adjust height as needed
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'El Colegio de Bachilleres del Estado de Campeche (COBACAM) fue fundado en 1990 por el gobernador Abelardo Carrillo Zavala con el objetivo de satisfacer la demanda de educación media superior en el estado. El primer plantel se abrió ese mismo año en Hecelchakán. Desde entonces, ha crecido a más de 37 planteles y atiende a más de 10,000 estudiantes, contribuyendo significativamente a la educación en Campeche.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(context, 'Lema', 'FORMANDO LAS MENTES DEL MAÑANA'),
                      const SizedBox(height: 16),
                      _buildInfoRow(context, 'Misión',
                          'Formar jóvenes con una educación integral que les permita continuar con su proyecto de vida profesional y laboral, contribuyendo a su bienestar y a la construcción de una sociedad equitativa, incluyente y solidaria.'),
                      _buildInfoRow(context, 'Visión',
                          'Ser una institución líder en el nivel medio superior, que atienda la demanda educativa con excelencia académica, igualdad, equidad, inclusión e interculturalidad.'),
                      _buildInfoRow(context, 'Objetivo Principal',
                          'Impartir e impulsar la educación correspondiente al nivel medio superior, con características de terminal y propedéutica, formando jóvenes con una académica integral y de calidad.'),
                      const SizedBox(height: 16),
                      _buildSectionTitle(context, 'Valores y Principios', theme),
                      _buildValuesList(context, theme, [
                        'Igualdad: Asegurando un trato idéntico para toda la comunidad escolar.',
                        'Inclusión: Fomentando la convivencia y aceptación de la diversidad.',
                        'Solidaridad: Fortaleciendo el compromiso por el bien común.',
                        'Cultura de Paz: Promoviendo el respeto a la vida y la dignidad humana.',
                        'Responsabilidad: Afianzando la conciencia del entorno y los derechos/obligaciones.',
                        'Equidad: Reconociendo y reduciendo las desigualdades por género, etnia, clase o sexualidad.',
                        'Respeto: Fomentando la aceptación de la diversidad étnica, cultural, sexual y biológica.',
                        'Legalidad: Actuando conforme a las leyes y normativas vigentes.',
                        'Integridad: Fomentando la honestidad, transparencia y el buen uso de los recursos.',
                        'Cooperación: Trabajando en equipo para alcanzar metas comunes y el bienestar de la comunidad.'
                      ]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    context,
                    title: 'Historia del Desarrollo del Sistema ASYSTEM',
                    children: [
                      Text(
                        'El sistema ASYSTEM inició su desarrollo en el transcurso de **Mayo - Agosto de 2024** como un proyecto de estadía profesional, impulsado por **dos alumnos de TSU de la UTCAM** (Universidad Tecnológica de Campeche).',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tras un periodo de pausa, el proyecto fue retomado y se ha continuado su evolución hasta la fecha. Actualmente, se encuentra en sus **etapas finales de desarrollo**, con el objetivo de realizar las **primeras pruebas piloto en Marzo de 2026** en el **Plantel 05 Atasta** para el nuevo ciclo escolar.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'La visión a futuro es que, mediante un acuerdo formal, este sistema pueda ser implementado progresivamente en más planteles, o incluso en **todos los planteles del COBACAM**, optimizando así la gestión académica y administrativa a nivel estatal.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle(context, 'Supervisión del Proyecto', theme),
                      _buildInfoRow(context, 'Director del Plantel 05 Atasta', 'Apoyo fundamental en la dirección estratégica y necesidades institucionales.'),
                      _buildInfoRow(context, 'Encargado de Cómputo', 'Asesoramiento técnico y coordinación para la integración tecnológica.'),
                      _buildInfoRow(context, 'Prefecta', 'Orientación sobre los procesos académicos y administrativos del día a día.'),
                      const SizedBox(height: 16), // Add some spacing
                      Text(
                        'La propiedad intelectual y los derechos sobre los códigos fuente, bases de datos y demás componentes del proyecto ASYSTEM pertenecen al Plantel 05 Atasta. El desarrollo fue realizado por el joven Ángel del Carmen González Alcocer, con el apoyo y supervisión de los encargados del plantel. En caso de interés de otros planteles o de la totalidad de los planteles del COBACAM en adoptar el sistema, se establecerá un acuerdo formal para su implementación y uso.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.secondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValuesList(BuildContext context, ThemeData theme, List<String> values) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: values
          .map((value) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        value,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
