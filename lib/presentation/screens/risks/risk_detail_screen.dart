// lib/presentation/screens/risks/risk_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert'; // Necesario para codificación Base64 (imágenes)
import 'package:http/http.dart' as http; // Necesario para llamadas a la API
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

  // ▼▼▼ VARIABLES DE ESTADO MODIFICADAS ▼▼▼
  // Solo necesitamos el estado de carga para el botón de análisis
  bool _isAiAnalyzing = false;
  // ▲▲▲ FIN VARIABLES DE ESTADO ▼▼▲

  // EL MÉTODO initState SE HA ELIMINADO para que el análisis no sea automático.

  // ▼▼▼ FUNCIÓN DE LA API MODIFICADA PARA GUARDAR EL RESULTADO ▼▼▼
  Future<void> _fetchAiAnalysis() async {
    if (!mounted || _isAiAnalyzing) return;

    setState(() {
      _isAiAnalyzing = true;
    });

    final riskProvider = Provider.of<RiskProvider>(context, listen: false);
    // Usamos el estado más reciente del riesgo
    final risk = riskProvider.risks.firstWhere((r) => r.id == widget.risk.id, orElse: () => widget.risk);

    String generatedAnalysis = 'Error: No se pudo generar el análisis.';

    // 1. Construcción del Prompt (incluyendo los detalles del riesgo)
    final riskDetails = '''
      Riesgo ID: ${risk.id}
      Título: ${risk.title}
      Activo Afectado: ${risk.asset}
      Probabilidad (1-5): ${risk.probability}
      Impacto (1-5): ${risk.impact}
      Nivel de Riesgo Inherente: ${risk.inherentRisk}
      Efectividad del Control (0.0-1.0): ${risk.controlEffectiveness}
      Riesgo Residual Estimado: ${risk.residualRisk.toStringAsFixed(2)}
      Comentarios del Auditor: ${risk.comment ?? 'No hay comentarios.'}
    ''';

    // 2. Construir la solicitud multimodal (Texto y Imágenes)
    final List<Map<String, dynamic>> parts = [
      {
        "text": '''
        Actúa como un Auditor Senior especializado en Gobierno de TI y Control Interno bajo el marco COBIT. 
        Analiza el siguiente riesgo de TI de forma técnica, estructurada y concisa (máximo 3 párrafos). 
        Tu análisis debe abordar con claridad los siguientes puntos:
  
        1. *Implicación del riesgo:* Explica cómo este riesgo afecta el logro de los objetivos de negocio y de TI, en relación con los principios y dominios del marco COBIT.  
        2. *Evaluación del riesgo residual:* Determina si el riesgo residual es aceptable o no, considerando el nivel de riesgo inherente y la efectividad de los controles existentes.  
        3. *Recomendaciones de mejora:* Propón acciones concretas y priorizadas para fortalecer el Gobierno de TI, mejorar la efectividad del control y reducir la exposición al riesgo.
  
        Sé directo, evita repeticiones o texto genérico. Fundamenta brevemente tus conclusiones en los conceptos de COBIT y buenas prácticas de gestión de riesgos.
        Detalle del riesgo a analizar:

        ${riskDetails.trim()}
        '''
      }
    ];

    // 2.1. Añadir imágenes
    for (final path in risk.imagePaths) {
      try {
        final bytes = await File(path).readAsBytes();
        final base64Image = base64Encode(bytes);
        final mimeType = path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

        parts.add({
          "inlineData": {
            "data": base64Image,
            "mimeType": mimeType,
          }
        });
      } catch (e) {
        debugPrint('Error al procesar imagen para IA: $e');
      }
    }

    final payload = {
      "contents": [
        {"parts": parts}
      ]
    };

    // 3. Llamar a la API
    // **IMPORTANTE: REEMPLAZA ESTA CLAVE CON TU CLAVE REAL**
    const apiKey = 'AIzaSyBVU2vBuRwbu1vv4WajfKzAzW6v1Y-0iaY';
    const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final generatedText = jsonResponse['candidates'][0]['content']['parts'][0]['text'] as String;
        generatedAnalysis = generatedText.trim();

        // 4. PERSISTIR el resultado
        await riskProvider.saveAiAnalysis(risk.id, generatedAnalysis);

      } else {
        generatedAnalysis = 'Error de API (${response.statusCode}): No se pudo obtener el análisis.';
        await riskProvider.saveAiAnalysis(risk.id, generatedAnalysis); // Persistir el error
      }
    } catch (e) {
      generatedAnalysis = 'Error de conexión: Detalle: $e';
      await riskProvider.saveAiAnalysis(risk.id, generatedAnalysis); // Persistir el error
    } finally {
      if (mounted) {
        setState(() {
          _isAiAnalyzing = false;
        });
      }
    }
  }
  // ▲▲▲ FIN FUNCIÓN DE LA API MODIFICADA ▼▼▲

  // El resto de funciones auxiliares (_showImageDialog, _showAssignAuditorDialog, _showReturnWithCommentDialog)
  // deben estar definidas fuera del build, ya sea aquí o en el widget padre si lo prefieres.
  // ... (asume que aquí está el código de las funciones auxiliares)

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

  // ▼▼▼ FUNCIÓN DE PDF MODIFICADA PARA USAR EL CAMPO PERSISTIDO ▼▼▼
  Future<void> _generateRiskPdf(Risk risk) async {
    final doc = pw.Document();

    // Función para carga de imágenes y rowKV (mantenida de la implementación previa)
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

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // CABECERA (mantenida)
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
                  padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          // DATOS PRINCIPALES (mantenidos)
          rowKV('ID:', risk.id),
          rowKV('Título:', risk.title),
          rowKV('Activo Afectado:', risk.asset),
          rowKV('Asignado a:', risk.assignedUserName ?? 'Nadie'),
          rowKV('Nivel de Riesgo:', risk.riskLevel),
          rowKV('Probabilidad:', risk.probability.toString()),
          rowKV('Impacto:', risk.impact.toString()),
          rowKV('Efectividad del Control:',
              '${(risk.controlEffectiveness * 100).toStringAsFixed(0)}%'),
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

          // Reemplazo: Usar el análisis de la IA persistido (risk.aiAnalysis)
          if (risk.aiAnalysis?.isNotEmpty ?? false) ...[
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
            pw.Text(
              risk.aiAnalysis!, // Usa el campo persistido
              textAlign: pw.TextAlign.justify,
              style: pw.TextStyle(
                fontSize: 11,
                lineSpacing: 2,
              ),
            ),
          ],

          // Evidencia (mantenida)
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

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'reporte_riesgo_${risk.id}.pdf',
    );
  }
  // ▲▲▲ FIN FUNCIÓN DE PDF MODIFICADA ▼▼▲


  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final riskProvider = Provider.of<RiskProvider>(context);
    // Usamos .firstWhere para obtener el riesgo más actualizado del provider
    final currentRisk = riskProvider.risks.firstWhere((r) => r.id == widget.risk.id, orElse: () => widget.risk);

    // Definición de roles
    final isManager = currentUser?.role == UserRole.gerenteAuditoria || currentUser?.role == UserRole.socioAuditoria;
    final isSeniorAuditor = currentUser?.role == UserRole.auditorSenior;
    final isAssignedAuditor = currentUser?.id == currentRisk.assignedUserId;

    // Condición para mostrar el botón de PDF (Auditor Senior O Gerente/Socio)
    final canGeneratePdf = isManager || isSeniorAuditor;

    // Condición para mostrar el botón de Análisis (Solo Auditor Asignado Y si no se ha generado)
    final canGenerateAiAnalysis = isAssignedAuditor && (currentRisk.aiAnalysis == null || currentRisk.aiAnalysis!.isEmpty);


    return Scaffold(
      appBar: AppBar(title: Text(currentRisk.title)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            // ... Contenido de la tarjeta principal (Detalles del riesgo)
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

          // ▼▼▼ SECCIÓN DE ANÁLISIS DE LA IA (A DEMANDA Y PERSISTENTE) ▼▼▼
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
                  const SizedBox(height: 16),

                  if (canGenerateAiAnalysis)
                  // Muestra el botón para generar
                    _buildActionButton(
                      context,
                      title: 'Generar Análisis con IA',
                      icon: Icons.auto_awesome_outlined,
                      color: Colors.indigo,
                      onPressed: _isAiAnalyzing ? null : _fetchAiAnalysis,
                    )
                  else if (_isAiAnalyzing)
                  // Muestra el indicador de carga
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Generando análisis de riesgo con IA...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    )
                  else if (currentRisk.aiAnalysis?.isNotEmpty ?? false)
                    // Muestra el análisis guardado
                      SingleChildScrollView(
                        child: SelectableText(
                          currentRisk.aiAnalysis!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      )
                    else
                    // Si no se ha generado y no tiene permiso
                      Text(
                        'El análisis de IA aún no ha sido generado.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),

                  // Opción para regenerar (solo si es auditor asignado y no está en curso)
                  if (isAssignedAuditor && (currentRisk.aiAnalysis?.isNotEmpty ?? false) && !_isAiAnalyzing)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Volver a generar análisis IA'),
                        onPressed: _fetchAiAnalysis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ▲▲▲ FIN SECCIÓN DE ANÁLISIS DE LA IA (A DEMANDA Y PERSISTENTE) ▲▲▲


          // Sección de Acciones de Auditor (se mantiene como estaba)
          if (isAssignedAuditor) ...[
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

          // Sección de Acciones de Revisión (se mantiene como estaba)
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
                      // Se mantiene la lógica de Approve & Close aquí
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

          // ▼▼▼ SECCIÓN DE EXPORTAR (VISIBLE para Manager y Senior Auditor) ▼▼▼
          if (canGeneratePdf) ...[
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
          // ▲▲▲ FIN SECCIÓN DE EXPORTAR (MODIFICADA) ▼▼▲

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

  // Se modificó para aceptar VoidCallback? ya que el botón puede estar deshabilitado (_isAiAnalyzing)
  Widget _buildActionButton(BuildContext context, {required String title, required IconData icon, Color? color, required VoidCallback? onPressed}) {
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