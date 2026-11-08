import 'package:flutter/material.dart';
import '../api.dart';
import '../config.dart';
import '../notificaciones.dart';
import '../sync.dart';

class Ajustes extends StatefulWidget {
  const Ajustes({super.key});

  @override
  State<Ajustes> createState() => _AjustesState();
}

class _AjustesState extends State<Ajustes> {
  final _url = TextEditingController(text: Config.apiUrl);

  Future<void> _guardar() async {
    var u = _url.text.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      aviso(context, 'La dirección debe empezar con http://');
      return;
    }
    await Config.guardar(u);
    await Sync.sincronizar();
    if (mounted) aviso(context, 'Dirección guardada');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Servidor de sincronización',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Dirección de la API',
              helperText: 'Ejemplo: http://192.168.1.246:8080',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _guardar, child: const Text('Guardar y sincronizar')),
          const Divider(height: 40),
          Text('Recordatorios', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Probar aviso ahora'),
            onTap: () => Notificaciones.probarAhora(),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Programar aviso de prueba en 1 minuto'),
            subtitle: const Text('Sirve para comprobar que salen con la app cerrada'),
            onTap: () async {
              await Notificaciones.probarEn1Minuto();
              if (mounted) aviso(context, 'Listo: sale en 1 minuto. Puedes cerrar la app.');
            },
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Los avisos salen a las 8:00 a. m.: 2 días antes del vencimiento, el día '
              'del vencimiento y a los 1, 3 y 7 días de atraso.',
            ),
          ),
        ],
      ),
    );
  }
}