import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/report_service.dart';

final reportServiceProvider = Provider<ReportService>((ref) => ReportService());
