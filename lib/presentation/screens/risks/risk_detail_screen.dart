// Guarda este código en: lib/presentation/screens/risks/risk_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../data/models/risk_model.dart';

class RiskDetailScreen extends StatelessWidget {
  final Risk risk;

  const RiskDetailScreen({super.key, required this.risk});

  // El método para mostrar la imagen en un diálogo se mantiene igual
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La AppBar ahora es translúcida y el contenido pasa por debajo
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.zero, // Quitamos el padding para el encabezado
        children: [
          _buildHeader(context),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildValuationCard(context),
                const SizedBox(height: 16),
                if (risk.comment?.isNotEmpty ?? false)
                  _buildTitledCard(
                    context,
                    title: 'Comentarios del Auditor',
                    child: Text(risk.comment!, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                const SizedBox(height: 16),
                if (risk.imagePaths.isNotEmpty)
                  _buildTitledCard(
                    context,
                    title: 'Evidencia Fotográfica',
                    child: _buildImageGrid(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DE LA NUEVA UI ---

  // 1. Encabezado dinámico y colorido
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 80, bottom: 24),
      decoration: BoxDecoration(
        color: risk.riskColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            risk.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _DetailInfoTile(
                icon: Icons.computer_outlined,
                label: 'Activo',
                value: risk.asset,
              ),
              const SizedBox(width: 24),
              _DetailInfoTile(
                icon: Icons.shield_outlined,
                label: 'Estado',
                value: risk.statusText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Tarjeta para la valoración con barras de progreso
  Widget _buildValuationCard(BuildContext context) {
    return _buildTitledCard(
      context,
      title: 'Análisis del Riesgo',
      child: Column(
        children: [
          _ValuationBar(
            label: 'Probabilidad',
            value: risk.probability,
            color: risk.riskColor,
          ),
          const SizedBox(height: 16),
          _ValuationBar(
            label: 'Impacto',
            value: risk.impact,
            color: risk.riskColor,
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ScoreCircle(
                label: 'R. Inherente',
                score: risk.inherentRisk.toString(),
                color: risk.riskColor,
              ),
              _ScoreCircle(
                label: 'R. Residual',
                score: risk.residualRisk.toStringAsFixed(1),
                color: Colors.blueGrey,
              ),
            ],
          )
        ],
      ),
    );
  }

  // 3. Grid para las imágenes
  Widget _buildImageGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: risk.imagePaths.length,
      itemBuilder: (context, index) {
        final path = risk.imagePaths[index];
        return GestureDetector(
          onTap: () => _showImageDialog(context, path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.file(File(path), fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  // 4. Widget base para las tarjetas con título
  Widget _buildTitledCard(BuildContext context, {required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS AUXILIARES PARA LA UI ---

class _DetailInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.8)),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _ValuationBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ValuationBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text('$value de 5', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value / 5.0,
            minHeight: 10,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  final String label;
  final String score;
  final Color color;

  const _ScoreCircle({required this.label, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 30,
          backgroundColor: color,
          child: Text(
            score,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}