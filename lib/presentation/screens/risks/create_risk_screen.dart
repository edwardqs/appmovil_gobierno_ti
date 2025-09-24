import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _commentController = TextEditingController();
  double _probability = 3;
  double _impact = 3;
  double _controlEffectiveness = 0.5;
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _assetController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // Muestra un diálogo para elegir entre Galería y Cámara
  Future<void> _showImageSourceDialog() async {
    if (_images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes seleccionar más de 3 imágenes.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería de Fotos'),
                onTap: () {
                  _getImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Cámara'),
                onTap: () {
                  _getImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Obtiene la imagen desde la fuente seleccionada
  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _images.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      // Manejo de errores en caso de que el usuario niegue el permiso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la imagen: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _submitForm() {
    // Valida que los campos de texto no estén vacíos
    if (!_formKey.currentState!.validate()) {
      setState(() {
        // Regresa al primer paso si hay un error de validación
        _currentStep = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa todos los campos obligatorios.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final riskProvider = Provider.of<RiskProvider>(context, listen: false);
    final imagePaths = _images.map((file) => file.path).toList();

    riskProvider.addRisk(
      _titleController.text,
      _assetController.text,
      _probability.toInt(),
      _impact.toInt(),
      _controlEffectiveness,
      _commentController.text,
      imagePaths,
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nuevo riesgo creado con éxito.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Construye la lista de pasos de forma segura
  List<Step> _getSteps() {
    return [
      Step(
        title: const Text('Identificación'),
        content: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Nombre del Riesgo'),
              validator: (value) =>
              value == null || value.isEmpty ? 'Este campo es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _assetController,
              decoration: const InputDecoration(labelText: 'Activo Afectado'),
              validator: (value) =>
              value == null || value.isEmpty ? 'Este campo es obligatorio' : null,
            ),
          ],
        ),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
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
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Controles'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Efectividad del Control: ${(_controlEffectiveness * 100).toInt()}%'),
            Slider(
              value: _controlEffectiveness,
              min: 0,
              max: 1,
              divisions: 4,
              label: '${(_controlEffectiveness * 100).toInt()}%',
              onChanged: (value) => setState(() => _controlEffectiveness = value),
            ),
          ],
        ),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Evidencia y Comentarios'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comentarios del Auditor',
                hintText: 'Añade tus observaciones aquí...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text('Adjuntar Evidencia (máx. 3)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ..._images.asMap().entries.map((entry) {
                  int idx = entry.key;
                  File imageFile = entry.value;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.file(imageFile, width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => _removeImage(idx),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                if (_images.length < 3)
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid)),
                      child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ],
        ),
        isActive: _currentStep >= 3,
      ),
    ];
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
            final steps = _getSteps();
            final isLastStep = _currentStep == steps.length - 1;

            if (isLastStep) {
              _submitForm();
            } else {
              setState(() => _currentStep += 1);
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == _getSteps().length - 1;
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(isLastStep ? 'GUARDAR' : 'SIGUIENTE'),
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
          steps: _getSteps(),
        ),
      ),
    );
  }
}