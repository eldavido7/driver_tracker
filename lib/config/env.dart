import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

class Env {
  static Future<void> load() async => await dotenv.load();

  static String get apiUrl => dotenv.env['API_URL']!;
  static String get mapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY']!;

  Future<void> setMapsApiKey() async {
    const platform = MethodChannel('maps_api_key_channel');
    await platform.invokeMethod('setMapsApiKey', Env.mapsApiKey);
  }
}
