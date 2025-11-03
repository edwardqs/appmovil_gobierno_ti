import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/risk_model.dart';
import '../../providers/auth_provider.dart';
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final allRisks = riskProvider.risks;

    // Función para mostrar diálogo de confirmación y eliminar riesgo
    Future<void> _showDeleteConfirmation(String riskId) async {
      final risk = allRisks.firstWhere((r) => r.id == riskId);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que deseas eliminar el riesgo "${risk.title}"?\n\nEsta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await riskProvider.deleteRisk(riskId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Riesgo "${risk.title}" eliminado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al eliminar el riesgo: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }

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
            currentUser: currentUser,
            onDelete: _showDeleteConfirmation,
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