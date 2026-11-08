import 'package:flutter/material.dart';
import '../api.dart';
import '../whatsapp.dart';
import '../sync.dart';

String _fecha(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  Map<String, dynamic>? reporte;
  List<dynamic> atrasados = [];
  List<dynamic> porVencer = [];
  Map<String, dynamic> contratos = {};
  Map<String, dynamic> inquilinos = {};
  Map<String, dynamic> inmuebles = {};
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
      reporte = await Api.get('/reportes/atraso-promedio');
      atrasados = await Api.get('/pagos/atrasados');

      final hoy = DateTime.now();
      final desde = _fecha(hoy);
      final hasta = _fecha(hoy.add(const Duration(days: 5)));
      final todos = await Api.get('/pagos') as List;
      porVencer = todos.where((p) {
        final v = p['fechaVencimiento'] as String;
        return p['estado'] == 'pendiente' && v.compareTo(desde) >= 0 && v.compareTo(hasta) <= 0;
      }).toList();

      contratos = {for (final c in await Api.get('/contratos') as List) c['_id'] as String: c};
      inquilinos = {for (final q in await Api.get('/inquilinos') as List) q['_id'] as String: q};
      inmuebles = {for (final i in await Api.get('/inmuebles') as List) i['_id'] as String: i};
    } catch (e) {
      error = 'No se pudo conectar con la API: $e';
    }
    if (!mounted) return;
    setState(() => cargando = false);
  }

  Map<String, dynamic>? _inquilino(dynamic pago) {
    final c = contratos[pago['contratoId']];
    return c == null ? null : inquilinos[c['inquilinoId']];
  }

  String _inmueble(dynamic pago) {
    final c = contratos[pago['contratoId']];
    final i = c == null ? null : inmuebles[c['inmuebleId']];
    return i == null ? 'Inmueble no encontrado' : i['direccion'];
  }

  Future<void> recordar(dynamic p, {required bool atrasado}) async {
    final q = _inquilino(p);
    if (q == null) {
      aviso(context, 'No se encontró al inquilino de este contrato.');
      return;
    }
    final mensaje = mensajeRecordatorio(
      nombre: q['nombre'],
      periodo: p['periodo'],
      monto: p['monto'],
      vencimiento: p['fechaVencimiento'],
      atrasado: atrasado,
      diasAtraso: p['diasAtraso'],
    );
    final ok = await enviarWhatsApp(q['telefono'], mensaje);
    if (!ok && mounted) aviso(context, 'No se pudo abrir WhatsApp.');
  }

  Future<void> pagar(dynamic p) async {
    try {
      await Api.post('/pagos/${p['_id']}/pagar');
      final recibo = await Api.get('/pagos/${p['_id']}');
      await cargar();
      if (mounted) mostrarRecibo(recibo);
    } catch (e) {
      if (mounted) aviso(context, '$e');
    }
  }

  void mostrarRecibo(dynamic r) {
    final q = _inquilino(r);
    final nombre = q?['nombre'] ?? 'Inquilino';
    final inmueble = _inmueble(r);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Recibo ${r['reciboNo']}'),
        content: Text('Inquilino: $nombre\n'
            'Inmueble: $inmueble\n'
            'Periodo: ${r['periodo']}\n'
            'Monto: \$${r['monto']}\n'
            'Fecha de pago: ${r['fechaPago']}\n'
            'Días de atraso: ${r['diasAtraso']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar')),
          if (q != null)
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Enviar por WhatsApp'),
              onPressed: () => enviarWhatsApp(
                q['telefono'],
                mensajeRecibo(
                  nombre: nombre,
                  inmueble: inmueble,
                  periodo: r['periodo'],
                  monto: r['monto'],
                  fechaPago: r['fechaPago'],
                  reciboNo: r['reciboNo'],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjeta(dynamic p, {required bool atrasado}) {
    final q = _inquilino(p);
    final detalle = atrasado
        ? 'Venció ${p['fechaVencimiento']} · ${p['diasAtraso']} días de atraso'
        : 'Vence ${p['fechaVencimiento']}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_inmueble(p)} · ${q?['nombre'] ?? 'Inquilino no encontrado'}',
              style: Theme.of(context).textTheme.titleSmall),
          Text('Periodo ${p['periodo']} · \$${p['monto']}'),
          Text(detalle),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => recordar(p, atrasado: atrasado),
              icon: const Icon(Icons.chat),
              label: const Text('Recordar'),
            ),
            FilledButton(onPressed: () => pagar(p), child: const Text('Pagar')),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Alquileres')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
           await Sync.sincronizar();
           await cargar();
  },
  child: const Icon(Icons.refresh),
),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        title: const Text('Días de atraso promedio'),
                        subtitle: Text('${reporte?['pagosRegistrados']} pagos registrados · '
                            '${(reporte?['porcentajeConAtraso'] as num).toStringAsFixed(0)}% con atraso'),
                        trailing: Text(
                          (reporte?['diasAtrasoPromedio'] as num).toStringAsFixed(1),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Pagos atrasados (${atrasados.length})', style: titulo),
                    for (final p in atrasados) _tarjeta(p, atrasado: true),
                    const SizedBox(height: 16),
                    Text('Por vencer en 5 días (${porVencer.length})', style: titulo),
                    for (final p in porVencer) _tarjeta(p, atrasado: false),
                  ],
                ),
    );
  }
}