import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/risk_provider.dart';

class CreateRiskScreen extends StatefulWidget {
  const CreateRiskScreen({super.key});

  @override
  State<CreateRiskScreen> createState() => _CreateRiskScreenState();
}

class _CreateRiskScreenState extends State<CreateRiskScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // --- Controladores y variables del formulario ---
  final _titleController = TextEditingController();
  final _assetController = TextEditingController();
  final _commentController = TextEditingController();
  double _probability = 3;
  double _impact = 3;
  double _controlEffectiveness = 0.5;
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  // --- Mapas para etiquetas descriptivas de los sliders ---
  final Map<int, String> _riskLevelLabels = {
    1: 'Muy Bajo',
    2: 'Bajo',
    3: 'Medio',
    4: 'Alto',
    5: 'Muy Alto',
  };

  final Map<double, String> _controlEffectivenessLabels = {
    0.0: '0% - Inexistente',
    0.25: '25% - Bajo',
    0.5: '50% - Medio',
    0.75: '75% - Bueno',
    1.0: '100% - Óptimo',
  };


  @override
  void dispose() {
    _titleController.dispose();
    _assetController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // --- Lógica de Negocio (sin cambios, pero bien estructurada) ---

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
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

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _images.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      // Manejar errores, por ejemplo, si el usuario no da permisos.
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
    if (_formKey.currentState!.validate()) {
      // Lógica para guardar el riesgo
      final riskProvider = Provider.of<RiskProvider>(context, listen: false);
      riskProvider.addRisk(
        _titleController.text,
        _assetController.text,
        _probability.toInt(),
        _impact.toInt(),
        _controlEffectiveness,
        _commentController.text.isNotEmpty ? _commentController.text : null,
        _images.map((file) => file.path).toList(),
      );
      Navigator.pop(context);
    }
  }

  // =======================================================================
  // --- SECCIÓN DE WIDGETS REUTILIZABLES PARA EVITAR REDUNDANCIA ---
  // =======================================================================

  /// Widget reutilizable para los campos de texto con estilo unificado.
  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: validator,
      maxLines: maxLines,
    );
  }

  /// Widget reutilizable para los sliders con etiquetas descriptivas.
  Widget _buildStyledSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Map<num, String> descriptiveLabels,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text(
              descriptiveLabels[value] ?? '',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: descriptiveLabels[value] ?? value.toString(),
          onChanged: (newValue) => setState(() => onChanged(newValue)),
        ),
      ],
    );
  }
  
  // =================================================================
  // --- MÉTODOS BUILDER PARA CADA PASO (MAYOR CLARIDAD) ---
  // =================================================================

  Step _buildIdentificationStep() {
    return Step(
      title: const Text('Identificación'),
      content: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildStyledTextField(
                controller: _titleController,
                label: 'Nombre del Riesgo',
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),
              _buildStyledTextField(
                controller: _assetController,
                label: 'Activo Afectado',
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
              ),
            ],
          ),
        ),
      ),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildValuationStep() {
    return Step(
      title: const Text('Valoración'),
      content: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildStyledSlider(
                label: 'Probabilidad',
                value: _probability,
                min: 1, max: 5, divisions: 4,
                descriptiveLabels: _riskLevelLabels,
                onChanged: (val) => _probability = val,
              ),
              const SizedBox(height: 16),
              _buildStyledSlider(
                label: 'Impacto',
                value: _impact,
                min: 1, max: 5, divisions: 4,
                descriptiveLabels: _riskLevelLabels,
                onChanged: (val) => _impact = val,
              ),
            ],
          ),
        ),
      ),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildControlsStep() {
    return Step(
      title: const Text('Controles'),
      content: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildStyledSlider(
            label: 'Efectividad del Control',
            value: _controlEffectiveness,
            min: 0, max: 1, divisions: 4,
            descriptiveLabels: _controlEffectivenessLabels,
            onChanged: (val) => _controlEffectiveness = val,
          ),
        ),
      ),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildEvidenceStep() {
    return Step(
      title: const Text('Evidencia y Comentarios'),
      content: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStyledTextField(
                controller: _commentController,
                label: 'Comentarios del Auditor',
                validator: (_) => null, // Comentarios opcionales
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              Text('Adjuntar Evidencia (máx. 3)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              // Widget para mostrar imágenes y botón de añadir
              _buildImagePicker(),
            ],
          ),
        ),
      ),
      isActive: _currentStep >= 3,
    );
  }
  
  /// Widget mejorado para la selección de imágenes.
  Widget _buildImagePicker() {
    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      children: [
        ..._images.asMap().entries.map((entry) {
          int idx = entry.key;
          File imageFile = entry.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.file(imageFile, width: 80, height: 80, fit: BoxFit.cover),
              ),
              Positioned(
                right: -8,
                top: -8,
                child: InkWell(
                  onTap: () => _removeImage(idx),
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
        if (_images.length < 3)
          InkWell(
            onTap: _showImageSourceDialog,
            borderRadius: BorderRadius.circular(12.0),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade600, size: 32),
            ),
          ),
      ],
    );
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
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: () {
            final isLastStep = _currentStep == 3;
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
          // Builder para botones con mejor estilo
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 3;
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(isLastStep ? Icons.save_alt_outlined : Icons.arrow_forward),
                      onPressed: details.onStepContinue,
                      label: Text(isLastStep ? 'GUARDAR RIESGO' : 'SIGUIENTE'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: isLastStep ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ),
                  if (_currentStep != 0)
                    const SizedBox(width: 12),
                  if (_currentStep != 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('ANTERIOR'),
                    ),
                ],
              ),
            );
          },
          // Se usan los métodos builder para generar los pasos
          steps: [
            _buildIdentificationStep(),
            _buildValuationStep(),
            _buildControlsStep(),
            _buildEvidenceStep(),
          ],
        ),
      ),
    );
  }
}
