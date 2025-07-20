import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/auth_controller.dart';
import './qr_scanner_page.dart';
import './live_tracking_page.dart';
import './profile_page.dart';
import '../../config/env.dart';
import '../session/session_controller.dart';
import '../../models/session.dart';
// import '../auth/login_page.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool _hasProcessedSessions = false;

  @override
  void initState() {
    super.initState();
    // Check for active sessions when the widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForActiveSessions();
    });
  }

  Future<void> _checkForActiveSessions() async {
    if (_hasProcessedSessions) return;

    final authState = ref.read(authControllerProvider);
    final user = authState.user;

    if (user == null || user.sessions == null) return;

    final activeSessions = user.sessions!
        .where((s) => s.status == 'active')
        .toList();

    if (activeSessions.isNotEmpty && mounted) {
      _hasProcessedSessions = true;
      final sessionId = activeSessions.last.id;

      await Future.delayed(Duration.zero);
      if (!mounted) return;

      final resume = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Resume Session?'),
          content: const Text(
            'You have an active session. Would you like to resume tracking it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Start New'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Resume'),
            ),
          ],
        ),
      );

      if (resume == true && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LiveTrackingPage(sessionId: sessionId),
          ),
        );
      } else if (resume == false && mounted) {
        await _endActiveSession(activeSessions.last);
      }
    }
  }

  Future<void> _endActiveSession(SessionModel session) async {
    try {
      double distance = 0.0;
      String duration = 'N/A';
      final endedAt = DateTime.now().toIso8601String();

      try {
        final origin = session.origin.split(',').map(double.parse).toList();
        final destination = session.destination
            .split(',')
            .map(double.parse)
            .toList();
        final response = await http.get(
          Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=${origin[0]},${origin[1]}'
            '&destination=${destination[0]},${destination[1]}'
            '&mode=driving'
            '&key=${Env.mapsApiKey}',
          ),
        );
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          distance =
              data['routes'][0]['legs'][0]['distance']['value'] / 1000.0; // km
        }
      } catch (e) {
        debugPrint('Error fetching Directions API for distance: $e');
      }

      final createdAt = DateTime.tryParse(session.createdAt ?? '');
      if (createdAt != null) {
        final elapsed = DateTime.now().difference(createdAt);
        duration = elapsed.inSeconds < 60
            ? '${elapsed.inSeconds} sec${elapsed.inSeconds != 1 ? 's' : ''}'
            : '${elapsed.inMinutes} min${elapsed.inMinutes != 1 ? 's' : ''}';
      }

      debugPrint(
        'Calling endSession with distance: $distance, duration: $duration, endedAt: $endedAt',
      );

      if (!mounted) return;

      await ref
          .read(sessionControllerProvider.notifier)
          .endSession(
            context: context,
            sessionId: session.id,
            distance: distance,
            duration: duration,
          );

      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const QRCodeScannerPage()));
      }
    } catch (e) {
      debugPrint('Error preparing to end session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare session end: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    // Listen to auth state changes and check for active sessions
    ref.listen(authControllerProvider, (previous, next) {
      if (next.user != null &&
          (previous?.user == null || previous?.user != next.user)) {
        // Reset the flag when user changes
        _hasProcessedSessions = false;
        // Check for active sessions with the new user data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkForActiveSessions();
        });
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00A86B), Color(0xFF006B42)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Left Icon
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.2 * 255).toInt()),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    // Centered Title
                    const Text(
                      'Ride Along',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Right Icons
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(
                                (0.2 * 255).toInt(),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.person),
                              color: Colors.white,
                              tooltip: 'Profile',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ProfilePage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Container(
                          //   decoration: BoxDecoration(
                          //     color: Colors.white.withAlpha(
                          //       (0.2 * 255).toInt(),
                          //     ),
                          //     borderRadius: BorderRadius.circular(12),
                          //   ),
                          //   child: IconButton(
                          //     icon: const Icon(Icons.logout),
                          //     color: Colors.white,
                          //     tooltip: 'Logout',
                          //     onPressed: () async {
                          //       final navigator = Navigator.of(context);
                          //       final authNotifier = ref.read(
                          //         authControllerProvider.notifier,
                          //       );
                          //       await authNotifier.logout();
                          //       if (!mounted) return;
                          //       navigator.pushAndRemoveUntil(
                          //         MaterialPageRoute(
                          //           builder: (context) => const LoginPage(),
                          //         ),
                          //         (Route<dynamic> route) => false,
                          //       );
                          //     },
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Welcome Header
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00A86B), Color(0xFF006B42)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00A86B,
                                ).withAlpha((0.3 * 255).toInt()),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(
                                    (0.2 * 255).toInt(),
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.waving_hand,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(
                                    (0.9 * 255).toInt(),
                                  ),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.name ?? 'Driver',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Description Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 32,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Real-time Location Sharing',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Share your real-time location with our system for seamless driver tracking. Start by entering your current location and destination, and we\'ll handle the rest.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Start Tracking Button
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00A86B), Color(0xFF006B42)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00A86B,
                                ).withAlpha((0.3 * 255).toInt()),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.navigation,
                              color: Colors.white,
                              size: 24,
                            ),
                            label: const Text(
                              'Start Tracking',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const QRCodeScannerPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Privacy Note
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: Colors.green[600],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your privacy is our priority. You control when location sharing starts and stops.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
