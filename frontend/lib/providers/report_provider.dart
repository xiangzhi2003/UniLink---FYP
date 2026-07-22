// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : report_provider.dart
// Description     : Riverpod provider exposing ReportService.
// First Written on: Friday,17-Jul-2026
// Edited on       : Friday,17-Jul-2026

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/report_service.dart';

final reportServiceProvider = Provider<ReportService>((ref) => ReportService());
