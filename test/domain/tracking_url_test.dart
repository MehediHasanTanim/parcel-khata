import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/couriers/domain/tracking_url.dart';

void main() {
  test('validates templates', () {
    expect(TrackingUrl.isValidTemplate('https://x.com/t/{cn}'), isTrue);
    expect(TrackingUrl.isValidTemplate('http://x.com/?id={cn}'), isTrue);
    expect(TrackingUrl.isValidTemplate('https://x.com/t/'), isFalse);
    expect(TrackingUrl.isValidTemplate('ftp://x.com/{cn}'), isFalse);
    expect(TrackingUrl.isValidTemplate('{cn}'), isFalse);
    expect(TrackingUrl.isValidTemplate(''), isFalse);
  });

  test('substitutes and encodes the CN', () {
    expect(TrackingUrl.build('https://x.com/t/{cn}', 'AB123').toString(),
        'https://x.com/t/AB123');
    expect(TrackingUrl.build('https://x.com/?id={cn}', 'a b').toString(),
        'https://x.com/?id=a%20b');
  });

  test('null for blank CN or invalid template', () {
    expect(TrackingUrl.build('https://x.com/{cn}', ' '), isNull);
    expect(TrackingUrl.build('nope', 'A'), isNull);
  });
}
