// lib/presentation/screens/risks/risk_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/risk_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/risk_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';


class RiskDetailScreen extends StatefulWidget {
  final Risk risk;
  const RiskDetailScreen({super.key, required this.risk});

  @override
  State<RiskDetailScreen> createState() => _RiskDetailScreenState();
}

class _RiskDetailScreenState extends State<RiskDetailScreen> {

  void _showImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.file(File(imagePath)),
              ),
              IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, color: Colors.white),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAssignAuditorDialog(BuildContext context) {
    final riskProvider = Provider.of<RiskProvider>(context, listen: false);
    final auditors = riskProvider.auditors;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Asignar a Auditor'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: auditors.length,
              itemBuilder: (context, index) {
                final auditor = auditors[index];
                return ListTile(
                  title: Text(auditor.name),
                  onTap: () {
                    riskProvider.assignRisk(widget.risk.id, auditor);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Riesgo asignado a ${auditor.name}')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _showReturnWithCommentDialog(BuildContext context) {
    final riskProvider = Provider.of<RiskProvider>(context, listen: false);
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Devolver con Comentarios'),
          content: TextField(
            controller: commentController,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notas de Revisión',
              hintText: 'Explica los cambios necesarios...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (commentController.text.isNotEmpty) {
                  riskProvider.updateRiskStatus(
                    widget.risk.id,
                    RiskStatus.open,
                    reviewNotes: commentController.text,
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Riesgo devuelto al auditor con notas.')),
                  );
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateRiskPdf(Risk risk) async {
  final doc = pw.Document();

  // Cargar imágenes (si hay)
  final pwImages = <pw.ImageProvider>[];
  for (final path in risk.imagePaths) {
    try {
      final bytes = await File(path).readAsBytes();
      pwImages.add(pw.MemoryImage(bytes));
    } catch (_) {}
  }

  pw.Widget rowKV(String k, String v) => pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 150,
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                k,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(v, style: pw.TextStyle(color: PdfColors.black)),
            ),
          ],
        ),
      );

  // Cabecera + contenido
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        // CABECERA
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue900,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Reporte de Riesgo",
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: (risk.status == RiskStatus.closed)
                      ? PdfColors.green600
                      : PdfColors.orange600,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  risk.statusText,
                  style: const pw.TextStyle(color: PdfColors.white),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        // DATOS PRINCIPALES
        rowKV('ID:', risk.id),
        rowKV('Título:', risk.title),
        rowKV('Activo Afectado:', risk.asset),
        rowKV('Asignado a:', risk.assignedUserName ?? 'Nadie'),
        rowKV('Nivel de Riesgo:', risk.riskLevel),
        rowKV('Probabilidad:', risk.probability.toString()),
        rowKV('Impacto:', risk.impact.toString()),
        rowKV('Efectividad del Control:', '${(risk.controlEffectiveness * 100).toStringAsFixed(0)}%'),
        rowKV('Riesgo Inherente:', risk.inherentRisk.toString()),
        rowKV('Riesgo Residual:', risk.residualRisk.toStringAsFixed(2)),

        if (risk.reviewNotes?.isNotEmpty ?? false) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            'Notas de Revisión',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(risk.reviewNotes!),
        ],

        if (risk.comment?.isNotEmpty ?? false) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            'Comentarios del Auditor',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(risk.comment!),
        ],

        pw.SizedBox(height: 12),
        pw.Text(
          'Análisis de la IA',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo,
          ),
        ),
        pw.SizedBox(height: 4),

        // ⬇⬇ Reemplaza este Text corto por el análisis completo ⬇⬇
        pw.Text(
          '''Análisis de Riesgo bajo el Marco de Gobierno de TI (COBIT)

        1. Alineación con los Objetivos Estratégicos

        Este riesgo de "Vulnerabilidad crítica en el Firewall" impacta directamente en múltiples objetivos de la organización. Un firewall comprometido no es solo una falla técnica; es una falla en la capacidad de la empresa para garantizar la resiliencia del servicio (un objetivo de TI) y proteger la información de las partes interesadas (un objetivo de negocio). La materialización de este riesgo podría llevar al incumplimiento de normativas de protección de datos (ej. GDPR, Ley de Protección de Datos Personales), resultando en sanciones financieras y un daño significativo a la reputación, lo cual afecta directamente la continuidad del negocio y la confianza del cliente.

        2. Análisis de Fallo en los Procesos de Gobierno y Gestión

        La existencia de esta vulnerabilidad sin parchar evidencia una debilidad en procesos clave de gestión de TI, específicamente:

        APO12 (Gestionar el Riesgo): El proceso de identificación de riesgos ha funcionado, pero el proceso de respuesta y mitigación está fallando en agilidad. El riesgo residual actual de 3.0 es inaceptable para un activo tan crítico.

        BAI03 (Gestionar Soluciones de Identificación y Construcción): La falta de una política de gestión de parches robusta indica una deficiencia en el ciclo de vida de la gestión de activos de TI. No se está asegurando que los componentes de la infraestructura se mantengan en un estado seguro y soportado.

        DSS05 (Gestionar los Servicios de Seguridad): Aunque existen controles compensatorios (IPS), la dependencia de estos sin corregir la causa raíz (firmware desactualizado) no es una postura de seguridad sostenible y demuestra una falta de madurez en la gestión de la seguridad perimetral.

        3. Recomendaciones Orientadas al Gobierno y la Mejora Continua

        Las recomendaciones deben ir más allá de la solución técnica para fortalecer la estructura de gobierno y evitar la recurrencia del problema.

        Acción Inmediata (Tratamiento del Riesgo): Aplicar el parche de seguridad es el tratamiento de riesgo obvio y debe ejecutarse de forma prioritaria. Esta acción debe ser registrada y supervisada por el propietario del riesgo designado (probablemente el Gerente de Infraestructura), con un seguimiento por parte del CISO o el comité de riesgos de TI.

        Acción Táctica (Mejora del Proceso): Se debe formalizar e implementar una Política de Gestión de Parches y Vulnerabilidades para toda la organización. Esta política debe definir plazos máximos (SLAs) para la aplicación de parches basados en la criticidad de la vulnerabilidad y del activo, alineándose con el apetito de riesgo definido por la dirección. La efectividad de este proceso debe medirse a través de métricas clave (KPIs), como el "tiempo medio para parchear vulnerabilidades críticas".

        Acción Estratégica (Fortalecimiento del Gobierno): El Comité de Riesgos de TI debe revisar este incidente como un caso de estudio para evaluar si los recursos asignados a la gestión de la seguridad son adecuados. Además, se debe asegurar que el inventario de activos de TI (proceso BAI09) esté actualizado y clasificado correctamente según su criticidad para el negocio, garantizando que los activos más importantes reciban la máxima prioridad en los ciclos de parcheo.
        ''',
          textAlign: pw.TextAlign.justify,
          style: pw.TextStyle(
            fontSize: 11,
            lineSpacing: 2, // interlineado suave
          ),
        ),
        // ⬆⬆ Aquí termina el reemplazo ⬆⬆


        if (pwImages.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Evidencia Fotográfica',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pwImages
                .map(
                  (img) => pw.Container(
                    width: 120,
                    height: 90,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Image(img, fit: pw.BoxFit.cover),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    ),
  );

  // COMPARTIR (ya no imprime)
  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'reporte_riesgo_${risk.id}.pdf',
  );
}



  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final riskProvider = Provider.of<RiskProvider>(context);
    final currentRisk = riskProvider.risks.firstWhere((r) => r.id == widget.risk.id, orElse: () => widget.risk);
    final isManager = currentUser?.role == UserRole.gerenteAuditoria || currentUser?.role == UserRole.socioAuditoria;
    final isSeniorAuditor = currentUser?.role == UserRole.auditorSenior;
    final isAssignedAuditor = currentUser?.id == currentRisk.assignedUserId;

    return Scaffold(
      appBar: AppBar(title: Text(currentRisk.title)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(context, 'Activo Afectado:', currentRisk.asset),
                  _buildDetailRow(context, 'Estado:', currentRisk.statusText),
                  _buildDetailRow(context, 'Asignado a:', currentRisk.assignedUserName ?? 'Nadie'),
                  _buildDetailRow(context, 'Nivel de Riesgo:', currentRisk.riskLevel),
                  _buildDetailRow(context, 'Riesgo Inherente:', currentRisk.inherentRisk.toString()),
                  _buildDetailRow(context, 'Riesgo Residual:', currentRisk.residualRisk.toStringAsFixed(2)),
                  if (currentRisk.reviewNotes?.isNotEmpty ?? false) ...[
                    const Divider(height: 32),
                    Text('Notas de la Última Revisión:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200)
                      ),
                      child: Text(currentRisk.reviewNotes!, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                  if (currentRisk.comment?.isNotEmpty ?? false) ...[
                    const Divider(height: 32),
                    Text('Comentarios del Auditor', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(currentRisk.comment!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (currentRisk.imagePaths.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text('Evidencia Fotográfica', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: currentRisk.imagePaths.map((path) {
                        return GestureDetector(
                          onTap: () => _showImageDialog(context, path),
                          child: ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (isAssignedAuditor) ...[
           // ▼▼▼ SECCIÓN DE ANÁLISIS DE LA IA ▼▼▼
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Análisis de la IA:',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        child: SelectableText(
                          '''Análisis de Riesgo bajo el Marco de Gobierno de TI (COBIT)

              1. Alineación con los Objetivos Estratégicos

              Este riesgo de "Vulnerabilidad crítica en el Firewall" impacta directamente en múltiples objetivos de la organización. Un firewall comprometido no es solo una falla técnica; es una falla en la capacidad de la empresa para garantizar la resiliencia del servicio (un objetivo de TI) y proteger la información de las partes interesadas (un objetivo de negocio). La materialización de este riesgo podría llevar al incumplimiento de normativas de protección de datos (ej. GDPR, Ley de Protección de Datos Personales), resultando en sanciones financieras y un daño significativo a la reputación, lo cual afecta directamente la continuidad del negocio y la confianza del cliente.

              2. Análisis de Fallo en los Procesos de Gobierno y Gestión

              La existencia de esta vulnerabilidad sin parchar evidencia una debilidad en procesos clave de gestión de TI, específicamente:

              APO12 (Gestionar el Riesgo): El proceso de identificación de riesgos ha funcionado, pero el proceso de respuesta y mitigación está fallando en agilidad. El riesgo residual actual de 3.0 es inaceptable para un activo tan crítico.

              BAI03 (Gestionar Soluciones de Identificación y Construcción): La falta de una política de gestión de parches robusta indica una deficiencia en el ciclo de vida de la gestión de activos de TI. No se está asegurando que los componentes de la infraestructura se mantengan en un estado seguro y soportado.

              DSS05 (Gestionar los Servicios de Seguridad): Aunque existen controles compensatorios (IPS), la dependencia de estos sin corregir la causa raíz (firmware desactualizado) no es una postura de seguridad sostenible y demuestra una falta de madurez en la gestión de la seguridad perimetral.

              3. Recomendaciones Orientadas al Gobierno y la Mejora Continua

              Las recomendaciones deben ir más allá de la solución técnica para fortalecer la estructura de gobierno y evitar la recurrencia del problema.

              Acción Inmediata (Tratamiento del Riesgo): Aplicar el parche de seguridad es el tratamiento de riesgo obvio y debe ejecutarse de forma prioritaria. Esta acción debe ser registrada y supervisada por el propietario del riesgo designado (probablemente el Gerente de Infraestructura), con un seguimiento por parte del CISO o el comité de riesgos de TI.

              Acción Táctica (Mejora del Proceso): Se debe formalizar e implementar una Política de Gestión de Parches y Vulnerabilidades para toda la organización. Esta política debe definir plazos máximos (SLAs) para la aplicación de parches basados en la criticidad de la vulnerabilidad y del activo, alineándose con el apetito de riesgo definido por la dirección. La efectividad de este proceso debe medirse a través de métricas clave (KPIs), como el "tiempo medio para parchear vulnerabilidades críticas".

              Acción Estratégica (Fortalecimiento del Gobierno): El Comité de Riesgos de TI debe revisar este incidente como un caso de estudio para evaluar si los recursos asignados a la gestión de la seguridad son adecuados. Además, se debe asegurar que el inventario de activos de TI (proceso BAI09) esté actualizado y clasificado correctamente según su criticidad para el negocio, garantizando que los activos más importantes reciban la máxima prioridad en los ciclos de parcheo.
              ''',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ▲▲▲ FIN SECCIÓN DE ANÁLISIS DE LA IA ▲▲▲



            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Acciones de Auditor', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    if (currentRisk.status == RiskStatus.open)
                      _buildActionButton(
                        context,
                        title: 'Comenzar Tratamiento',
                        icon: Icons.play_circle_outline,
                        onPressed: () {
                          riskProvider.updateRiskStatus(currentRisk.id, RiskStatus.inProgress);
                        },
                      ),
                    if (currentRisk.status == RiskStatus.inProgress)
                      _buildActionButton(
                        context,
                        title: 'Enviar a Revisión',
                        icon: Icons.send_outlined,
                        color: Colors.orange,
                        onPressed: () {
                          riskProvider.updateRiskStatus(currentRisk.id, RiskStatus.pendingReview);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Riesgo enviado a revisión.')),
                          );
                        },
                      ),
                    if (currentRisk.status == RiskStatus.pendingReview)
                      const Text('Este riesgo está pendiente de revisión por un Auditor Senior.'),
                    if (currentRisk.status == RiskStatus.closed)
                      const Text('Este riesgo ha sido cerrado.'),
                  ],
                ),
              ),
            ),
          ],

          if (isSeniorAuditor && currentRisk.status == RiskStatus.pendingReview) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Acciones de Revisión', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _buildActionButton(
                      context,
                      title: 'Aprobar y Cerrar',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      onPressed: () {
                        riskProvider.updateRiskStatus(currentRisk.id, RiskStatus.closed, reviewNotes: '');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Riesgo aprobado y cerrado.')),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      context,
                      title: 'Devolver con Comentarios',
                      icon: Icons.undo_outlined,
                      color: Colors.redAccent,
                      onPressed: () {
                        _showReturnWithCommentDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Mostrar exportación solo si el riesgo está Cerrado y el usuario es Auditor Senior
          if (isSeniorAuditor && currentRisk.status == RiskStatus.closed) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exportar', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Generar PDF'),
                      onPressed: () => _generateRiskPdf(currentRisk),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          
        ],

        
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
        onPressed: () => _showAssignAuditorDialog(context),
        tooltip: 'Asignar Auditor',
        child: const Icon(Icons.person_add_alt_1),
      )
          : null,
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 16),
          Flexible(child: Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required String title, required IconData icon, Color? color, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}