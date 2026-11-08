import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'barra_sync.dart';
import 'local.dart';
import 'sync.dart';
import 'pantallas/inicio.dart';
import 'pantallas/inmuebles.dart';
import 'pantallas/inquilinos.dart';
import 'pantallas/contratos.dart';
import 'pantallas/registro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Local.iniciar();
  runApp(const AlquileresApp());
}

class AlquileresApp extends StatelessWidget {
  const AlquileresApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Alquileres',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const Arranque(),
      );
}

/// Sincroniza si hay conexión, busca al propietario y, si no existe, pide registrarlo.
class Arranque extends StatefulWidget {
  const Arranque({super.key});

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  String? propietarioId;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    await Sync.sincronizar(); // sin conexión, sigue con lo que hay en el teléfono
    final lista = await Api.get('/propietarios') as List;
    if (lista.isNotEmpty) propietarioId = lista.first['_id'];
    if (!mounted) return;
    setState(() => cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (propietarioId == null) {
      return Registro(onListo: (id) => setState(() => propietarioId = id));
    }
    return Home(propietarioId: propietarioId!);
  }
}

class Home extends StatefulWidget {
  final String propietarioId;
  const Home({super.key, required this.propietarioId});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int actual = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => Sync.sincronizar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      const Inicio(),
      Inmuebles(propietarioId: widget.propietarioId),
      const Inquilinos(),
      Contratos(propietarioId: widget.propietarioId),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const BarraSync(),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: Sync.version,
              builder: (context, v, _) => MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: KeyedSubtree(key: ValueKey('$actual-$v'), child: pantallas[actual]),
              ),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: actual,
        onDestinationSelected: (i) => setState(() => actual = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.apartment), label: 'Inmuebles'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Inquilinos'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Contratos'),
        ],
      ),
    );
  }
}