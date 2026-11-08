import 'package:flutter/material.dart';
import '../api.dart';

class Registro extends StatefulWidget {
  final void Function(String id) onListo;
  const Registro({super.key, required this.onListo});

  @override
  State<Registro> createState() => _RegistroState();
}

class _RegistroState extends State<Registro> {
  final _clave = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  bool _guardando = false;

  Future<void> _guardar() async {
    if (!_clave.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final r = await Api.post('/propietarios', {
        'nombre': _nombre.text.trim(),
        'telefono': _telefono.text.trim(),
      });
      widget.onListo(r['id']);
    } catch (e) {
      if (mounted) {
        aviso(context, '$e');
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenido')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _clave,
          child: Column(children: [
            const Text('Registra tus datos para empezar'),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando...' : 'Continuar'),
            ),
          ]),
        ),
      ),
    );
  }
}