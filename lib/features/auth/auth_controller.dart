import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

class AuthState {
  final bool isLoading;
  final UserModel? user;

  bool get isAuthenticated => user != null;

  AuthState({this.isLoading = false, this.user});

  AuthState copyWith({bool? isLoading, UserModel? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;

  AuthController(this.ref) : super(AuthState());

  Future<void> login({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await AuthService.login(email, password);
      state = state.copyWith(user: user);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> register({
    required BuildContext context,
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await AuthService.register(
        name: name,
        email: email,
        password: password,
      );
      state = state.copyWith(user: user);

      // Navigate back to login or to main app if registration is successful
      if (context.mounted) {
        Navigator.of(context).pop(); // This will go back to login page
        // OR navigate to main app if you want direct login after registration
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> checkAuth(BuildContext context) async {
    try {
      // First try to get user from token (for initial auth check)
      final user = await AuthService.getUserFromToken();

      if (user != null) {
        // Guard the use of `context` with a `mounted` check.
        if (context.mounted) {
          // If user exists, fetch complete user data including sessions from /api/auth/me
          await fetchUserData(context);
        }
      } else {
        state = state.copyWith(user: null);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> fetchUserData(BuildContext context) async {
    try {
      final userData = await ApiService.get('/api/auth/me', useAuth: true);
      final user = UserModel.fromJson(userData['user']);
      state = state.copyWith(user: user);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load user data: $e')));
      }
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = AuthState();
  }

  Future<void> updateUser({
    required BuildContext context,
    required String name,
    required String email,
    String? password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final payload = <String, dynamic>{'name': name, 'email': email};
      if (password != null && password.isNotEmpty) {
        payload['password'] = password;
      }

      final response = await ApiService.patch(
        '/api/auth/me',
        payload,
        useAuth: true,
      );
      final updatedUser = UserModel.fromJson(response['user']);

      state = state.copyWith(user: updatedUser);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
