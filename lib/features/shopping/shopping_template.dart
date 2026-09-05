import 'package:apexo/features/shopping/shopping_item_model.dart';
import 'package:apexo/utils/hash.dart';

/// Clean starter catalogue transcribed from "Αναλωσιμα Ιατρειου.xlsx".
/// The workbook's dated stock counts and urgency marks are deliberately not
/// imported; only its categories, material names, and useful variants seed a
/// new installation.
List<ShoppingItem> buildShoppingTemplate() {
  const source = <String, List<(String, List<String>)>>{
    'Αναλώσιμα': [
      ('Ποτηράκια', ['Μαύρα', 'Μπλε']),
      ('Οθόνια', ['Μαύρα', 'Μπλε']),
      ('Γάντια', ['Medium', 'Small']),
      ('Σιελαντλίες', []),
      ('Σιελαντλίες σαλιγκάρια', []),
      ('Τολύπια', ['Size 1', 'Size 2']),
      ('Μάσκες', ['Δετές', 'Με λάστιχο', 'Hartmann']),
      ('Μάσκες FFP2', []),
      ('Γάζες 5x5', []),
      ('Νήμα απώθησης', ['00', '0', '1', '2']),
      (
        'Αμπούλες αναισθησίας',
        [
          'Αρτικαΐνη / αδρεναλίνη 1:100000',
          'Αρτικαΐνη / αδρεναλίνη 1:200000',
          'Μεπιβακαΐνη χωρίς αδρεναλίνη',
        ],
      ),
      ('Λιδοκαΐνη', []),
      ('Βελόνες', ['30G x 12', '30G x 21', '27G x 36']),
      ('Οινόπνευμα', []),
      ('Υπεροξείδιο υδρογόνου', []),
      ('Απολυμαντικό εργαλείων', []),
      ('Απολυμαντικό αναρρόφησης', ['Orotol', 'MD55']),
      ('Απολυμαντικό επιφανειών', []),
      ('Apis No 28', []),
      ('Σφήνες', ['Πορτοκαλί', 'Άσπρες', 'Κίτρινες']),
      ('Υαλονομερής κονία φωτοπολυμεριζόμενη', []),
      ('Υαλονομερής κονία αυτοπολυμεριζόμενη', []),
      ('Αιμοστατική πάστα', ['Expasyl', '3M / πιστόλι', 'Voco']),
      ('Blocks ανάμιξης', ['Μικρά', 'Μεγάλα']),
      ('Algofren 400mg', []),
      ('Ράμματα 3.0', ['Silk', 'PGA']),
      ('Airflow', ['Μέντα', 'Κεράσι']),
      ('Ψυχρό spray', []),
      ('Ρολά σακουλοποίησης', ['5 cm', '7,5 cm', '15 cm', '20 cm', '25 cm']),
      ('Χαρτί σύγκλισης', []),
    ],
    'ΜΑΠ': [
      ('Προσωπίδα', ['Φύλλα']),
      ('Ποδιές χειρουργείου', []),
      ('Επιμανίκια', []),
      ('Ποδονάρια', []),
      ('Unisept', []),
      ('Σκουφάκια', []),
      ('Χλωρεξιδίνη', []),
    ],
    'Εμφράξεις': [
      ('Ρητίνες', ['Brilliant', 'Spident']),
      ('Ουδέτερο στρώμα', ['TG']),
      ('Πινελάκια εφαρμογών', ['Μπλε', 'Μαύρα', 'Πράσινα', 'Άσπρα']),
      ('Τοιχώματα', ['Προκαμπυλωμένα', 'Τμηματικά', 'Apis', 'Tofflemire']),
      ('Δίσκοι λείανσης', ['POI2002A', 'Ταινίες']),
      ('Blue etch', []),
      ('Rebilda', []),
      (
        'Περιστροφικά εργαλεία',
        ['Στρογγυλές', 'Μακριές', 'Στρογγυλό διαμάντι']
      ),
      ('Σιλάνιο', []),
      ('Temp cure', ['Spident']),
      ('Δείκτης τερηδόνας', []),
    ],
    'Ένδο': [
      ('Ca(OH)', ['Cerkamed']),
      (
        'Κώνοι χάρτου',
        ['15', '20', '25', '30', '35', '40', '45', '50', '55', '60', '70', '80']
      ),
      ('Sealer', ['Apexit', 'AH26', 'Ρητινώδες']),
      ('Files', ['6', '8', '10', '15', '20', '25', '30']),
      ('Υποχλωριώδες νάτριο', ['2%', '5%', '5+%']),
      ('MTA', []),
      ('Lentulo', []),
      ('Πολφουλκό', ['6', '8', '10', '15', '20', '25', '30', '40']),
      ('Γουταπέρκα', ['04/40', '04/45', 'Hyflex', 'Taper 06 - Set']),
      ('Στοπ ενδο', []),
      ('CHX ενδο', []),
    ],
    'Προσθετική': [
      ('Express XT Penta', []),
      ('Express XT Light Body', []),
      ('Registrado', ['Lascod Oclurest', 'Ρύγχη πράσινα']),
      ('Αιμοστατική πάστα', ['3M / πιστόλι']),
      ('Monophase', []),
      ('Monophase soft', []),
      ('Αλγηνικό', ['Δοσομετρητής']),
      ('Σιλικόνη Lascod', ['Box', 'Light']),
      ('Kondisil καταλύτης', ['Enersil', 'Λεπτόρρευστη χειρός']),
      ('Ρύγχη κίτρινα', ['Ενδοστοματικά', 'Pentamix yellow', 'Pentamix red']),
      ('Structur', ['Ρύγχη μπλε']),
      ('Hexatemp', ['A2', 'A3']),
      ('Protemp', []),
      ('Οξυφωσφορική', ['TG']),
      (
        'Προσωρινή κονία',
        ['Temp Bond', 'Temp Bond NE', 'Spident Temp', 'Spident Temp NE']
      ),
      ('GIC', ['Meron powder', 'Meron liquid']),
      ('Alustat', []),
    ],
    'Διάφορα': [
      ('Ανταπτοράκι μικρής χειρός αναρρόφησης', []),
      ('Opalescence', ['Home Bleach', 'Office']),
      ('Voco home bleach', ['Home Bleach']),
      ('Liquid dam', []),
      ('Σιλικόνη', ['Μάζα', 'Καταλύτης']),
      ('Office bleach', ['Voco', 'BMS', 'Ultradent']),
      ('Απολυμαντικό χεριών', []),
      ('Φθόριο τζελ', []),
      ('Καθρέπτης', []),
      ('Orotol', []),
      ('MD555', []),
      ('Απολυμαντικό εργαλείων', ['Durr']),
      ('Ταμπλέτες κλιβάνου', []),
      ('Κάτοπτρα', ['4', '5']),
      ('Θήκες νάρθηκα', []),
      ('Πλάκα ανάμιξης', ['Γυάλινη']),
      ('Λάδι Assistina', []),
      ('Καθαριστικό Assistina', []),
      ('Μπλοκ ανάμιξης', ['Μικρό']),
    ],
  };

  final result = <ShoppingItem>[];
  var categoryOrder = 0;
  for (final entry in source.entries) {
    final categoryID =
        simpleHash('shopping-category:${entry.key}', length: 15);
    result.add(ShoppingItem.fromJson({
      'id': categoryID,
      'title': entry.key,
      'isCategory': true,
      'displayOrder': categoryOrder++,
    }));
    var itemOrder = 0;
    for (final material in entry.value) {
      result.add(ShoppingItem.fromJson({
        'id': simpleHash(
          'shopping-item:${entry.key}:${material.$1}',
          length: 15,
        ),
        'title': material.$1,
        'categoryID': categoryID,
        'displayOrder': itemOrder++,
        if (material.$2.isNotEmpty) 'variants': material.$2,
      }));
    }
  }
  return result;
}
