import 'package:flutter/material.dart';
import 'sync.dart';

class BarraSync extends StatelessWidget {
  const BarraSync({super.key});

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoSync>(
      valueListenable: Sync.estado,
      builder: (context, e, _) {
        final texto = e.enLinea
            ? 'En línea${e.ultima != null ? ' · sincronizado ${_hora(e.ultima!)}' : ''}'
            : 'Sin conexión · trabajando en el teléfono';
        final pendientes = e.pendientes > 0 ? ' · ${e.pendientes} por subir' : '';
        return Material(
          color: e.enLinea ? Colors.teal.shade700 : Colors.orange.shade800,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(children: [
              Icon(e.enLinea ? Icons.cloud_done : Icons.cloud_off,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$texto$pendientes',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.sync, color: Colors.white, size: 20),
                onPressed: Sync.sincronizar,
              ),
            ]),
          ),
        );
      },
    );
  }
}