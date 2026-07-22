// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : review_provider.dart
// Description     : Riverpod provider exposing ReviewService.
// First Written on: Thursday,16-Jul-2026
// Edited on       : Thursday,16-Jul-2026

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/review_service.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService());
