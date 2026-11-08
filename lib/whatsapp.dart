import 'package:url_launcher/url_launcher.dart';

String _normalizar(String tel) {
  var d = tel.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 8) d = '503$d'; // código de El Salvador
  return d;
}

Future<bool> enviarWhatsApp(String telefono, String mensaje) async {
  final uri = Uri.parse(
      'https://wa.me/${_normalizar(telefono)}?text=${Uri.encodeComponent(mensaje)}');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

String mensajeRecordatorio({
  required String nombre,
  required String periodo,
  required dynamic monto,
  required String vencimiento,
  required bool atrasado,
  int? diasAtraso,
}) {
  if (atrasado) {
    return 'Hola $nombre, le recordamos que el pago del alquiler del periodo '
        '$periodo (\$$monto) venció el $vencimiento y lleva $diasAtraso días de atraso. '
        'Quedamos atentos. Gracias.';
  }
  return 'Hola $nombre, le recordamos que el pago del alquiler del periodo '
      '$periodo (\$$monto) vence el $vencimiento. Gracias.';
}

String mensajeRecibo({
  required String nombre,
  required String inmueble,
  required String periodo,
  required dynamic monto,
  required String fechaPago,
  required String reciboNo,
}) {
  return 'RECIBO $reciboNo\n'
      'Inquilino: $nombre\n'
      'Inmueble: $inmueble\n'
      'Periodo: $periodo\n'
      'Monto recibido: \$$monto\n'
      'Fecha de pago: $fechaPago\n'
      'Gracias por su pago.';
}