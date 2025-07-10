import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

class AuthState {
  final bool isLoading;
  final UserModel? user;

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
      final user = await AuthService.getUserFromToken();
      state = state.copyWith(user: user);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = AuthState(); // clear state
  }
}
