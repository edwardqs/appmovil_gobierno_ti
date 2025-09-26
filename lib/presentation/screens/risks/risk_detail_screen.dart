// lib/presentation/screens/risks/risk_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/risk_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/risk_provider.dart';

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
          ]
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