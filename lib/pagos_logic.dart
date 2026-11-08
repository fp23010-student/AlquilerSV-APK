DateTime fechaDe(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String fechaTexto(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime hoyUtc() {
  final n = DateTime.now();
  return DateTime.utc(n.year, n.month, n.day);
}

int diasAtraso(DateTime vencimiento, DateTime pago) {
  final d = pago.difference(vencimiento).inDays;
  return d < 0 ? 0 : d;
}

/// Un vencimiento por mes, en el día de pago, dentro de la vigencia del contrato.
List<(String, DateTime)> generarPeriodos(DateTime inicio, DateTime fin, int diaPago) {
  final res = <(String, DateTime)>[];
  var y = inicio.year, m = inicio.month;
  while (y < fin.year || (y == fin.year && m <= fin.month)) {
    final venc = DateTime.utc(y, m, diaPago);
    if (!venc.isBefore(inicio) && !venc.isAfter(fin)) {
      res.add(('$y-${m.toString().padLeft(2, '0')}', venc));
    }
    m++;
    if (m == 13) {
      m = 1;
      y++;
    }
  }
  return res;
}