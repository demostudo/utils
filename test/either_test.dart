import 'package:test/test.dart';
import 'package:utils/either.dart';
import 'package:utils/maybe.dart';
import 'package:utils/curry.dart';

Never _fail([_]) => fail('Should not be called');
void main() {
  group('Either', () {
    test('right/left', () {
      expect(Either.left<int, double>(1), isA<Left<int, double>>());
      expect(Either.right<int, double>(1.0), isA<Right<int, double>>());
    });
    test('identity', () {
      final left = Either.left<int, double>(1);
      final right = Either.right<int, double>(1.0);
      expect(left.identity<String>(), isA<Left<int, String>>());
      expect(right.identity<String>(), isA<Left<int, String>>());
    });
    test('unit', () {
      final left = Either.left<int, double>(1);
      final right = Either.right<int, double>(1.0);
      expect(left.unit<String>(''), isA<Right<int, String>>());
      expect(right.unit<String>(''), isA<Right<int, String>>());
    });
    test('fromComputation lazy', () {
      expect(Either.fromComputation(_fail), isA<Either>());
      expect(
          Either.fromComputation(() => throw Exception()), isNot(isA<Left>()));
      expect(Either.fromComputation(() => throw Exception()).getL(_fail),
          isA<Exception>());
      expect(Either.fromComputation(() => 'Hello'), isNot(isA<Right>()));
      expect(Either.fromComputation(() => 'Hello').getR(_fail), 'Hello');
    });
    test('fromComputation', () {
      expect(Either.fromComputation(() => throw Exception(), lazy: false),
          isA<Left>());
      expect(
          Either.fromComputation(() => throw Exception(), lazy: false)
              .getL(_fail),
          isA<Exception>());
      expect(Either.fromComputation(() => 'Hello', lazy: false), isA<Right>());
      expect(Either.fromComputation(() => 'Hello', lazy: false).getR(_fail),
          'Hello');
    });

    final lv = 1;
    final rv = 'Hello';
    final left = Either.left<int, String>(1);
    final right = Either.right<int, String>('Hello');
    group('BiFunctor', () {
      test('first', () {
        expect(left.first((v) => 2 * v).getL(_fail), 2);
        expect(
            () => right.first((v) => 2 * v).getL((_) => throw ''), throwsA(''));
      });
      test('second', () {
        expect(
            () => left.second((v) => v * 2).getR((_) => throw ''), throwsA(''));
        expect(right.second((v) => v * 2).getR(_fail), rv * 2);
      });
      test('bimap', () {
        double a(int a) => a.toDouble();
        int b(String b) => b.length;
        expect(left.bimap(a: a, b: b).getL(_fail), lv.toDouble());
        expect(right.bimap(a: a, b: b).getR(_fail), rv.length);
      });
    });
    test('fmap', () {
      expect(left.fmap((b) => b * 2).getL(_fail), lv);
      expect(right.fmap((b) => b * 2).getR(_fail), rv * 2);
    });
    test('bind', () {
      expect(left.bind((b) => right).getL(_fail), lv);
      expect(right.bind((b) => right).getR(_fail), rv);
      expect(right.bind((b) => left).getL(_fail), lv);
    });
    test('getL', () {
      expect(left.getL(_fail), lv);
      expect(() => right.getL((_) => throw ''), throwsA(''));
    });
    test('getR', () {
      expect(right.getR(_fail), rv);
      expect(() => left.getR((_) => throw ''), throwsA(''));
    });
    test('visit', () {
      expect(left.visit(), null);
      expect(left.visit(a: (_) => 2.0), 2.0);
      expect(left.visit(b: (_) => 2.0), null);
      expect(left.visit(a: (_) => 2.0, b: (_) => 3.0), 2.0);
      expect(right.visit(), null);
      expect(right.visit(a: (_) => 2.0), null);
      expect(right.visit(b: (_) => 2.0), 2.0);
      expect(right.visit(a: (_) => 2.0, b: (_) => 3.0), 3.0);
    });
    test('maybeLeft/maybeRight', () {
      expect(left.maybeLeft, isA<Just<int>>());
      expect(left.maybeRight, isA<None<String>>());
      expect(right.maybeLeft, isA<None<int>>());
      expect(right.maybeRight, isA<Just<String>>());
    });
  });
  group('EitherApply', () {
    final left = Either.left<Exception, int>(Exception());
    final right = Either.right<Exception, int>(1);
    double sum(int a, int b) => (a + b).toDouble();
    final sumCurryRight =
        Either.right<Exception, double Function(int) Function(int)>(sum.curry);
    test('apply', () {
      expect(sumCurryRight.apply(left).apply(left), isA<Left>());
      expect(sumCurryRight.apply(right).apply(left), isA<Left>());
      expect(sumCurryRight.apply(left).apply(right), isA<Left>());
      expect(sumCurryRight.apply(right).apply(right), isA<Right>());
      expect(sumCurryRight.apply(right).apply(right).getR(_fail), 2.0);
    });
    test('>>', () {
      expect(sumCurryRight >> left >> left, isA<Left>());
      expect(sumCurryRight >> right >> left, isA<Left>());
      expect(sumCurryRight >> left >> right, isA<Left>());
      expect(sumCurryRight >> right >> right, isA<Right>());
      expect((sumCurryRight >> right >> right).getR(_fail), 2.0);
    });
  });
  group('EitherIterableUtils', () {
    final lv = 1;
    final rv = 'Hello';
    final left = Either.left<int, String>(1);
    final right = Either.right<int, String>('Hello');
    final iter = Iterable.generate(4, (i) => i.isEven ? left : right);
    test('lefts', () {
      expect(iter.lefts(), Iterable.castFrom([lv, lv]));
    });
    test('rights', () {
      expect(iter.rights(), Iterable.castFrom([rv, rv]));
    });
    test('partitionEithers', () {
      final lefts = iter.partitionEithers()[0];
      final rights = iter.partitionEithers()[1];
      expect(lefts, Iterable.castFrom([lv, lv]));
      expect(rights, Iterable.castFrom([rv, rv]));
    });
  });
}
