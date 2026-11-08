import 'package:flutter/material.dart';
import '../api.dart';

class Inquilinos extends StatefulWidget {
  const Inquilinos({super.key});

  @override
  State<Inquilinos> createState() => _InquilinosState();
}

class _InquilinosState extends State<Inquilinos> {
  List<dynamic> lista = [];
  String? error;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      lista = await Api.get('/inquilinos') as List;
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() => cargando = false);
  }

  Future<void> nuevo() async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FormInquilino(),
    );
    if (creado == true) cargar();
  }

  Future<void> eliminar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Eliminar inquilino?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.delete('/inquilinos/$id');
    } catch (e) {
      if (mounted) aviso(context, '$e');
    }
    cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inquilinos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: nuevo,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : lista.isEmpty
                  ? const Center(child: Text('Aún no hay inquilinos. Agrega el primero.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final q in lista)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(q['nombre']),
                              subtitle: Text(
                                  '${q['telefono']}${q['dui'] != null ? ' · DUI ${q['dui']}' : ''}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => eliminar(q['_id']),
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class FormInquilino extends StatefulWidget {
  const FormInquilino({super.key});

  @override
  State<FormInquilino> createState() => _FormInquilinoState();
}

class _FormInquilinoState extends State<FormInquilino> {
  final _clave = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _dui = TextEditingController();
  bool _guardando = false;

  Future<void> _guardar() async {
    if (!_clave.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final datos = <String, dynamic>{
        'nombre': _nombre.text.trim(),
        'telefono': _telefono.text.trim(),
      };
      if (_dui.text.trim().isNotEmpty) datos['dui'] = _dui.text.trim();
      await Api.post('/inquilinos', datos);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        aviso(context, '$e');
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _clave,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _nombre,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
          ),
          TextFormField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono (WhatsApp)'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
          ),
          TextFormField(
            controller: _dui,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'DUI (opcional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando...' : 'Guardar'),
          ),
        ]),
      ),
    );
  }
}