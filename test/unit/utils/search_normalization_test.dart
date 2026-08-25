import 'package:apexo/utils/search_normalization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePatientSearch', () {
    test('folds common Greek accents, diaeresis, case, and final sigma', () {
      expect(
        normalizePatientSearch('  ΔΗΜΗΤΡΑΚΟΠΟΥΛΟΣ  Ευριπίδης  '),
        'δημητρακοπουλοσ ευριπιδησ',
      );
      expect(normalizePatientSearch('Μαΐου ΰ'), 'μαιου υ');
    });

    test('keeps Apexo Arabic alif normalization', () {
      expect(normalizePatientSearch('أحمد إبراهيم'), 'احمد ابراهيم');
    });

    test('collapses whitespace', () {
      expect(normalizePatientSearch('John\n  Doe'), 'john doe');
    });
  });
}
