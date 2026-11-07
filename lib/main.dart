import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// En el teléfono, cambia localhost por la IP de tu laptop (ej. 192.168.1.15)
const apiUrl = 'http://localhost:8080';

void main() => runApp(const AlquileresApp());

class AlquileresApp extends StatelessWidget {
  const AlquileresApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Alquileres',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const Inicio(),
      );
}

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  Map<String, dynamic>? reporte;
  List<dynamic> atrasados = [];
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
      final r = await http.get(Uri.parse('$apiUrl/reportes/atraso-promedio'));
      final a = await http.get(Uri.parse('$apiUrl/pagos/atrasados'));
      reporte = jsonDecode(r.body);
      atrasados = jsonDecode(a.body);
    } catch (e) {
      error = 'No se pudo conectar con la API: $e';
    }
    setState(() => cargando = false);
  }

  Future<void> pagar(String id) async {
    await http.post(
      Uri.parse('$apiUrl/pagos/$id/pagar'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    await cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alquileres')),
      floatingActionButton: FloatingActionButton(
        onPressed: cargar,
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
                    Text('Pagos atrasados (${atrasados.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                    for (final p in atrasados)
                      Card(
                        child: ListTile(
                          title: Text('Periodo ${p['periodo']} · \$${p['monto']}'),
                          subtitle: Text('Venció ${p['fechaVencimiento']} · ${p['diasAtraso']} días de atraso'),
                          trailing: FilledButton(
                            onPressed: () => pagar(p['_id']),
                            child: const Text('Pagar'),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}