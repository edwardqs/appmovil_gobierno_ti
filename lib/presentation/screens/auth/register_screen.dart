import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedRole;

  final List<String> _auditorRoles = [
    'Auditor Junior',
    'Auditor Senior',
    'Gerente de Auditoría',
    'Socio de Auditoría',
    'Especialista en TI'
  ];

  void _register() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Lógica de registro simulada
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro exitoso. Ahora puedes iniciar sesión.'),
          backgroundColor: Colors.green,
        ),
      );

      // Regresar a la pantalla de login después del registro
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Auditor'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Nombres', prefixIcon: Icon(Icons.person_outline)),
              validator: (value) => (value?.isEmpty ?? true) ? 'Este campo es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Apellidos', prefixIcon: Icon(Icons.person_outline)),
              validator: (value) => (value?.isEmpty ?? true) ? 'Este campo es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Dirección', prefixIcon: Icon(Icons.location_on_outlined)),
              validator: (value) => (value?.isEmpty ?? true) ? 'Este campo es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'DNI', prefixIcon: Icon(Icons.badge_outlined)),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              validator: (value) => (value?.length ?? 0) < 8 ? 'El DNI debe tener 8 dígitos' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Celular', prefixText: '+51 ', prefixIcon: Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: (value) => (value?.length ?? 0) < 9 ? 'El celular debe tener 9 dígitos' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedRole,
              decoration: const InputDecoration(labelText: 'Cargo', prefixIcon: Icon(Icons.work_outline)),
              items: _auditorRoles.map((String role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Text(role),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedRole = newValue;
                });
              },
              validator: (value) => value == null ? 'Selecciona un cargo' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email_outlined)),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Este campo es obligatorio';
                if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return 'Ingresa un correo válido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
              obscureText: true,
              validator: (value) => (value?.length ?? 0) < 6 ? 'La contraseña debe tener al menos 6 caracteres' : null,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _register,
              child: const Text('Registrarse'),
            ),
          ],
        ),
      ),
    );
  }
}