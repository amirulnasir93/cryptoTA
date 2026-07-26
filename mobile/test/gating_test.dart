// Ported from packages/backend/tests/gating.test.ts -- same cases, same
// expected values, proving the Dart port behaves identically.
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_watchlist_mobile/gating.dart';

void main() {
  group('divergence', () {
    test('returns null with fewer than two valid prices', () {
      expect(divergence([]), isNull);
      expect(divergence([100]), isNull);
      expect(divergence([100, null, null, 0, -5]), isNull);
    });

    test('computes (max-min)/min across valid prices', () {
      expect(divergence([100, 110]), closeTo(0.1, 1e-9));
      expect(divergence([100, 105, 102]), closeTo(0.05, 1e-9));
    });
  });

  group('horizonsFor', () {
    test('<1% divergence allows every horizon', () {
      final r = horizonsFor(0.005, 1000000);
      expect(r.allowed, ["4h_scalp", "1d_scalp", "1d_hold", "1w_hold", "1m_hold"]);
    });

    test('1-5% divergence excludes 4h scalp only', () {
      final r = horizonsFor(0.03, 1000000);
      expect(r.allowed, ["1d_scalp", "1d_hold", "1w_hold", "1m_hold"]);
    });

    test('5-20% divergence excludes both scalps', () {
      final r = horizonsFor(0.1, 1000000);
      expect(r.allowed, ["1d_hold", "1w_hold", "1m_hold"]);
    });

    test('>20% divergence allows only 1w/1m hold', () {
      final r = horizonsFor(0.3, 1000000);
      expect(r.allowed, ["1w_hold", "1m_hold"]);
    });

    test('single-source (null divergence) stays conservative', () {
      final r = horizonsFor(null, 1000000);
      expect(r.allowed, ["1d_hold", "1w_hold", "1m_hold"]);
      expect(r.reason, contains("single source only"));
    });

    test('thin liquidity strips both scalp horizons regardless of divergence', () {
      final r = horizonsFor(0.005, 50000);
      expect(r.allowed, ["1d_hold", "1w_hold", "1m_hold"]);
      expect(r.reason, contains("below liquidity floor"));
    });
  });

  group('dataQualityFor', () {
    test('maps divergence buckets to a single top-level badge', () {
      expect(dataQualityFor(null), isNull);
      expect(dataQualityFor(0.03), "Good");
      expect(dataQualityFor(0.1), "Degraded");
      expect(dataQualityFor(0.3), "Poor");
    });
  });
}
