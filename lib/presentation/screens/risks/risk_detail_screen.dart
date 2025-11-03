// lib/presentation/screens/risks/risk_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para rootBundle
import 'package:provider/provider.dart';
import 'dart:convert'; // Necesario para codificación Base64 (imágenes)
import 'package:http/http.dart' as http; // Necesario para llamadas a la API
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/risk_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/risk_provider.dart';
import '../../widgets/common/risk_image_widget.dart';
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
        Usaras el idioma español para responder. No uses ingles ni otro idioma.
        Analiza el siguiente riesgo de TI de forma técnica, estructurada y concisa (máximo 3 párrafos).

        Primero analiza lo que seria el nombre del riesgo, el activo afectado, la probabilidad, el impacto, el nivel de riesgo inherente, la efectividad del control y el riesgo residual estimado. Todo con las imagenes que se te proporcionan. Seguido del comentario del auditor si existe.
        En base a lo anterior, dame soluciones prácticas y alineadas con COBIT para mitigar este riesgo. Pero no debe ser tanto texto, sino un análisis puntual y directo.

        Detalle del riesgo a analizar:

        ${riskDetails.trim()}
        '''
      }
    ];

    // 2.1. Añadir imágenes
    for (final path in risk.imagePaths) {
      try {
        List<int> bytes;
        if (path.startsWith('http://') || path.startsWith('https://')) {
          // Es una URL de Supabase Storage
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
          } else {
            continue; // Saltar esta imagen si no se puede descargar
          }
        } else {
          // Es una ruta local de archivo
          bytes = await File(path).readAsBytes();
        }
        
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
                child: RiskImageWidget(
                  imagePath: imagePath,
                  fit: BoxFit.contain,
                ),
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
    
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: riskProvider.ensureAuditorsLoaded(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                title: Text('Asignar a Auditor'),
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            
            final auditors = riskProvider.auditors;
            
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

  // ▼▼▼ NUEVO MÉTODO: DIÁLOGO PARA CONSULTAS DEL AUDITOR SENIOR ▼▼▼
  void _showSeniorAuditorQueryDialog(BuildContext context) {
    final riskProvider = Provider.of<RiskProvider>(context, listen: false);
    final queryController = TextEditingController();
    String selectedQueryType = 'technical'; // Tipo por defecto

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.question_answer, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text('Consulta del Auditor Senior'),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo de Consulta:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedQueryType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'technical', child: Text('Consulta Técnica')),
                        DropdownMenuItem(value: 'compliance', child: Text('Consulta de Cumplimiento')),
                        DropdownMenuItem(value: 'risk_assessment', child: Text('Evaluación de Riesgo')),
                        DropdownMenuItem(value: 'control_effectiveness', child: Text('Efectividad de Controles')),
                        DropdownMenuItem(value: 'general', child: Text('Consulta General')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedQueryType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Detalle de la Consulta:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: queryController,
                      autofocus: true,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Describe tu consulta específica sobre este riesgo...',
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (queryController.text.isNotEmpty) {
                      try {
                        await riskProvider.addRiskComment(
                          widget.risk.id,
                          queryController.text,
                          type: selectedQueryType,
                        );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Consulta registrada exitosamente.')),
                        );
                        // Refrescar la vista para mostrar el nuevo comentario
                        setState(() {});
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al registrar consulta: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Registrar Consulta'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ▼▼▼ NUEVO MÉTODO: CONSTRUIR TARJETA DE COMENTARIO ▼▼▼
  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final createdAt = DateTime.parse(comment['created_at']);
    final userName = comment['users']?['name'] ?? 'Usuario desconocido';
    final commentType = comment['comment_type'] ?? 'general';
    
    // Mapear tipos de comentario a etiquetas legibles
    final typeLabels = {
      'technical': 'Técnica',
      'compliance': 'Cumplimiento',
      'risk_assessment': 'Evaluación de Riesgo',
      'control_effectiveness': 'Efectividad de Controles',
      'general': 'General',
    };
    
    final typeColors = {
      'technical': Colors.blue,
      'compliance': Colors.orange,
      'risk_assessment': Colors.red,
      'control_effectiveness': Colors.green,
      'general': Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColors[commentType]?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: typeColors[commentType] ?? Colors.grey),
                  ),
                  child: Text(
                    typeLabels[commentType] ?? 'General',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: typeColors[commentType],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment['comment'],
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Por: $userName',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  // ▼▼▼ FUNCIÓN HELPER PARA CARGAR FUENTES UNICODE ▼▼▼
  Future<pw.Font> _getUnicodeFont({bool bold = false}) async {
    try {
      // Usar PdfGoogleFonts directamente para mejor soporte Unicode
      if (bold) {
        return await PdfGoogleFonts.robotoBold();
      } else {
        return await PdfGoogleFonts.robotoRegular();
      }
    } catch (e) {
      debugPrint('Error al cargar fuente Unicode desde Google Fonts: $e');
      
      // Fallback: intentar cargar desde assets si están disponibles
      try {
        final fontData = await rootBundle.load(
          bold ? 'packages/google_fonts/fonts/Roboto-Bold.ttf' : 'packages/google_fonts/fonts/Roboto-Regular.ttf'
        );
        return pw.Font.ttf(fontData);
      } catch (e2) {
        debugPrint('Error al cargar fuente desde assets: $e2');
        
        // Último fallback: usar Times que tiene mejor soporte Unicode que Helvetica
        return bold ? pw.Font.timesBold() : pw.Font.times();
      }
    }
  }

  // ▼▼▼ FUNCIÓN DE PDF MODIFICADA PARA USAR FUENTES UNICODE Y LAYOUT CORREGIDO ▼▼▼
  Future<void> _generateRiskPdf(Risk risk) async {
    // Debug: Verificar si el análisis de IA está presente
    print('🔍 [PDF_DEBUG] Generando PDF para riesgo: ${risk.id}');
    print('🔍 [PDF_DEBUG] Análisis de IA presente: ${risk.aiAnalysis != null}');
    print('🔍 [PDF_DEBUG] Contenido del análisis: ${risk.aiAnalysis?.substring(0, risk.aiAnalysis!.length > 100 ? 100 : risk.aiAnalysis!.length) ?? 'NULL'}...');
    
    final doc = pw.Document();

    // Cargar fuentes Unicode
    final regularFont = await _getUnicodeFont();
    final boldFont = await _getUnicodeFont(bold: true);

    // Función para carga de imágenes
    final pwImages = <pw.ImageProvider>[];
    for (final path in risk.imagePaths) {
      try {
        if (path.startsWith('http://') || path.startsWith('https://')) {
          // Es una URL de Supabase Storage
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            pwImages.add(pw.MemoryImage(response.bodyBytes));
          }
        } else {
          // Es una ruta local de archivo
          final bytes = await File(path).readAsBytes();
          pwImages.add(pw.MemoryImage(bytes));
        }
      } catch (e) {
        debugPrint('Error al cargar imagen para PDF: $e');
      }
    }

    // Función helper para filas clave-valor
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
                font: boldFont,
                fontSize: 10,
                color: PdfColors.blue800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v, 
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 10,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );

    // Crear contenido de la primera página
    final firstPageContent = <pw.Widget>[
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
                font: boldFont,
                color: PdfColors.white,
                fontSize: 18,
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
                style: pw.TextStyle(
                  font: regularFont,
                  color: PdfColors.white,
                  fontSize: 12,
                ),
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
    ];

    // Agregar notas de revisión si existen
    if (risk.reviewNotes?.isNotEmpty ?? false) {
      firstPageContent.addAll([
        pw.SizedBox(height: 12),
        pw.Text(
          'Notas de Revisión',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
            color: PdfColors.orange800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          risk.reviewNotes!,
          style: pw.TextStyle(
            font: regularFont,
            fontSize: 10,
          ),
        ),
      ]);
    }

    // Agregar comentarios del auditor si existen
    if (risk.comment?.isNotEmpty ?? false) {
      firstPageContent.addAll([
        pw.SizedBox(height: 12),
        pw.Text(
          'Comentarios del Auditor',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          risk.comment!,
          style: pw.TextStyle(
            font: regularFont,
            fontSize: 10,
          ),
        ),
      ]);
    }

    // Primera página
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: firstPageContent,
        ),
      ),
    );

    // Segunda página - Análisis de IA (si existe)
    print('🔍 [PDF_DEBUG] Verificando análisis de IA para segunda página...');
    print('🔍 [PDF_DEBUG] risk.aiAnalysis es null: ${risk.aiAnalysis == null}');
    print('🔍 [PDF_DEBUG] risk.aiAnalysis está vacío: ${risk.aiAnalysis?.isEmpty ?? true}');
    
    if (risk.aiAnalysis?.isNotEmpty ?? false) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Análisis de la IA',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                  color: PdfColors.indigo,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                risk.aiAnalysis!,
                textAlign: pw.TextAlign.justify,
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 11,
                  lineSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tercera página - Evidencia fotográfica (si existe)
    if (pwImages.isNotEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Evidencia Fotográfica',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                ),
              ),
              pw.SizedBox(height: 16),
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
          ),
        ),
      );
    }

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
    final isManager = currentUser?.role == UserRole.gerenteAuditoria;
    final isSeniorAuditor = currentUser?.role == UserRole.auditorSenior;
    final isAssignedAuditor = currentUser?.id == currentRisk.assignedUserId;

    // Condición para mostrar el botón de PDF (Auditor Senior O Gerente de Auditoría)
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
                          color: Colors.orange.withValues(alpha: 0.1),
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
                          child: RiskImageWidget(
                            imagePath: path,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
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

          // ▼▼▼ NUEVA SECCIÓN: CONSULTAS DEL AUDITOR SENIOR ▼▼▼
          if (isSeniorAuditor) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.question_answer, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Consultas del Auditor Senior', style: Theme.of(context).textTheme.titleLarge),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildActionButton(
                      context,
                      title: 'Hacer Consulta Específica',
                      icon: Icons.add_comment,
                      color: Colors.blue,
                      onPressed: () {
                        _showSeniorAuditorQueryDialog(context);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Mostrar comentarios existentes
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: riskProvider.getRiskComments(currentRisk.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError) {
                          return Text('Error al cargar comentarios: ${snapshot.error}');
                        }
                        
                        final comments = snapshot.data ?? [];
                        
                        if (comments.isEmpty) {
                          return const Text(
                            'No hay consultas registradas para este riesgo.',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          );
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Historial de Consultas:',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...comments.map((comment) => _buildCommentCard(comment)).toList(),
                          ],
                        );
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
                      onPressed: () {
                        print('🔍 [PDF_DEBUG] Botón PDF presionado');
                        print('🔍 [PDF_DEBUG] currentRisk.id: ${currentRisk.id}');
                        print('🔍 [PDF_DEBUG] currentRisk.aiAnalysis: ${currentRisk.aiAnalysis?.substring(0, (currentRisk.aiAnalysis?.length ?? 0) > 50 ? 50 : (currentRisk.aiAnalysis?.length ?? 0)) ?? 'NULL'}...');
                        _generateRiskPdf(currentRisk);
                      },
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