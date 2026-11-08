import 'package:flutter/material.dart';
import '../api.dart';

class Inmuebles extends StatefulWidget {
  final String propietarioId;
  const Inmuebles({super.key, required this.propietarioId});

  @override
  State<Inmuebles> createState() => _InmueblesState();
}

class _InmueblesState extends State<Inmuebles> {
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
      final todos = await Api.get('/inmuebles') as List;
      lista = todos.where((i) => i['propietarioId'] == widget.propietarioId).toList();
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
      builder: (_) => FormInmueble(propietarioId: widget.propietarioId),
    );
    if (creado == true) cargar();
  }

  Future<void> eliminar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Eliminar inmueble?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.delete('/inmuebles/$id');
    } catch (e) {
      if (mounted) aviso(context, '$e');
    }
    cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inmuebles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : lista.isEmpty
                  ? const Center(child: Text('Aún no hay inmuebles. Agrega el primero.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final i in lista)
                          Card(
                            child: ListTile(
                              leading: Icon(i['tipo'] == 'local' ? Icons.storefront : Icons.house),
                              title: Text(i['direccion']),
                              subtitle: Text('${i['tipo']} · \$${i['canonMensual']} al mes'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => eliminar(i['_id']),
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class FormInmueble extends StatefulWidget {
  final String propietarioId;
  const FormInmueble({super.key, required this.propietarioId});

  @override
  State<FormInmueble> createState() => _FormInmuebleState();
}

class _FormInmuebleState extends State<FormInmueble> {
  final _clave = GlobalKey<FormState>();
  final _direccion = TextEditingController();
  final _canon = TextEditingController();
  String _tipo = 'casa';
  bool _guardando = false;

  Future<void> _guardar() async {
    if (!_clave.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await Api.post('/inmuebles', {
        'propietarioId': widget.propietarioId,
        'tipo': _tipo,
        'direccion': _direccion.text.trim(),
        'canonMensual': double.parse(_canon.text.replaceAll(',', '.')),
      });
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
          DropdownButtonFormField<String>(
            initialValue: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'casa', child: Text('Casa')),
              DropdownMenuItem(value: 'local', child: Text('Local comercial')),
            ],
            onChanged: (v) => setState(() => _tipo = v!),
          ),
          TextFormField(
            controller: _direccion,
            decoration: const InputDecoration(labelText: 'Dirección'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
          ),
          TextFormField(
            controller: _canon,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Canon mensual (\$)'),
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll(',', '.'));
              return (n == null || n <= 0) ? 'Escribe un monto mayor a 0' : null;
            },
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