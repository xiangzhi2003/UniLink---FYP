import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/review_service.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService());
