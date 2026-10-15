import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/time/clock.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());
