import 'local.dart';

class Config {
  static String apiUrl = 'http://192.168.1.246:8080';

  static Future<void> cargar() async {
    apiUrl = await Local.meta('apiUrl') ?? apiUrl;
  }

  static Future<void> guardar(String url) async {
    apiUrl = url;
    await Local.setMeta('apiUrl', url);
  }
}