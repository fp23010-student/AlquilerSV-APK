import 'package:flutter/material.dart';
import '../api.dart';

String _fecha(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Contratos extends StatefulWidget {
  final String propietarioId;
  const Contratos({super.key, required this.propietarioId});

  @override
  State<Contratos> createState() => _ContratosState();
}

class _ContratosState extends State<Contratos> {
  List<dynamic> inmuebles = [];
  List<dynamic> inquilinos = [];
  List<dynamic> contratos = [];
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
      final todosInm = await Api.get('/inmuebles') as List;
      inmuebles = todosInm.where((i) => i['propietarioId'] == widget.propietarioId).toList();
      inquilinos = await Api.get('/inquilinos') as List;
      final ids = inmuebles.map((i) => i['_id']).toSet();
      final todos = await Api.get('/contratos') as List;
      contratos = todos.where((c) => ids.contains(c['inmuebleId'])).toList();
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() => cargando = false);
  }

  Future<void> nuevo() async {
    if (inmuebles.isEmpty || inquilinos.isEmpty) {
      aviso(context, 'Primero registra al menos un inmueble y un inquilino.');
      return;
    }
    final pagos = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormContrato(inmuebles: inmuebles, inquilinos: inquilinos),
    );
    if (pagos != null) {
      if (mounted) aviso(context, 'Contrato creado con $pagos pagos mensuales.');
      cargar();
    }
  }

  String _direccion(String id) {
    for (final i in inmuebles) {
      if (i['_id'] == id) return i['direccion'];
    }
    return 'Inmueble no encontrado';
  }

  String _inquilino(String id) {
    for (final q in inquilinos) {
      if (q['_id'] == id) return q['nombre'];
    }
    return 'Inquilino no encontrado';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contratos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: nuevo,
        icon: const Icon(Icons.note_add),
        label: const Text('Nuevo'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : contratos.isEmpty
                  ? const Center(child: Text('Aún no hay contratos.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final c in contratos)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.description),
                              title: Text(_direccion(c['inmuebleId'])),
                              subtitle: Text(
                                '${_inquilino(c['inquilinoId'])}\n'
                                '${c['fechaInicio']} a ${c['fechaFin']} · pago el día ${c['diaPago']}',
                              ),
                              isThreeLine: true,
                              trailing: Text('\$${c['canon']}'),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class FormContrato extends StatefulWidget {
  final List<dynamic> inmuebles;
  final List<dynamic> inquilinos;
  const FormContrato({super.key, required this.inmuebles, required this.inquilinos});

  @override
  State<FormContrato> createState() => _FormContratoState();
}

class _FormContratoState extends State<FormContrato> {
  final _clave = GlobalKey<FormState>();
  final _canon = TextEditingController();
  final _diaPago = TextEditingController(text: '5');
  String? _inmuebleId;
  String? _inquilinoId;
  DateTime? _inicio;
  DateTime? _fin;
  String? _errorFechas;
  bool _guardando = false;

  Future<void> _elegirFecha(bool esInicio) async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: esInicio ? (_inicio ?? hoy) : (_fin ?? hoy.add(const Duration(days: 365))),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (f != null) {
      setState(() {
        if (esInicio) {
          _inicio = f;
        } else {
          _fin = f;
        }
        _errorFechas = null;
      });
    }
  }

  Future<void> _guardar() async {
    final okForm = _clave.currentState!.validate();
    if (_inicio == null || _fin == null) {
      setState(() => _errorFechas = 'Elige la fecha de inicio y la de fin');
      return;
    }
    if (!_fin!.isAfter(_inicio!)) {
      setState(() => _errorFechas = 'La fecha de fin debe ser posterior a la de inicio');
      return;
    }
    if (!okForm) return;

    setState(() => _guardando = true);
    try {
      final r = await Api.post('/contratos', {
        'inmuebleId': _inmuebleId,
        'inquilinoId': _inquilinoId,
        'fechaInicio': _fecha(_inicio!),
        'fechaFin': _fecha(_fin!),
        'diaPago': int.parse(_diaPago.text),
        'canon': double.parse(_canon.text.replaceAll(',', '.')),
        'estado': 'vigente',
      });
      final g = await Api.post('/contratos/${r['id']}/generar-pagos');
      if (mounted) Navigator.pop(context, g['creados'] as int);
    } catch (e) {
      if (mounted) {
        aviso(context, '$e');
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _clave,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Inmueble'),
            items: [
              for (final i in widget.inmuebles)
                DropdownMenuItem(value: i['_id'] as String, child: Text(i['direccion'])),
            ],
            onChanged: (v) {
              setState(() => _inmuebleId = v);
              final inm = widget.inmuebles.firstWhere((i) => i['_id'] == v);
              _canon.text = '${inm['canonMensual']}';
            },
            validator: (v) => v == null ? 'Elige un inmueble' : null,
          ),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Inquilino'),
            items: [
              for (final q in widget.inquilinos)
                DropdownMenuItem(value: q['_id'] as String, child: Text(q['nombre'])),
            ],
            onChanged: (v) => setState(() => _inquilinoId = v),
            validator: (v) => v == null ? 'Elige un inquilino' : null,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _elegirFecha(true),
                icon: const Icon(Icons.event),
                label: Text(_inicio == null ? 'Inicio' : _fecha(_inicio!)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _elegirFecha(false),
                icon: const Icon(Icons.event),
                label: Text(_fin == null ? 'Fin' : _fecha(_fin!)),
              ),
            ),
          ]),
          if (_errorFechas != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_errorFechas!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextFormField(
            controller: _diaPago,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Día de pago del mes (1 a 28)'),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return (n == null || n < 1 || n > 28) ? 'Escribe un día entre 1 y 28' : null;
            },
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
            child: Text(_guardando ? 'Creando...' : 'Crear contrato'),
          ),
        ]),
      ),
    );
  }
}