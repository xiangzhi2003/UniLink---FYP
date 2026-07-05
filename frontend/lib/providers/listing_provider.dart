import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/listing_service.dart';

final listingServiceProvider = Provider<ListingService>((ref) => ListingService());
