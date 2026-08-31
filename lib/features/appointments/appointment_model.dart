import 'package:apexo/core/model.dart';
import 'package:apexo/features/accounts/accounts_controller.dart';
import 'package:apexo/features/appointments/google_calendar_link.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/utils/constants.dart';
import 'package:apexo/utils/imgs.dart';

class Appointment extends Model {
  @override
  String? get avatar {
    if (launch.isDemo) return "https://person.alisaleem.workers.dev/";
    if (imgs.isEmpty) return null;
    return imgs.first;
  }

  @override
  String get title {
    if (patient == null) {
      return "  ";
    } else if (patient!.title.isEmpty) {
      return "  ";
    } else {
      return patient!.title;
    }
  }

  @override
  bool get locked {
    // lock if only personal appointments are permissible
    // and the appointment doesn't have the current account id as an operator
    if (login.perm(Perm.appointments).exact(2)) {
      return false;
    } else if (login.perm(Perm.appointments).exact(1)) {
      if (operatorsIDs.contains(login.currentAccountID)) {
        return false;
      } else {
        return true;
      }
    } else {
      return true;
    }
  }

  Patient? get patient {
    return patients.get(patientID ?? "return null when null");
  }

  String get subtitleLine1 {
    return "${isDone ? "✔️ " : ""}${isDone && postOpNotes.isNotEmpty ? postOpNotes : preOpNotes}";
  }

  String get subtitleLine2 {
    return operatorsNames;
  }

  String get operatorsNames {
    if (operatorsIDs.isEmpty) return "";
    return operatorsIDs.map((id) => accounts.nameOrEmailFromID(id)).join(", ");
  }

  bool get userIsOperator {
    return operatorsIDs.contains(login.currentAccountID);
  }

  bool get fullPaid {
    return paid == price;
  }

  bool get overPaid {
    return paid > price;
  }

  bool get underPaid {
    return paid < price;
  }

  double get paymentDifference {
    return (paid - price).abs();
  }

  bool get isMissed {
    return date.isBefore(DateTime.now()) &&
        date.difference(DateTime.now()).inDays.abs() > 0 &&
        !isDone;
  }

  DateTime get endDate => date.add(Duration(minutes: duration));

  bool get firstAppointmentForThisPatient {
    if (patient == null) return false;
    if (patient!.allAppointments.isEmpty) return false;
    return patient!.allAppointments.first == this;
  }

  bool get isLaboworkUndelivered {
    return hasLabwork &&
        labworkReceived &&
        patient != null &&
        patient!.doneAppointments.isNotEmpty &&
        patient!.doneAppointments.last.id == id;
  }

  String get labworkStatus {
    if (!hasLabwork) return "none";
    if (isLaboworkUndelivered) return txt("undelivered");
    if (labworkReceived) return txt("receivedAndDelivered");
    return txt("waitingForLab");
  }

  List<String> get viewableImgs {
    return imgs.where((name) => isAnImageName(name)).toList();
  }

  /// DCM X-ray filenames attached to this appointment, filtered to valid
  /// `.dcm`/`.dicom` names. Guards against stale or corrupt entries.
  List<String> get viewableDcmImgs {
    return dcmImgs.where(isADcmName).toList();
  }

  // id: id of the appointment (inherited from Model)

  /* 1 */ List<String> operatorsIDs = [];
  /* 2 */ String? patientID;
  /* 3 */ String preOpNotes = "";
  /* 4 */ String postOpNotes = "";
  /* 5 */ List<String> prescriptions = [];
  /* 6 */ double price = 0;
  /* 7 */ double paid = 0;
  /* 8 */ List<String> imgs = [];
  /* 9 */ DateTime date = DateTime.now();
  /* 10 */ bool isDone = false;
  /* 11 */ Map<String, String> teeth = {};
  /* 11b */ Map<String, String> teethExtraNotes = {};
  /* 12 */ bool hasLabwork = false;
  /* 13 */ String labName = "";
  /* 14 */ String labworkNotes = "";
  /* 15 */ bool labworkReceived = false;
  /* 16 */ Map<String, String> drawings = {};
  /* 17 */ int duration = 15; // in minutes, default 15
  /* 18 */ List<String> dcmImgs = []; // DICOM X-ray filenames
  /* 19 */ String therapyGroup = ""; // calendar colour / visit category
  // Google Calendar sync metadata. OAuth access/refresh tokens are never
  // stored on an appointment or in PocketBase.
  /* 20 */ String googleCalendarEventId = "";
  /* 21 */ String googleCalendarId = "";
  /* 22 */ String googleCalendarEtag = "";
  /* 23 */ DateTime? googleCalendarUpdatedAt;
  /* 24 */ String googleCalendarHtmlLink = "";
  /* 25 */ String googleCalendarSyncFingerprint = "";
  /* 26 */ Map<String, GoogleCalendarAppointmentLink> googleCalendarLinks = {};

  GoogleCalendarAppointmentLink googleCalendarLinkFor(String accountId) {
    final accountLink = googleCalendarLinks[accountId];
    if (accountLink != null) return accountLink;
    // Read the foundation milestone's single-account fields as a legacy link.
    // The next successful sync moves it into the account-keyed map.
    if (googleCalendarLinks.isEmpty && googleCalendarEventId.isNotEmpty) {
      return GoogleCalendarAppointmentLink(
        eventId: googleCalendarEventId,
        calendarId: googleCalendarId,
        etag: googleCalendarEtag,
        updatedAt: googleCalendarUpdatedAt,
        htmlLink: googleCalendarHtmlLink,
        syncFingerprint: googleCalendarSyncFingerprint,
      );
    }
    return const GoogleCalendarAppointmentLink();
  }

  void setGoogleCalendarLink(
    String accountId,
    GoogleCalendarAppointmentLink link,
  ) {
    googleCalendarLinks = Map<String, GoogleCalendarAppointmentLink>.from(
      googleCalendarLinks,
    )..[accountId] = link;
    _clearLegacyGoogleCalendarLink();
  }

  void removeGoogleCalendarLink(String accountId) {
    googleCalendarLinks = Map<String, GoogleCalendarAppointmentLink>.from(
      googleCalendarLinks,
    )..remove(accountId);
    if (googleCalendarLinks.isEmpty) _clearLegacyGoogleCalendarLink();
  }

  void _clearLegacyGoogleCalendarLink() {
    googleCalendarEventId = "";
    googleCalendarId = "";
    googleCalendarEtag = "";
    googleCalendarUpdatedAt = null;
    googleCalendarHtmlLink = "";
    googleCalendarSyncFingerprint = "";
  }

  Appointment.fromJson(super.json) : super.fromJson();

  @override
  Appointment copy(bool blank) {
    return Appointment.fromJson(blank ? {} : toJson());
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    /* 1 */ operatorsIDs =
        List<String>.from(json["operatorsIDs"] ?? operatorsIDs);
    /* 2 */ prescriptions =
        List<String>.from(json["prescriptions"] ?? prescriptions);
    /* 3 */ patientID = json["patientID"] ?? patientID;
    /* 4 */ preOpNotes = json["preOpNotes"] ?? preOpNotes;
    /* 5 */ postOpNotes = json["postOpNotes"] ?? postOpNotes;
    /* 6 */ price = double.parse((json["price"] ?? price).toString());
    /* 7 */ paid = double.parse((json["paid"] ?? paid).toString());
    /* 8 */ imgs = List<String>.from(json["imgs"] ?? imgs);
    /* 9 */ date = (json["date"] != null
        ? DateTime.fromMillisecondsSinceEpoch((json["date"] * 60000).toInt())
        : date);
    /* 10 */ isDone = (json["isDone"] ?? isDone);
    /* 11 */ teeth = Map<String, String>.from(json['teeth'] ?? teeth);
    /* 11b */ teethExtraNotes =
        Map<String, String>.from(json['teethExtraNotes'] ?? teethExtraNotes);
    /* 12 */ hasLabwork = json["hasLabwork"] ?? hasLabwork;
    /* 13 */ labName = json["labName"] ?? labName;
    /* 14 */ labworkNotes = json["labworkNotes"] ?? labworkNotes;
    /* 15 */ labworkReceived = json["labworkReceived"] ?? labworkReceived;
    /* 16 */ drawings = Map<String, String>.from(json['drawings'] ?? drawings);
    /* 17 */ duration = (json["duration"] as int?) ?? duration;
    /* 18 */ dcmImgs = List<String>.from(json["dcmImgs"] ?? dcmImgs);
    /* 19 */ therapyGroup = json["therapyGroup"] ?? therapyGroup;
    /* 20 */ googleCalendarEventId =
        json["googleCalendarEventId"] ?? googleCalendarEventId;
    /* 21 */ googleCalendarId = json["googleCalendarId"] ?? googleCalendarId;
    /* 22 */ googleCalendarEtag =
        json["googleCalendarEtag"] ?? googleCalendarEtag;
    /* 23 */ googleCalendarUpdatedAt = json["googleCalendarUpdatedAt"] == null
        ? googleCalendarUpdatedAt
        : DateTime.tryParse(json["googleCalendarUpdatedAt"].toString());
    /* 24 */ googleCalendarHtmlLink =
        json["googleCalendarHtmlLink"] ?? googleCalendarHtmlLink;
    /* 25 */ googleCalendarSyncFingerprint =
        json["googleCalendarSyncFingerprint"] ?? googleCalendarSyncFingerprint;
    /* 26 */ final rawGoogleCalendarLinks = json["googleCalendarLinks"];
    if (rawGoogleCalendarLinks is Map) {
      final parsed = <String, GoogleCalendarAppointmentLink>{};
      for (final entry in rawGoogleCalendarLinks.entries) {
        if (entry.value is! Map) continue;
        parsed[entry.key.toString()] = GoogleCalendarAppointmentLink.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
      googleCalendarLinks = parsed;
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Appointment.fromJson({});
    /* 1 */ if (operatorsIDs.isNotEmpty) json['operatorsIDs'] = operatorsIDs;
    /* 2 */ if (prescriptions.isNotEmpty) json['prescriptions'] = prescriptions;
    /* 3 */ if (patientID != d.patientID) json['patientID'] = patientID;
    /* 4 */ if (preOpNotes != d.preOpNotes) json['preOpNotes'] = preOpNotes;
    /* 5 */ if (postOpNotes != d.postOpNotes) json['postOpNotes'] = postOpNotes;
    /* 6 */ if (price != d.price) json['price'] = price;
    /* 7 */ if (paid != d.paid) json['paid'] = paid;
    /* 8 */ if (imgs.isNotEmpty) json['imgs'] = imgs;
    /* 9 */ if (isDone != d.isDone) json['isDone'] = isDone;
    /* 10 */ json['date'] = (date.millisecondsSinceEpoch / 60000).round();
    /* 11 */ if (teeth.isNotEmpty) json['teeth'] = teeth;
    /* 11b */ if (teethExtraNotes.isNotEmpty)
      json['teethExtraNotes'] = teethExtraNotes;
    /* 12 */ if (hasLabwork != d.hasLabwork) json['hasLabwork'] = hasLabwork;
    /* 13 */ if (labName != d.labName) json['labName'] = labName;
    /* 14 */ if (labworkNotes != d.labworkNotes) {
      json['labworkNotes'] = labworkNotes;
    }
    /* 15 */ if (labworkReceived != d.labworkReceived) {
      json['labworkReceived'] = labworkReceived;
    }
    /* 16 */ if (drawings.isNotEmpty) json['drawings'] = drawings;
    /* 17 */ if (duration != d.duration) json['duration'] = duration;
    /* 18 */ if (dcmImgs.isNotEmpty) json['dcmImgs'] = dcmImgs;
    /* 19 */ if (therapyGroup != d.therapyGroup) {
      json['therapyGroup'] = therapyGroup;
    }
    /* 20 */ if (googleCalendarEventId.isNotEmpty) {
      json['googleCalendarEventId'] = googleCalendarEventId;
    }
    /* 21 */ if (googleCalendarId.isNotEmpty) {
      json['googleCalendarId'] = googleCalendarId;
    }
    /* 22 */ if (googleCalendarEtag.isNotEmpty) {
      json['googleCalendarEtag'] = googleCalendarEtag;
    }
    /* 23 */ if (googleCalendarUpdatedAt != null) {
      json['googleCalendarUpdatedAt'] =
          googleCalendarUpdatedAt!.toUtc().toIso8601String();
    }
    /* 24 */ if (googleCalendarHtmlLink.isNotEmpty) {
      json['googleCalendarHtmlLink'] = googleCalendarHtmlLink;
    }
    /* 25 */ if (googleCalendarSyncFingerprint.isNotEmpty) {
      json['googleCalendarSyncFingerprint'] = googleCalendarSyncFingerprint;
    }
    /* 26 */ if (googleCalendarLinks.isNotEmpty) {
      json['googleCalendarLinks'] = googleCalendarLinks.map(
        (accountId, link) => MapEntry(accountId, link.toJson()),
      );
    }

    json.remove("title"); // remove since it is a computed value in this case

    return json;
  }

  @override
  Map<String, dynamic> get jsonCopyForPush {
    return {
      "date": (date.millisecondsSinceEpoch / 60000).round(),
      "isDone": isDone,
      "archived": archived,
      "operatorsIDs": operatorsIDs,
    };
  }

  // Note: `dcmImgs` is intentionally NOT in pushIfChanged — adding X-rays
  // to an appointment should not notify the patient. Other devices learn
  // about new X-rays via the normal PocketBase sync, not push.
  @override
  List<String> get pushIfChanged =>
      ["date", "isDone", "archived", "operatorsIDs"];

  @override
  bool get pushOnCreation => true;

  @override
  List<String> get targetsToPushTo => [
        // once we've implemented the patient side, we should uncomment the following line
        if (patientID != null && patientID!.isNotEmpty) patientID!,
        ...operatorsIDs
      ];
}
