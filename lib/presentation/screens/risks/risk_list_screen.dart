import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/risk_model.dart';
import '../../providers/risk_provider.dart';
import '../../widgets/common/risk_list_item.dart';
import 'risk_detail_screen.dart';

// Define el enum aquí para que pueda ser utilizado por otros archivos.
enum RiskStatusFilter { all, critical, high }

class RiskListScreen extends StatelessWidget {
  final RiskStatusFilter filter;

  const RiskListScreen({super.key, this.filter = RiskStatusFilter.all});

  @override
  Widget build(BuildContext context) {
    // Escucha los cambios en RiskProvider para obtener la lista de riesgos.
    final riskProvider = Provider.of<RiskProvider>(context);
    final allRisks = riskProvider.risks;

    // Lógica para filtrar la lista de riesgos y definir el título de la pantalla.
    final List<Risk> filteredRisks;
    final String screenTitle;

    switch (filter) {
      case RiskStatusFilter.critical:
        screenTitle = 'Riesgos Críticos';
        filteredRisks = allRisks.where((r) => r.inherentRisk >= 20).toList();
        break;
      case RiskStatusFilter.high:
        screenTitle = 'Riesgos Altos';
        filteredRisks = allRisks
            .where((r) => r.inherentRisk >= 13 && r.inherentRisk < 20)
            .toList();
        break;
      case RiskStatusFilter.all:
        screenTitle = 'Todos los Riesgos';
        filteredRisks = allRisks;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
      ),
      body: riskProvider.isLoading
      // Muestra un indicador de carga mientras se obtienen los datos.
          ? const Center(child: CircularProgressIndicator())
      // Si no hay riesgos en la lista filtrada, muestra un mensaje.
          : filteredRisks.isEmpty
          ? const Center(
        child: Text(
          'No hay riesgos en esta categoría.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
      // Si hay riesgos, construye la lista.
          : ListView.builder(
        itemCount: filteredRisks.length,
        itemBuilder: (context, index) {
          final risk = filteredRisks[index];
          return RiskListItem(
            risk: risk,
            // Habilita la navegación a la pantalla de detalles al tocar.
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RiskDetailScreen(risk: risk),
              ));
            },
          );
        },
      ),
    );
  }
}