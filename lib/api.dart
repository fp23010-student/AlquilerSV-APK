import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'local.dart';
import 'pagos_logic.dart';
import 'sync.dart';

class ApiException implements Exception {
  final String mensaje;
  ApiException(this.mensaje);
  @override
  String toString() => mensaje;
}

const _tipos = {
  'propietarios': 'propietario',
  'inmuebles': 'inmueble',
  'inquilinos': 'inquilino',
  'contratos': 'contrato',
  'pagos': 'pago',
};

List<String> _partes(String ruta) =>
    ruta.split('/').where((s) => s.isNotEmpty).toList();

/// Imita la API REST, pero lee y escribe en la base del teléfono.
class Api {
  static Future<dynamic> get(String ruta) async {
    final partes = _partes(ruta);
    if (partes.length == 2 && partes[0] == 'reportes' && partes[1] == 'atraso-promedio') {
      return _reporte();
    }
    if (partes.length == 2 && partes[0] == 'pagos' && partes[1] == 'atrasados') {
      return _atrasados();
    }
    final tipo = _tipos[partes.first];
    if (tipo == null) throw ApiException('Ruta desconocida: $ruta');
    if (partes.length == 1) return Local.porTipo(tipo);
    final doc = await Local.obtener(partes[1]);
    if (doc == null) throw ApiException('No encontrado');
    return doc;
  }

  static Future<dynamic> post(String ruta, [Map<String, dynamic>? datos]) async {
    final partes = _partes(ruta);
    if (partes.length == 3 && partes[0] == 'contratos' && partes[2] == 'generar-pagos') {
      return _generarPagos(partes[1]);
    }
    if (partes.length == 3 && partes[0] == 'pagos' && partes[2] == 'pagar') {
      return _pagar(partes[1], datos);
    }
    final tipo = _tipos[partes.first];
    if (tipo == null || partes.length != 1) throw ApiException('Ruta desconocida: $ruta');
    final id = '$tipo:${const Uuid().v4()}';
    await Local.guardar({...?datos, '_id': id, 'type': tipo});
    Sync.programar();
    return {'id': id, 'ok': true};
  }

  static Future<dynamic> delete(String ruta) async {
    final partes = _partes(ruta);
    if (partes.length != 2 || _tipos[partes[0]] == null) {
      throw ApiException('Ruta desconocida: $ruta');
    }
    await Local.eliminar(partes[1]);
    Sync.programar();
    return null;
  }

  static Future<Map<String, dynamic>> _generarPagos(String id) async {
    final c = await Local.obtener(id);
    if (c == null || c['type'] != 'contrato') throw ApiException('Contrato no encontrado');
    final corto = id.replaceFirst('contrato:', '');
    var creados = 0, existentes = 0;
    for (final (periodo, venc) in generarPeriodos(
        fechaDe(c['fechaInicio']), fechaDe(c['fechaFin']), c['diaPago'] as int)) {
      final pagoId = 'pago:$periodo:$corto';
      if (await Local.obtener(pagoId) != null) {
        existentes++;
        continue;
      }
      await Local.guardar({
        '_id': pagoId,
        'type': 'pago',
        'contratoId': id,
        'periodo': periodo,
        'fechaVencimiento': fechaTexto(venc),
        'monto': (c['canon'] as num).toDouble(),
        'estado': 'pendiente',
      });
      creados++;
    }
    Sync.programar();
    return {'creados': creados, 'existentes': existentes};
  }

  static Future<Map<String, dynamic>> _pagar(String id, Map<String, dynamic>? datos) async {
    final p = await Local.obtener(id);
    if (p == null || p['type'] != 'pago') throw ApiException('Pago no encontrado');
    if (p['estado'] == 'pagado') throw ApiException('El pago ya fue registrado');
    final fechaPago =
        datos?['fechaPago'] != null ? fechaDe(datos!['fechaPago']) : hoyUtc();
    p['fechaPago'] = fechaTexto(fechaPago);
    p['diasAtraso'] = diasAtraso(fechaDe(p['fechaVencimiento']), fechaPago);
    p['estado'] = 'pagado';
    p['reciboNo'] = 'R-${const Uuid().v4().substring(0, 8).toUpperCase()}';
    await Local.guardar(p);
    Sync.programar();
    return {'id': id, 'ok': true};
  }

  static Future<List<dynamic>> _atrasados() async {
    final hoy = hoyUtc();
    final res = <dynamic>[];
    var cambio = false;
    for (final d in await Local.porTipo('pago')) {
      if (d['estado'] != 'pendiente' && d['estado'] != 'atrasado') continue;
      final atraso = hoy.difference(fechaDe(d['fechaVencimiento'])).inDays;
      if (atraso <= 0) continue;
      if (d['estado'] != 'atrasado' || d['diasAtraso'] != atraso) {
        d['estado'] = 'atrasado';
        d['diasAtraso'] = atraso;
        await Local.guardar(d);
        cambio = true;
      }
      res.add(d);
    }
    if (cambio) Sync.programar();
    return res;
  }

  static Future<Map<String, dynamic>> _reporte() async {
    final pagados =
        (await Local.porTipo('pago')).where((p) => p['estado'] == 'pagado').toList();
    final n = pagados.length;
    num suma = 0;
    var conAtraso = 0;
    for (final p in pagados) {
      final d = (p['diasAtraso'] ?? 0) as num;
      suma += d;
      if (d > 0) conAtraso++;
    }
    return {
      'pagosRegistrados': n,
      'diasAtrasoPromedio': n == 0 ? 0.0 : suma / n,
      'porcentajeConAtraso': n == 0 ? 0.0 : conAtraso * 100 / n,
    };
  }
}

void aviso(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
}