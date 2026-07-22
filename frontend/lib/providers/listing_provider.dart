// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : listing_provider.dart
// Description     : Riverpod provider exposing ListingService.
// First Written on: Sunday,05-Jul-2026
// Edited on       : Sunday,05-Jul-2026

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/listing_service.dart';

final listingServiceProvider = Provider<ListingService>((ref) => ListingService());
