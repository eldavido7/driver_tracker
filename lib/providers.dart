import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/auth_controller.dart';

final authProvider = Provider((ref) => AuthController(ref));
