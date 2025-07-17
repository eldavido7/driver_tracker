import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import '../../models/session.dart';
import '../session/live_tracking_page.dart';
import '../session/welcome.dart';
import '../auth/auth_controller.dart';

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>(
      (ref) => SessionController(ref),
    );

class SessionState {
  final bool isLoading;
  final SessionModel? session;
  final String? error;

  SessionState({this.isLoading = false, this.session, this.error});

  SessionState copyWith({
    bool? isLoading,
    SessionModel? session,
    String? error,
  }) {
    return SessionState(
      isLoading: isLoading ?? this.isLoading,
      session: session ?? this.session,
      error: error ?? this.error,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  final Ref ref;

  SessionController(this.ref) : super(SessionState());

  Future<void> startSession({
    required BuildContext context,
    required String driverId,
    required String origin,
    required String destination,
    String? destinationName,
  }) async {
    debugPrint('SessionController: Starting session...');

    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('SessionController: Making API call...');
      debugPrint('SessionController: driverId: $driverId');
      debugPrint('SessionController: origin: $origin');
      debugPrint('SessionController: destination: $destination');
      debugPrint('SessionController: destinationName: $destinationName');

      final response = await ApiService.post('/api/sessions', {
        'driverId': driverId,
        'origin': origin,
        'destination': destination,
        'destinationName': destinationName, // Include destinationName
      }, useAuth: true);

      debugPrint('SessionController: API Response data: $response');

      if (response is Map<String, dynamic>) {
        final sessionId = response['id'] as String?;

        if (sessionId != null) {
          debugPrint(
            'SessionController: Session created successfully with ID: $sessionId',
          );

          state = state.copyWith(isLoading: false, error: null);

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LiveTrackingPage(sessionId: sessionId),
              ),
            );
          }
        } else {
          throw Exception('Session ID not found in response');
        }
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      debugPrint('SessionController: Error occurred: $e');

      state = state.copyWith(isLoading: false, error: e.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> endSession({
    required BuildContext context,
    required String sessionId,
    double? distance,
    String? duration,
  }) async {
    debugPrint('SessionController: Ending session...');

    state = state.copyWith(isLoading: true, error: null);

    try {
      await ApiService.post('/api/sessions/$sessionId', {
        'distance': distance,
        'duration': duration,
        'endedAt': DateTime.now().toIso8601String(),
      }, useAuth: true);

      state = state.copyWith(isLoading: false, error: null);

      // After a session ends, we immediately tell the AuthController to
      // refresh the user's data. We `await` this to ensure the data is fresh
      // before we navigate anywhere.
      if (context.mounted) {
        await ref.read(authControllerProvider.notifier).checkAuth(context);
      }

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
      }
    } catch (e) {
      debugPrint('SessionController: Error ending session: $e');

      state = state.copyWith(isLoading: false, error: e.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end session: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
