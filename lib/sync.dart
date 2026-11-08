import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'local.dart';
import 'notificaciones.dart';

class EstadoSync {
  final bool enLinea;
  final int pendientes;
  final DateTime? ultima;
  const EstadoSync(this.enLinea, this.pendientes, this.ultima);
}

class Sync {
  static final estado = ValueNotifier<EstadoSync>(const EstadoSync(false, 0, null));
  static final version = ValueNotifier<int>(0); // sube cuando llegan datos nuevos
  static bool _ocupado = false;
  static Timer? _espera;

  /// Se llama después de cada cambio local: intenta sincronizar en 2 segundos.
  static void programar() {
    Notificaciones.marcarSucio();
    _espera?.cancel();
    _espera = Timer(const Duration(seconds: 2), sincronizar);
    _actualizarContador();
  }

  static Future<void> _actualizarContador() async {
    estado.value = EstadoSync(
        estado.value.enLinea, await Local.contarPendientes(), estado.value.ultima);
  }

  static Future<void> sincronizar() async {
    if (_ocupado) return;
    _ocupado = true;
    var enLinea = false;
    var ultima = estado.value.ultima;
    try {
      await _subir();
      final nuevos = await _bajar();
      enLinea = true;
      ultima = DateTime.now();
      if (nuevos > 0) {
        Notificaciones.marcarSucio();
        version.value++;
      }
    } catch (_) {
      enLinea = false; // sin conexión: se sigue trabajando en el teléfono
    } finally {
      _ocupado = false;
      estado.value = EstadoSync(enLinea, await Local.contarPendientes(), ultima);
      await Notificaciones.reprogramar();
    }
  }

  static Future<void> _subir() async {
    final filas = await Local.pendientes();
    if (filas.isEmpty) return;

    final docs = <Map<String, dynamic>>[];
    for (final f in filas) {
      final id = f['id'] as String;
      if (f['deleted'] == 1) {
        docs.add({'_id': id, '_rev': f['rev'], '_deleted': true});
      } else {
        final d = jsonDecode(f['body'] as String) as Map<String, dynamic>;
        if (f['rev'] != null) d['_rev'] = f['rev'];
        docs.add(d);
      }
    }

    final r = await http
        .post(Uri.parse('${Config.apiUrl}/sync/push'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'docs': docs}))
        .timeout(const Duration(seconds: 6));
    if (r.statusCode >= 400) throw Exception('push ${r.statusCode}');

    var hayConflicto = false;
    for (final res in jsonDecode(r.body)['resultados'] as List) {
      final id = res['id'] as String;
      if (res['ok'] == true) {
        final fila = filas.firstWhere((f) => f['id'] == id);
        if (fila['deleted'] == 1) {
          await Local.borrarFisico(id);
        } else {
          await Local.marcarSincronizado(id, res['rev'] as String);
        }
      } else if (res['error'] == 'conflict') {
        await Local.descartarCambio(id); // gana el servidor
        hayConflicto = true;
      }
    }
    if (hayConflicto) await Local.setMeta('lastSeq', '0');
  }

  static Future<int> _bajar() async {
    final since = await Local.meta('lastSeq') ?? '0';
    final r = await http
        .get(Uri.parse('${Config.apiUrl}/sync/pull')
            .replace(queryParameters: {'since': since}))
        .timeout(const Duration(seconds: 6));
    if (r.statusCode >= 400) throw Exception('pull ${r.statusCode}');
    final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
    final n = await Local.aplicarDelServidor(cuerpo['docs'] as List);
    await Local.setMeta('lastSeq', cuerpo['lastSeq'].toString());
    return n;
  }
}