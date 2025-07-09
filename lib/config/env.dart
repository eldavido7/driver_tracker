import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static Future<void> load() async => await dotenv.load();

  static String get apiUrl => dotenv.env['API_URL']!;
}
