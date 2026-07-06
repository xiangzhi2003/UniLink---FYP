import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backend_service.dart';
import '../services/transaction_service.dart';

final transactionServiceProvider =
    Provider<TransactionService>((ref) => TransactionService());

final backendServiceProvider = Provider<BackendService>((ref) => BackendService());
