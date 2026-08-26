import 'dart:convert';

import 'package:apexo/common_widgets/item_title.dart';
import 'package:apexo/common_widgets/teeth_selector/tx_options.dart';
import 'package:apexo/core/model.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/notifications/push_relay.dart';
import 'package:apexo/utils/constants.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patient_contact.dart';
import 'package:apexo/utils/encode.dart';
import 'package:apexo/utils/parsed_phone_number.dart';
import 'package:apexo/utils/phone_numbers_extractor.dart';
import 'package:apexo/utils/search_normalization.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:http/http.dart' as http;

class PatientTableLabel {
  final IconData icon;
  final Color? color;
  final String title;
  final String content;
  final double value;
  final String searchableString;
  final bool sortable;
  final int tab;
  final bool view;

  PatientTableLabel({
    this.icon = FluentIcons.document,
    this.color,
    this.view = true,
    required this.title,
    required this.content,
    required this.value,
    required this.searchableString,
    required this.sortable,
    required this.tab,
  });
}

class Patient extends Model {
  bool _legacyBirthWasProvided = false;
  bool _legacyGenderWasProvided = false;

  List<String> get allPredefinedTreatments {
    final List<String> list = List.from(teeth.values);
    list.addAll((appointments.byPatient[id]?["all"] ?? []).fold<Set<String>>(
        {}, (set, x) => set..addAll(x.archived == true ? [] : x.teeth.values)));
    return list
        .where((label) =>
            txOptions.any((x) => x.type != StateType.state && x.label == label))
        .toSet()
        .toList();
  }

  List<TreatmentLabel> get treatmentLabels {
    return allPredefinedTreatments
        .map((x) => x == "pontic" || x == "abutment" ? "bridge" : x)
        .where((x) =>
            txOptions.any((y) => y.type != StateType.state && y.label == x))
        .toSet()
        .map((x) => TreatmentLabel(
            string: x, color: labelToColor(x), icon: labelToIcon(x)))
        .toList();
  }

  Map<String, String> get allAppointmentsDentalNotes {
    return Map.from(teeth)
      ..addAll((appointments.byPatient[id]?["all"] ?? [])
          .fold<Map<String, String>>({}, (x, y) {
        if (y.archived == true) return x;
        for (var iso in y.teeth.keys) {
          x[iso] = y.teeth[iso]!;
        }
        return x;
      }));
  }

  List<Appointment> get allAppointments {
    return (appointments.byPatient[id]?["all"] ?? [])
        .where((appointment) =>
            (appointment.archived != true) && appointment.locked == false)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Appointment> get doneAppointments {
    return (appointments.byPatient[id]?["done"] ?? [])
        .where((appointment) =>
            (appointment.archived != true) && appointment.locked == false)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Appointment> get upcomingAppointments {
    return (appointments.byPatient[id]?["upcoming"] ?? [])
        .where((appointment) =>
            (appointment.archived != true) && appointment.locked == false)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Appointment> get pastAppointments {
    return (appointments.byPatient[id]?["past"] ?? [])
        .where((appointment) =>
            (appointment.archived != true) && appointment.locked == false)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  int get age {
    return DateTime.now().year - birth;
  }

  String get prototypeDisplayName {
    final splitName = [surname, firstName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (splitName.isNotEmpty) return splitName;
    if (legacyFullName.trim().isNotEmpty) return legacyFullName.trim();
    return title.trim();
  }

  int? get prototypeBirthYear {
    if (birthDate != null) return birthDate!.year;
    if (approximateBirthYear != null) return approximateBirthYear;
    if (_legacyBirthWasProvided) return birth;
    return null;
  }

  String get prototypeAddressLine =>
      addressLine.trim().isNotEmpty ? addressLine : address;

  String get prototypeAdministrativeNotes =>
      administrativeNotes.trim().isNotEmpty ? administrativeNotes : notes;

  String get prototypeActiveStatus {
    if (activeStatus.trim().isNotEmpty) return activeStatus;
    return archived == true ? 'archived' : 'active';
  }

  String get prototypeSexOrGender {
    if (sexOrGender != 'unknown') return sexOrGender;
    if (!_legacyGenderWasProvided) return 'unknown';
    return gender == 1 ? 'male' : 'female';
  }

  List<PatientContact> get prototypeContacts {
    if (contacts.isNotEmpty) return List.unmodifiable(contacts);
    return [
      ...phone.map((number) => PatientContact.fromJson({
            'type': PatientContactType.phone,
            'raw_value': number.e164,
            'normalized_value': number.e164,
          })),
      if (email.trim().isNotEmpty)
        PatientContact.fromJson({
          'type': PatientContactType.email,
          'raw_value': email.trim(),
          'normalized_value': email.trim().toLowerCase(),
        }),
    ];
  }

  double get paymentsMade {
    return doneAppointments.fold(0.0, (value, element) => value + element.paid);
  }

  double get pricesGiven {
    return doneAppointments.fold(
        0.0, (value, element) => value + element.price);
  }

  bool get overPaid {
    return paymentsMade > pricesGiven;
  }

  bool get fullPaid {
    return paymentsMade == pricesGiven;
  }

  bool get underPaid {
    return paymentsMade < pricesGiven;
  }

  Color? get colorBasedOnPayments {
    if (fullPaid) return null;
    if (underPaid) return Colors.orange;
    return Colors.blue;
  }

  double get outstandingPayments {
    return pricesGiven - paymentsMade;
  }

  int? get daysSinceLastAppointment {
    if (doneAppointments.isEmpty) return null;
    return DateTime.now().difference(doneAppointments.last.date).inDays;
  }

  /// Returns a human-readable string like "2 years, 3 months, 10 days"
  String? get lastVisitDuration {
    if (doneAppointments.isEmpty) return null;
    return Patient.formatDuration(doneAppointments.last.date, DateTime.now());
  }

  /// Formats the duration between two dates as a human-readable string.
  /// e.g. "2 years, 3 months, 10 days"
  static String formatDuration(DateTime from, DateTime to) {
    int years = to.year - from.year;
    int months = to.month - from.month;
    int days = to.day - from.day;

    if (days < 0) {
      months--;
      final prevMonth = DateTime(to.year, to.month - 1, 0);
      days += prevMonth.day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    final parts = <String>[];
    if (years > 0) {
      parts.add("$years ${txt("year${years > 1 ? "s" : ""}")}");
    }
    if (months > 0) {
      parts.add("$months ${txt("month${months > 1 ? "s" : ""}")}");
    }
    if (days > 0 || parts.isEmpty) {
      parts.add("$days ${txt("day${days > 1 ? "s" : ""}")}");
    }

    return parts.join(", ").toLowerCase();
  }

  @override
  bool get locked {
    // lock if only personal patients are permissible
    // and the patient DO have appointments
    // but those appointments doesn't have the current user as operator
    return login.perm(Perm.patients).not(2) &&
        (allAppointments.isNotEmpty &&
            allAppointments
                .where((appointment) =>
                    appointment.operatorsIDs.contains(login.currentAccountID))
                .isEmpty);
  }

  @override
  String? get avatar {
    if (launch.isDemo) return "https://person.alisaleem.workers.dev/";
    final appointmentsWithImages =
        allAppointments.where((a) => a.viewableImgs.isNotEmpty);
    if (appointmentsWithImages.isEmpty) return null;
    return appointmentsWithImages.first.viewableImgs.first;
  }

  @override
  String? get imageRowId {
    final appointmentsWithImages =
        allAppointments.where((a) => a.imgs.isNotEmpty);
    if (appointmentsWithImages.isEmpty) return null;
    return appointmentsWithImages.first.id;
  }

  List<Appointment> get appointmentsWithImages {
    return allAppointments.where((a) => a.imgs.isNotEmpty).toList();
  }

  /// Appointments that have at least one DCM X-ray attached.
  /// Parallel to [appointmentsWithImages].
  List<Appointment> get appointmentsWithDcmImgs {
    return allAppointments.where((a) => a.dcmImgs.isNotEmpty).toList();
  }

  String? _searchString;
  List<PatientTableLabel>? _labels;
  void nullifyLabels() {
    _labels = null;
    _searchString = null;
  }

  String get searchString {
    return _searchString ??= normalizePatientSearch([
      title,
      surname,
      firstName,
      legacyFullName,
      patronymic,
      motherName,
      occupation,
      registrationNumber,
      amka,
      afm,
      legacyFolderNumber,
      prototypeAddressLine,
      area,
      city,
      postalCode,
      ...prototypeContacts
          .expand((contact) => [contact.rawValue, contact.normalizedValue]),
      ...tableLabels.map((label) => label.searchableString),
    ].join(' '));
  }

  List<PatientTableLabel> get tableLabels {
    if (_labels != null) return _labels!;
    final List<PatientTableLabel> _ = [];

    // age
    final age = DateTime.now().year - birth;
    _.add(PatientTableLabel(
      content: age.toString(),
      icon: FluentIcons.birthday_cake,
      title: txt("age"),
      value: age.toDouble(),
      searchableString: age.toString(),
      sortable: true,
      tab: 0,
    ));

    // gender
    final importedGender = prototypeSexOrGender;
    final genderSymbol = importedGender == 'unknown'
        ? txt('notSet')
        : importedGender == 'male'
            ? "👨 ${txt('male')}"
            : "👩 ${txt('female')}";
    _.add(PatientTableLabel(
      content: genderSymbol,
      icon: FluentIcons.info,
      title: txt("gender"),
      value: importedGender == 'unknown'
          ? 2.0
          : importedGender == 'male'
              ? 1.0
              : 0.0,
      searchableString: importedGender,
      sortable: true,
      tab: 0,
    ));

    // phones
    _.add(PatientTableLabel(
      title: txt("phone"),
      content: phonesString.isEmpty ? txt("notSet") : phonesString,
      value: 0,
      searchableString: phonesString,
      sortable: false,
      tab: 0,
      icon: WindowsIcons.phone,
      color: phone.isEmpty ? Colors.orange : null,
    ));

    _.add(PatientTableLabel(
      title: txt("share"),
      content: txt("qrCode"),
      value: 0,
      searchableString: "",
      sortable: false,
      tab: 3,
      icon: FluentIcons.q_r_code,
    ));

    // number of visits
    _.add(PatientTableLabel(
      icon: WindowsIcons.calendar_reply,
      title: txt("appointments"),
      searchableString: "${allAppointments.length}",
      value: allAppointments.length.toDouble(),
      content: allAppointments.length.toString(),
      sortable: true,
      tab: 2,
    ));

    // last visit
    final lastVisitContent = daysSinceLastAppointment == null
        ? txt("noVisits")
        : "$lastVisitDuration ${txt("daysAgo").split(" ").last}";
    _.add(PatientTableLabel(
      icon: WindowsIcons.calendar,
      title: txt("lastVisit"),
      searchableString: lastVisitContent,
      value: (daysSinceLastAppointment ?? double.infinity).toDouble(),
      content: lastVisitContent,
      sortable: true,
      tab: 2,
    ));

    final paymentStatus = txt(underPaid
        ? "underpaid"
        : overPaid
            ? "overpaid"
            : "fullyPaid");
    _.add(PatientTableLabel(
      icon: WindowsIcons.payment_card,
      color: overPaid
          ? Colors.blue
          : underPaid
              ? Colors.orange
              : null,
      content: "${paymentsMade.toStringAsFixed(2)} ${currency()}",
      value: paymentsMade,
      searchableString: paymentStatus,
      title: txt("paid"),
      sortable: true,
      tab: 2,
    ));

    _.add(PatientTableLabel(
      icon: FluentIcons.warning,
      color: Colors.orange,
      content: "${outstandingPayments.toStringAsFixed(2)} ${currency()}",
      value: outstandingPayments,
      searchableString: paymentStatus,
      title: txt("underpaid"),
      sortable: true,
      tab: 2,
      view: underPaid,
    ));

    _.add(PatientTableLabel(
      icon: FluentIcons.warning,
      color: Colors.blue,
      content: "${outstandingPayments.abs().toStringAsFixed(2)} ${currency()}",
      value: overPaid ? outstandingPayments.abs() : outstandingPayments,
      searchableString: paymentStatus,
      title: txt("overpaid"),
      sortable: true,
      tab: 2,
      view: overPaid,
    ));

    for (var tag in tags) {
      _.add(PatientTableLabel(
        content: tag,
        icon: FluentIcons.tag,
        title: txt("patientTags"),
        searchableString: tag,
        value: 0,
        sortable: false,
        tab: 0,
      ));
    }

    return _labels = _;
  }

  Future<String> generatePatientLink() async {
    final longLink =
        "https://web.apexo.app/${encode("$id|$title|${login.url}|${await PushRelay.ensureKey()}")}";

    final shortLink = await http.put(Uri.parse(shorteningServer),
        body: jsonEncode({"long": longLink}));
    return shortLink.body;
  }

  get shortLink {
    if (link == null) return "";
    return "$shorteningServer/$link";
  }

  // id: id of the patient (inherited from Model)
  // title: name of the patient (inherited from Model)
  /* 1 */ int birth = DateTime.now().year - 18;
  /* 2 */ int gender = 0; // 0 for female, 1 for male
  /* 3 */ List<ParsedPhoneNumber> phone = [];
  /* 4 */ String email = "";
  /* 5 */ String address = "";
  /* 6 */ List<String> tags = [];
  /* 7 */ String notes = "";
  /* 8 */ Map<String, String> teeth = {};
  /* 8b */ Map<String, String> teethExtraNotes = {};
  /* 9 */ String? link;

  // Patient-fields prototype. These optional values are read-only in the
  // prototype UI and remain compatible with the existing Apexo JSON shape.
  String registrationNumber = '';
  String surname = '';
  String firstName = '';
  String legacyFullName = '';
  String patronymic = '';
  String motherName = '';
  DateTime? birthDate;
  int? approximateBirthYear;
  String birthDatePrecision = 'unknown';
  String sexOrGender = 'unknown';
  String occupation = '';
  String secondaryOccupationLabel = '';
  String placeOfOriginOrBirth = '';
  DateTime? registrationDate;
  String activeStatus = '';
  String addressLine = '';
  String area = '';
  String city = '';
  String postalCode = '';
  String countryCode = '';
  String amka = '';
  String afm = '';
  String doy = '';
  String identityCardNumber = '';
  String identityIssueDetails = '';
  String insurance = '';
  String patientCategory = '';
  String financialCategory = '';
  String salutation1 = '';
  String salutation2 = '';
  String referralSource = '';
  String administrativeNotes = '';
  String legacyFolderNumber = '';
  Map<String, String> legacyCustomFields = {};
  List<PatientContact> contacts = [];

  String get phonesString => phone.map((p) => p.e164).join(" ");

  @override
  Patient.fromJson(super.json) : super.fromJson();

  @override
  Patient copy(bool blank) {
    return Patient.fromJson(blank ? {} : toJson());
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    nullifyLabels();
    super.fromJson(json);

    _legacyBirthWasProvided = json.containsKey('birth');
    _legacyGenderWasProvided = json.containsKey('gender');
    /* 1 */ birth = json['birth'] ?? birth;
    /* 2 */ gender = json['gender'] ?? gender;
    /* 3 */ phone = json['phone'] == null
        ? []
        : PhoneNumberExtractor.extract(json['phone'])
            .map((s) => ParsedPhoneNumber(s))
            .toList();
    /* 4 */ email = json['email'] ?? email;
    /* 5 */ address = json['address'] ?? address;
    /* 6 */ tags = List<String>.from(json['tags'] ?? tags);
    /* 7 */ notes = json['notes'] ?? notes;
    /* 8 */ teeth = Map<String, String>.from(json['teeth'] ?? teeth);
    /* 8b */ teethExtraNotes =
        Map<String, String>.from(json['teethExtraNotes'] ?? teethExtraNotes);
    /* 9 */ link = json["link"] ?? link;

    registrationNumber = json['registration_number']?.toString() ?? '';
    surname = json['surname']?.toString() ?? '';
    firstName = json['first_name']?.toString() ?? '';
    legacyFullName = json['legacy_full_name']?.toString() ?? '';
    patronymic = json['patronymic']?.toString() ?? '';
    motherName = json['mother_name']?.toString() ?? '';
    birthDate = _parseDate(json['birth_date']);
    approximateBirthYear = _parseInt(json['approximate_birth_year']);
    birthDatePrecision = json['birth_date_precision']?.toString() ?? 'unknown';
    sexOrGender = json['sex_or_gender']?.toString() ?? 'unknown';
    occupation = json['occupation']?.toString() ?? '';
    secondaryOccupationLabel =
        json['secondary_occupation_label']?.toString() ?? '';
    placeOfOriginOrBirth = json['place_of_origin_or_birth']?.toString() ?? '';
    registrationDate = _parseDate(json['registration_date']);
    activeStatus = json['active_status']?.toString() ?? '';
    addressLine = json['address_line']?.toString() ?? '';
    area = json['area']?.toString() ?? '';
    city = json['city']?.toString() ?? '';
    postalCode = json['postal_code']?.toString() ?? '';
    countryCode = json['country_code']?.toString() ?? '';
    amka = json['amka']?.toString() ?? '';
    afm = json['afm']?.toString() ?? '';
    doy = json['doy']?.toString() ?? '';
    identityCardNumber = json['identity_card_number']?.toString() ?? '';
    identityIssueDetails = json['identity_issue_details']?.toString() ?? '';
    insurance = json['insurance']?.toString() ?? '';
    patientCategory = json['patient_category']?.toString() ?? '';
    financialCategory = json['financial_category']?.toString() ?? '';
    salutation1 = json['salutation_1']?.toString() ?? '';
    salutation2 = json['salutation_2']?.toString() ?? '';
    referralSource = json['referral_source']?.toString() ?? '';
    administrativeNotes = json['administrative_notes']?.toString() ?? '';
    legacyFolderNumber = json['legacy_folder_number']?.toString() ?? '';
    legacyCustomFields =
        Map<String, String>.from(json['legacy_custom_fields'] ?? {});
    contacts = (json['contacts'] as List<dynamic>? ?? [])
        .map((contact) =>
            PatientContact.fromJson(Map<String, dynamic>.from(contact as Map)))
        .toList();
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Patient.fromJson({});

    /* 1 */ if (birth != d.birth) json['birth'] = birth;
    /* 2 */ if (gender != d.gender) json['gender'] = gender;
    /* 3 */ if (phone != d.phone) json['phone'] = phonesString;
    /* 4 */ if (email != d.email) json['email'] = email;
    /* 5 */ if (address != d.address) json['address'] = address;
    /* 6 */ if (tags.toString() != d.tags.toString()) json['tags'] = tags;
    /* 7 */ if (notes != d.notes) json['notes'] = notes;
    /* 8 */ if (teeth.isNotEmpty) json['teeth'] = teeth;
    /* 8b */ if (teethExtraNotes.isNotEmpty) {
      json['teethExtraNotes'] = teethExtraNotes;
    }
    /* 9 */ if (link != d.link) json['link'] = link;

    if (registrationNumber.isNotEmpty) {
      json['registration_number'] = registrationNumber;
    }
    if (surname.isNotEmpty) json['surname'] = surname;
    if (firstName.isNotEmpty) json['first_name'] = firstName;
    if (legacyFullName.isNotEmpty) json['legacy_full_name'] = legacyFullName;
    if (patronymic.isNotEmpty) json['patronymic'] = patronymic;
    if (motherName.isNotEmpty) json['mother_name'] = motherName;
    if (birthDate != null) json['birth_date'] = _dateOnly(birthDate!);
    if (approximateBirthYear != null) {
      json['approximate_birth_year'] = approximateBirthYear;
    }
    if (birthDatePrecision != 'unknown') {
      json['birth_date_precision'] = birthDatePrecision;
    }
    if (sexOrGender != 'unknown') json['sex_or_gender'] = sexOrGender;
    if (occupation.isNotEmpty) json['occupation'] = occupation;
    if (secondaryOccupationLabel.isNotEmpty) {
      json['secondary_occupation_label'] = secondaryOccupationLabel;
    }
    if (placeOfOriginOrBirth.isNotEmpty) {
      json['place_of_origin_or_birth'] = placeOfOriginOrBirth;
    }
    if (registrationDate != null) {
      json['registration_date'] = _dateOnly(registrationDate!);
    }
    if (activeStatus.isNotEmpty) json['active_status'] = activeStatus;
    if (addressLine.isNotEmpty) json['address_line'] = addressLine;
    if (area.isNotEmpty) json['area'] = area;
    if (city.isNotEmpty) json['city'] = city;
    if (postalCode.isNotEmpty) json['postal_code'] = postalCode;
    if (countryCode.isNotEmpty) json['country_code'] = countryCode;
    if (amka.isNotEmpty) json['amka'] = amka;
    if (afm.isNotEmpty) json['afm'] = afm;
    if (doy.isNotEmpty) json['doy'] = doy;
    if (identityCardNumber.isNotEmpty) {
      json['identity_card_number'] = identityCardNumber;
    }
    if (identityIssueDetails.isNotEmpty) {
      json['identity_issue_details'] = identityIssueDetails;
    }
    if (insurance.isNotEmpty) json['insurance'] = insurance;
    if (patientCategory.isNotEmpty) {
      json['patient_category'] = patientCategory;
    }
    if (financialCategory.isNotEmpty) {
      json['financial_category'] = financialCategory;
    }
    if (salutation1.isNotEmpty) json['salutation_1'] = salutation1;
    if (salutation2.isNotEmpty) json['salutation_2'] = salutation2;
    if (referralSource.isNotEmpty) json['referral_source'] = referralSource;
    if (administrativeNotes.isNotEmpty) {
      json['administrative_notes'] = administrativeNotes;
    }
    if (legacyFolderNumber.isNotEmpty) {
      json['legacy_folder_number'] = legacyFolderNumber;
    }
    if (legacyCustomFields.isNotEmpty) {
      json['legacy_custom_fields'] = legacyCustomFields;
    }
    if (contacts.isNotEmpty) {
      json['contacts'] = contacts.map((contact) => contact.toJson()).toList();
    }
    return json;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return int.tryParse(value.toString());
  }

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
