import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Local {
  static late Database _db;

  static Future<void> iniciar() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final ruta = p.join(await getDatabasesPath(), 'alquileres.db');
    _db = await openDatabase(ruta, version: 1, onCreate: (db, v) async {
      await db.execute('''CREATE TABLE docs (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        body TEXT NOT NULL,
        rev TEXT,
        dirty INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0)''');
      await db.execute('CREATE INDEX idx_docs_type ON docs(type)');
      await db.execute('CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT)');
    });
  }

  static Map<String, dynamic> _aDoc(Map<String, Object?> f) {
    final d = jsonDecode(f['body'] as String) as Map<String, dynamic>;
    if (f['rev'] != null) d['_rev'] = f['rev'];
    return d;
  }

  static Future<List<Map<String, dynamic>>> porTipo(String tipo) async {
    final filas = await _db.query('docs',
        where: 'type = ? AND deleted = 0', whereArgs: [tipo]);
    return filas.map(_aDoc).toList();
  }

  static Future<Map<String, dynamic>?> obtener(String id) async {
    final filas = await _db.query('docs',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    return filas.isEmpty ? null : _aDoc(filas.first);
  }

  /// Guarda un cambio hecho en el teléfono (queda pendiente de subir).
  static Future<void> guardar(Map<String, dynamic> doc) async {
    final d = Map<String, dynamic>.from(doc);
    final rev = d.remove('_rev') as String?;
    final id = d['_id'] as String;
    final actual =
        await _db.query('docs', columns: ['rev'], where: 'id = ?', whereArgs: [id]);
    await _db.insert(
      'docs',
      {
        'id': id,
        'type': d['type'],
        'body': jsonEncode(d),
        'rev': rev ?? (actual.isEmpty ? null : actual.first['rev']),
        'dirty': 1,
        'deleted': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> eliminar(String id) async {
    final f = await _db.query('docs', where: 'id = ?', whereArgs: [id]);
    if (f.isEmpty) return;
    if (f.first['rev'] == null) {
      // nunca llegó al servidor: basta con borrarlo aquí
      await _db.delete('docs', where: 'id = ?', whereArgs: [id]);
    } else {
      await _db.update('docs', {'deleted': 1, 'dirty': 1},
          where: 'id = ?', whereArgs: [id]);
    }
  }

  // ---- apoyo para la sincronización ----

  static Future<List<Map<String, Object?>>> pendientes() =>
      _db.query('docs', where: 'dirty = 1');

  static Future<int> contarPendientes() async {
    final r = await _db.rawQuery('SELECT COUNT(*) AS n FROM docs WHERE dirty = 1');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  static Future<void> marcarSincronizado(String id, String rev) =>
      _db.update('docs', {'dirty': 0, 'rev': rev}, where: 'id = ?', whereArgs: [id]);

  static Future<void> borrarFisico(String id) =>
      _db.delete('docs', where: 'id = ?', whereArgs: [id]);

  /// Conflicto: se descarta el cambio local y gana la versión del servidor.
  static Future<void> descartarCambio(String id) => _db.update(
      'docs', {'dirty': 0, 'deleted': 0},
      where: 'id = ?', whereArgs: [id]);

  /// Aplica documentos bajados del servidor. Devuelve cuántos cambiaron.
  static Future<int> aplicarDelServidor(List docs) async {
    var n = 0;
    for (final raw in docs) {
      final d = Map<String, dynamic>.from(raw as Map);
      final id = d['_id'] as String;
      final f = await _db.query('docs',
          columns: ['dirty', 'rev'], where: 'id = ?', whereArgs: [id]);
      if (f.isNotEmpty && f.first['dirty'] == 1) continue; // tiene cambios locales
      if (f.isNotEmpty && f.first['rev'] == d['_rev']) continue; // ya lo tiene
      if (d['_deleted'] == true) {
        await _db.delete('docs', where: 'id = ?', whereArgs: [id]);
        n++;
        continue;
      }
      final rev = d.remove('_rev');
      await _db.insert(
        'docs',
        {
          'id': id,
          'type': d['type'],
          'body': jsonEncode(d),
          'rev': rev,
          'dirty': 0,
          'deleted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      n++;
    }
    return n;
  }

  static Future<String?> meta(String k) async {
    final f = await _db.query('meta', where: 'k = ?', whereArgs: [k]);
    return f.isEmpty ? null : f.first['v'] as String;
  }

  static Future<void> setMeta(String k, String v) => _db.insert(
      'meta', {'k': k, 'v': v},
      conflictAlgorithm: ConflictAlgorithm.replace);
}