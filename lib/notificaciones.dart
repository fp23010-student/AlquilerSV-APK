import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'local.dart';
import 'pagos_logic.dart';

class Notificaciones {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _sucio = true;
  static DateTime? _ultima;

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'pagos',
      'Recordatorios de pago',
      channelDescription: 'Avisos de pagos por vencer y atrasados',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> iniciar() async {
    if (!Platform.isAndroid) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Avisa que los datos cambiaron y hay que reprogramar.
  static void marcarSucio() => _sucio = true;

  static Future<void> reprogramar() async {
    if (!Platform.isAndroid) return;
    final ahora = DateTime.now();
    if (!_sucio &&
        _ultima != null &&
        ahora.difference(_ultima!) < const Duration(hours: 6)) {
      return;
    }
    _sucio = false;
    _ultima = ahora;

    try {
      await _plugin.cancelAll();
      final contratos = {for (final c in await Local.porTipo('contrato')) c['_id']: c};
      final inquilinos = {for (final q in await Local.porTipo('inquilino')) q['_id']: q};
      final inmuebles = {for (final i in await Local.porTipo('inmueble')) i['_id']: i};

      // Días respecto al vencimiento -> texto del aviso
      const avisos = {
        -2: 'vence en 2 días',
        0: 'vence hoy',
        1: 'lleva 1 día de atraso',
        3: 'lleva 3 días de atraso',
        7: 'lleva 7 días de atraso',
      };

      var id = 1;
      for (final p in await Local.porTipo('pago')) {
        if (p['estado'] == 'pagado') continue;
        final venc = fechaDe(p['fechaVencimiento']);
        final hoy = hoyUtc();
        final dias = venc.difference(hoy).inDays;
        if (dias > 10) continue; // solo lo cercano, para no saturar

        final c = contratos[p['contratoId']];
        if (c == null) continue;
        final q = inquilinos[c['inquilinoId']];
        final i = inmuebles[c['inmuebleId']];
        final quien = '${q?['nombre'] ?? 'Inquilino'} · ${i?['direccion'] ?? 'Inmueble'}';

        for (final e in avisos.entries) {
          final cuando = DateTime(venc.year, venc.month, venc.day + e.key, 8, 0);
          if (cuando.isBefore(ahora)) continue;
          await _plugin.zonedSchedule(
            id++,
            'Pago de alquiler',
            '$quien: periodo ${p['periodo']} (\$${p['monto']}) ${e.value}.',
            tz.TZDateTime.from(cuando, tz.local),
            _detalles,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (_) {
      // si algo falla, la app sigue funcionando sin avisos
    }
  }

  static Future<void> probarAhora() => _plugin.show(
        0,
        'Recordatorios activados',
        'Así se verán los avisos de pago de tus inquilinos.',
        _detalles,
      );

  static Future<void> probarEn1Minuto() => _plugin.zonedSchedule(
        999,
        'Aviso programado',
        'Este aviso se programó hace un minuto y salió solo.',
        tz.TZDateTime.from(DateTime.now().add(const Duration(minutes: 1)), tz.local),
        _detalles,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
}