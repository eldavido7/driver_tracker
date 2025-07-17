import 'dart:convert';
import 'package:background_locator_2/location_dto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

void callback(LocationDto locationDto) async {
  const storage = FlutterSecureStorage();
  final sessionId = await storage.read(key: 'activeSessionId');
  final token = await storage.read(key: 'token');

  if (sessionId == null || token == null) return;

  try {
    await http.post(
      Uri.parse('https://your-api.com/api/location'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'sessionId': sessionId,
        'latitude': locationDto.latitude,
        'longitude': locationDto.longitude,
      }),
    );
  } catch (e) {
    debugPrint('Background location error: $e');
  }
}

void notificationCallback() {
  debugPrint("Notification clicked.");
}
