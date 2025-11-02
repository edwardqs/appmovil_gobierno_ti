import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para los formatters

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controladores para los campos del formulario
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _emailController = TextEditingController();
  final _dniController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Variable para almacenar la fecha de nacimiento
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    // TODO: Cargar datos reales del usuario desde el provider o servicio
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _dniController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Función para mostrar el selector de fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  void _saveProfile() {
    // Oculta el teclado
    FocusScope.of(context).unfocus();

    // Muestra un mensaje de confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil actualizado con éxito.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Auditor'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre Completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 20),
          // ▼▼▼ CAMPO DNI AÑADIDO ▼▼▼
          TextFormField(
            controller: _dniController,
            decoration: const InputDecoration(
              labelText: 'DNI',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
          ),
          const SizedBox(height: 20),
          // ▼▼▼ CAMPO CELULAR AÑADIDO ▼▼▼
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Celular',
              prefixText: '+51 ',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            enabled: false, // El email no se puede editar
            decoration: const InputDecoration(
              labelText: 'Correo Electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _roleController,
            decoration: const InputDecoration(
              labelText: 'Rol o Cargo',
              prefixIcon: Icon(Icons.work_outline),
            ),
          ),
          const SizedBox(height: 20),
          // ▼▼▼ CAMPO FECHA DE NACIMIENTO AÑADIDO ▼▼▼
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha de Nacimiento',
              prefixIcon: Icon(Icons.calendar_today_outlined),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
            ),
            child: InkWell(
              onTap: () => _selectDate(context),
              child: Text(
                _birthDate != null
                    ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                    : 'No seleccionada',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ▼▼▼ CAMPO DIRECCIÓN AÑADIDO ▼▼▼
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _saveProfile,
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }
}