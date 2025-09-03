import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/risk_provider.dart';

class CreateRiskScreen extends StatefulWidget {
  const CreateRiskScreen({super.key});

  @override
  _CreateRiskScreenState createState() => _CreateRiskScreenState();
}

class _CreateRiskScreenState extends State<CreateRiskScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Controladores y variables para el formulario.
  final _titleController = TextEditingController();
  final _assetController = TextEditingController();
  double _probability = 3;
  double _impact = 3;
  double _controlEffectiveness = 0.5;

  @override
  void dispose() {
    _titleController.dispose();
    _assetController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final riskProvider = Provider.of<RiskProvider>(context, listen: false);
      riskProvider.addRisk(
        _titleController.text,
        _assetController.text,
        _probability.toInt(),
        _impact.toInt(),
        _controlEffectiveness,
      );
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nuevo riesgo creado con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Riesgo'),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepTapped: (step) => setState(() => _currentStep = step),
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep += 1);
            } else {
              _submitForm();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 2 ? 'GUARDAR' : 'SIGUIENTE'),
                  ),
                  if (_currentStep != 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('ANTERIOR'),
                    ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Identificación'),
              content: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration:
                    const InputDecoration(labelText: 'Nombre del Riesgo'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Este campo es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _assetController,
                    decoration:
                    const InputDecoration(labelText: 'Activo Afectado'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Este campo es obligatorio'
                        : null,
                  ),
                ],
              ),
              isActive: _currentStep >= 0,
              state:
              _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Valoración'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Probabilidad: ${_probability.toInt()}'),
                  Slider(
                    value: _probability,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _probability.round().toString(),
                    onChanged: (value) => setState(() => _probability = value),
                  ),
                  Text('Impacto: ${_impact.toInt()}'),
                  Slider(
                    value: _impact,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _impact.round().toString(),
                    onChanged: (value) => setState(() => _impact = value),
                  ),
                ],
              ),
              isActive: _currentStep >= 1,
              state:
              _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Controles'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Efectividad del Control: ${(_controlEffectiveness * 100).toInt()}%'),
                  Slider(
                    value: _controlEffectiveness,
                    min: 0,
                    max: 1,
                    divisions: 4,
                    label: '${(_controlEffectiveness * 100).toInt()}%',
                    onChanged: (value) =>
                        setState(() => _controlEffectiveness = value),
                  ),
                ],
              ),
              isActive: _currentStep >= 2,
            ),
          ],
        ),
      ),
    );
  }
}

