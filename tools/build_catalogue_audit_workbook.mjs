import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const workspace = process.cwd();
const sourcePath = path.join(workspace, "tmp", "catalogue-audit", "source_catalogue.json");
const outputDir = path.join(workspace, "outputs", "therapy-catalogue-audit-20260829");
const renderDir = path.join(workspace, "tmp", "catalogue-audit", "rendered");
const outputPath = path.join(outputDir, "Apexo_DentalWin_Therapy_Catalogue_Audit_Source_Colours_2026-08-30.xlsx");

const source = JSON.parse(await fs.readFile(sourcePath, "utf8"));

const groupTranslations = {
  "0": ["Uncategorized legacy review", "Nicht kategorisierte Altbestandsprüfung"],
  "1": ["Operative dentistry 1", "Zahnerhaltung 1"],
  "13": ["Operative dentistry 2", "Zahnerhaltung 2"],
  "2": ["Endodontics", "Endodontie"],
  "4": ["Oral surgery", "Oralchirurgie"],
  "5": ["Fixed prosthodontics", "Festsitzende Prothetik"],
  "7": ["Removable prosthodontics", "Herausnehmbare Prothetik"],
  "10": ["Orthodontics", "Kieferorthopädie"],
  "9": ["Periodontology", "Parodontologie"],
  "12": ["Prevention", "Prophylaxe"],
  "11": ["Implantology", "Implantologie"],
  "3": ["Diagnosis", "Diagnostik"],
  "14": ["Pediatric dentistry", "Kinderzahnheilkunde"],
  "15": ["General", "Allgemein"],
  "16": ["Legacy placeholder category", "Alte Platzhalterkategorie"],
};

const exactTranslations = {
  "ball atchament": ["Ball attachment", "Kugelattachment"],
  "inlay": ["Inlay", "Inlay"],
  "ενδιαμεσο μεταλλοπορσελανης": ["Metal-ceramic pontic", "Metallkeramisches Brückenglied"],
  "icon": ["Icon resin infiltration", "Icon-Kariesinfiltration"],
  "αυχενικη εμφρ.υαλοιονομερη": ["Cervical glass-ionomer restoration", "Zervikale Glasionomerfüllung"],
  "ακρορυζικη αλλοιωση": ["Periapical lesion", "Periapikale Läsion"],
  "αξονας": ["Post", "Stiftaufbau"],
  "εμφυτευμα": ["Implant", "Implantat"],
  "ενθετο": ["Inlay", "Inlay"],
  "μοσχευματα": ["Grafts", "Transplantate"],
  "ουλεκτομη": ["Gingivectomy", "Gingivektomie"],
  "προσω": ["Temporary procedure (legacy shorthand)", "Provisorische Leistung (alte Kurzbezeichnung)"],
  "appointment / no entry": ["Appointment / no entry", "Termin / kein Eintrag"],
  "cbct": ["CBCT", "DVT / CBCT"],
  "recall": ["Recall", "Recall"],
  "reevaluation": ["Re-evaluation", "Reevaluation"],
  "retainer": ["Retainer", "Retainer"],
  "αποκαλυψη κλινικης μυλης": ["Clinical crown exposure", "Freilegung der klinischen Krone"],
  "θεραπεια γενικευμενης χρ.ουλι": ["Treatment of generalized chronic gingivitis", "Behandlung der generalisierten chronischen Gingivitis"],
  "θεραπεια εντοπισμενης ουλιτιδα": ["Treatment of localized gingivitis", "Behandlung der lokalisierten Gingivitis"],
  "θεραπεια ουλιτιδος": ["Gingivitis treatment", "Gingivitisbehandlung"],
  "θεραπεια χειρ. περιοδοντ. α τε": ["Periodontal surgical treatment (legacy abbreviation)", "Parodontalchirurgische Behandlung (alte Kurzbezeichnung)"],
  "περιοδοντιτιδα αρχομενη": ["Early periodontitis", "Beginnende Parodontitis"],
  "περιοδοντιτιδα μετριας βαρυτητας": ["Moderate periodontitis", "Mittelschwere Parodontitis"],
  "περιοδοντιτιδα προχωρημενη": ["Advanced periodontitis", "Fortgeschrittene Parodontitis"],
  "στεφανη ανοξειδ. νεογιλων": ["Stainless-steel crown for primary teeth", "Edelstahlkrone für Milchzähne"],
  "στεφανη ολοκεραμικη": ["All-ceramic crown", "Vollkeramikkrone"],
  "στεφανη προσωρινη ακρυλικη": ["Temporary acrylic crown", "Provisorische Acrylkrone"],
  "συνδεσμος ακριβειας cheka": ["CEKA precision attachment", "CEKA-Präzisionsgeschiebe"],
  "ακτινογραφια": ["Radiograph", "Röntgenaufnahme"],
  "ελεγχος": ["Check-up", "Kontrolle"],
  "ναρθηκας συγκλισης": ["Occlusal splint", "Okklusionsschiene"],
  "θεραπεια με ναρθηκα συγκλεισιακο": ["Occlusal splint therapy", "Okklusionsschienentherapie"],
  "δοθηκε συνταγη φαρμακευτικης αγωγης": ["Medication prescription issued", "Medikamentenverordnung ausgestellt"],
  "ηλεκτρονικη συνταγη": ["Electronic prescription", "Elektronisches Rezept"],
  "παραπομπη": ["Referral", "Überweisung"],
  "χημειοπροφυλαξη / antibiotische abschirmung": ["Antibiotic prophylaxis", "Antibiotische Abschirmung"],
  "απευαισθητοποιηση με bonding": ["Desensitization with bonding agent", "Desensibilisierung mit Bonding"],
  "απευαισθητοποιηση με pro-relief": ["Desensitization with Pro-Relief", "Desensibilisierung mit Pro-Relief"],
  "απευαισθητοποιηση με teethmate desensitizer": ["Desensitization with Teethmate Desensitizer", "Desensibilisierung mit Teethmate Desensitizer"],
  "εμφραξη προσθιου d": ["Anterior restoration (distal)", "Frontzahnfüllung (distal)"],
  "εμφραξη προσθιου m": ["Anterior restoration (mesial)", "Frontzahnfüllung (mesial)"],
  "εμφραξη ρητινης v ομαδας": ["Class V composite restoration", "Kompositfüllung Klasse V"],
  "κλεισιμο διαστηματος με ρητινη": ["Diastema closure with composite", "Diastemaschluss mit Komposit"],
  "τοποθετηση καρφιδας": ["Pin placement", "Stiftsetzung"],
  "αλλαγη φαρμακου (ευγενολη)": ["Medication change (eugenol)", "Medikamentenwechsel (Eugenol)"],
  "τοποθετηση ευκαληπτου": ["Placement of eucalyptus oil", "Einbringen von Eukalyptusöl"],
  "μη αντιστρεπτη πολφιτιδα": ["Irreversible pulpitis", "Irreversible Pulpitis"],
  "παλιος αξονας": ["Existing post", "Vorhandener Stiftaufbau"],
  "προγομφοποιηση / εκτομη ριζας": ["Bicuspidization / root resection", "Prämolarisierung / Wurzelresektion", "Needs review", "Legacy surgical wording requires clinical confirmation"],
  "αξονας υαλονηματων": ["Glass-fiber post", "Glasfaserstift"],
  "αξονας χυτος": ["Cast post and core", "Gegossener Stiftaufbau"],
  "αξονας radix anker": ["Radix Anker post", "Radix-Anker-Stift"],
  "βαθρο φρεζαριστο στεφανης": ["Milled crown base", "Gefräste Kronenbasis", "Needs review", "Legacy laboratory wording requires confirmation"],
  "προβα σκελετου": ["Framework try-in", "Gerüsteinprobe"],
  "προβα rohbrand": ["Bisque-bake try-in", "Rohbrandeinprobe"],
  "στεφανη ζιρκονιας/κεραμικη οψη": ["Zirconia crown with ceramic veneer", "Zirkonoxidkrone mit keramischer Verblendung"],
  "στεφανη ζιρκονιας/κεραμικη πλ. χτιστη": ["Zirconia crown with layered ceramic", "Zirkonoxidkrone mit geschichteter Keramik", "Needs review", "The legacy abbreviation πλ. should be confirmed"],
  "στεφανη ολικη χυτη": ["Full-cast crown", "Vollgusskrone"],
  "συγκολληση αξονα": ["Post cementation", "Stiftzementierung"],
  "συγκολληση με variolink": ["Cementation with Variolink", "Zementierung mit Variolink"],
  "συγκολληση με variolink esthetic": ["Cementation with Variolink Esthetic", "Zementierung mit Variolink Esthetic"],
  "συγκολληση προσωρινη με κονια διπλ. πολυμ.": ["Temporary cementation with dual-cure cement", "Provisorische Zementierung mit dualhärtendem Zement", "Needs review", "Legacy abbreviation for curing mode should be confirmed"],
  "συγκολληση στεφανης/γεφυρας με οξυφωσφορικη κονια": ["Cementation of crown/bridge with zinc-phosphate cement", "Zementierung von Krone/Brücke mit Zinkphosphatzement"],
  "συγκολληση στεφανης/γεφυρας με ρητινωδη κονια": ["Cementation of crown/bridge with resin cement", "Zementierung von Krone/Brücke mit Kompositzement"],
  "συγκολληση στεφανης/γεφυρας με υαλοιονομερη κονια": ["Cementation of crown/bridge with glass-ionomer cement", "Zementierung von Krone/Brücke mit Glasionomerzement"],
  "συνδεσμος ακριβειας ceka": ["CEKA precision attachment", "CEKA-Präzisionsgeschiebe"],
  "συνδεσμος ακριβειας zl": ["ZL precision attachment", "ZL-Präzisionsgeschiebe"],
  "συνδεσμος ημιακριβειας": ["Semi-precision attachment", "Semipräzisionsgeschiebe"],
  "δοκος dolder": ["Dolder bar", "Dolder-Steg"],
  "μεταβατικη μερικη - `πεταλουδα` ακρυλικη": ["Transitional acrylic flipper partial denture", "Interimsteilprothese als Acryl-Flipper"],
  "μεταβατικη μερικη - `πεταλουδα` θερμοπλαστικη": ["Transitional thermoplastic flipper partial denture", "Interimsteilprothese als thermoplastischer Flipper"],
  "μεταβατικη οδοντοστοιχια - προσθηκη δοντιων": ["Transitional denture — addition of teeth", "Interimsprothese — Erweiterung um Zähne"],
  "μεταβατικη ολικη οδοντοστοιχια": ["Transitional complete denture", "Interimstotalprothese"],
  "προβα οπισθιων": ["Posterior-tooth try-in", "Seitenzahnprobe"],
  "προβα προσθιων": ["Anterior-tooth try-in", "Frontzahnprobe"],
  "προβα σκελετου με τοξο καταγραφης": ["Framework try-in with facebow", "Gerüsteinprobe mit Gesichtsbogen"],
  "τοξα καταγραφης / relationsbestimmung": ["Facebow records / jaw-relation registration", "Gesichtsbogen / Relationsbestimmung"],
  "φλιπερακι προσωρινο": ["Temporary flipper", "Provisorischer Flipper"],
  "attachment τυπου ball abutment": ["Ball-abutment attachment", "Kugelkopfattachment"],
  "ball attachment για επενθετη": ["Ball attachment for overdenture", "Kugelattachment für Deckprothese"],
  "locator για omnitaper": ["Locator for Omnitaper", "Locator für Omnitaper"],
  "locator για paltop": ["Locator for Paltop", "Locator für Paltop"],
  "αποξεση οδοντος": ["Scaling/root planing of tooth", "Scaling/Wurzelglättung am Zahn"],
  "θεραπεια γεν. περιοδοντιτιδας": ["Treatment of generalized periodontitis", "Behandlung der generalisierten Parodontitis", "Needs review", "Legacy abbreviation γεν. should be confirmed"],
  "συντ. θεραπεια περιοδοντιτιδας ανα ημιμοριο 1-4": ["Conservative periodontitis treatment per half-arch 1–4", "Konservative Parodontitisbehandlung pro Kieferhälfte 1–4"],
  "συντ. θεραπεια περιοδοντιτιδας ανα ημιμοριο 2-3": ["Conservative periodontitis treatment per half-arch 2–3", "Konservative Parodontitisbehandlung pro Kieferhälfte 2–3"],
  "συντ. θεραπεια περιοδοντιτιδας ανα τεταρτημοριο 1": ["Conservative periodontitis treatment per quadrant 1", "Konservative Parodontitisbehandlung pro Quadrant 1"],
  "συντ. θεραπεια περιοδοντιτιδας ανα τεταρτημοριο 2": ["Conservative periodontitis treatment per quadrant 2", "Konservative Parodontitisbehandlung pro Quadrant 2"],
  "συντ. θεραπεια περιοδοντιτιδας ανα τεταρτημοριο 3": ["Conservative periodontitis treatment per quadrant 3", "Konservative Parodontitisbehandlung pro Quadrant 3"],
  "συντ. θεραπεια περιοδοντιτιδας ανα τεταρτημοριο 4": ["Conservative periodontitis treatment per quadrant 4", "Konservative Parodontitisbehandlung pro Quadrant 4"],
  "εμφυτευμα branemark": ["Brånemark implant", "Brånemark-Implantat"],
  "εμφυτευμα southern": ["Southern implant", "Southern-Implantat"],
  "εμφυτευμα straumman": ["Straumann implant (source spelling: STRAUMMAN)", "Straumann-Implantat (Quellschreibweise: STRAUMMAN)"],
  "κοχλιωση εμφυτευματων": ["Screw retention of implant restorations", "Verschraubung von Implantatversorgungen"],
  "συγκολληση με implant temp": ["Cementation with Implant Temp", "Zementierung mit Implant Temp"],
  "αφαιρεση παλιας (ανεπαρκους) εμφραξης": ["Removal of old inadequate restoration", "Entfernung einer alten unzureichenden Füllung"],
  "εμφραξη αμαλγαματος ο": ["Amalgam restoration (occlusal)", "Amalgamfüllung (okklusal)"],
  "εμφραξη αμαλγαματος v ομαδας": ["Class V amalgam restoration", "Amalgamfüllung Klasse V"],
  "εμφραξη υαλοιονομερους v ομαδας": ["Class V glass-ionomer restoration", "Glasionomerfüllung Klasse V"],
  "προσωρινη εμφραξη με irm": ["Temporary restoration with IRM", "Provisorische Füllung mit IRM"],
  "προσωρινη εμφραξη με zno - eugenol": ["Temporary restoration with zinc oxide–eugenol", "Provisorische Füllung mit Zinkoxid-Eugenol"],
  "δωθηκε συνταγη φαρμακευτικης αγωγης": ["Medication prescription issued", "Medikamentenverordnung ausgestellt"],
};

const phrasePairs = [
  ["Επανάληψη ενδοδοντικής θεραπείας", "Root canal retreatment", "Endodontische Revision"],
  ["Ενδοδοντική θεραπεία", "Root canal treatment of", "Wurzelkanalbehandlung eines"],
  ["Συγκόλληση στεφάνης/γέφυρας με", "Cementation of crown/bridge with", "Zementierung von Krone/Brücke mit"],
  ["Συγκόλληση προσωρινή με", "Temporary cementation with", "Provisorische Zementierung mit"],
  ["Συντ. θεραπεία περιοδοντίτιδας ανά", "Conservative periodontitis treatment per", "Konservative Parodontitisbehandlung pro"],
  ["Χειρουργική εξαγωγή ημιεγκλείστου", "Surgical extraction of partially impacted tooth", "Operative Entfernung eines teilretinierten Zahns"],
  ["Χειρουργική εξαγωγή εγκλείστου", "Surgical extraction of impacted tooth", "Operative Entfernung eines retinierten Zahns"],
  ["Χειρουργική εξαγωγή", "Surgical extraction", "Operative Zahnentfernung"],
  ["Καθαρισμός / Αποτρύγωση / Στίλβωση", "Cleaning / scaling / polishing", "Reinigung / Zahnsteinentfernung / Politur"],
  ["Έμφραξη οπών & σχισμών", "Pit and fissure sealant", "Fissurenversiegelung"],
  ["Έμφραξη ρητίνης", "Composite restoration", "Kompositfüllung"],
  ["Έμφραξη Αμαλγάματος", "Amalgam restoration", "Amalgamfüllung"],
  ["Έμφραξη αμαλγάματος", "Amalgam restoration", "Amalgamfüllung"],
  ["Έμφραξη υαλοϊονομερούς", "Glass-ionomer restoration", "Glasionomerfüllung"],
  ["Έμφραξη με υαλοϊονομερή", "Glass-ionomer restoration", "Glasionomerfüllung"],
  ["Ανασύσταση Αμαλγάματος / Καρφίδα", "Amalgam core build-up / pin", "Amalgamaufbau / Stift"],
  ["Ανασύσταση υαλοϊονομερούς", "Glass-ionomer reconstruction", "Glasionomeraufbau"],
  ["Ανασύσταση κοπτικής γωνίας", "Incisal angle reconstruction", "Schneidekantenrekonstruktion"],
  ["Ανασύσταση ρητίνης με καρφίδα", "Composite core build-up with pin", "Kompositaufbau mit Stift"],
  ["Ανασύσταση ρητίνης", "Composite reconstruction", "Kompositaufbau"],
  ["Αλλαγή φαρμάκου", "Medication change", "Medikamentenwechsel"],
  ["Άμεση κάλυψη πολφού", "Direct pulp capping", "Direkte Pulpaüberkappung"],
  ["Έμμεση κάλυψη πολφού", "Indirect pulp capping", "Indirekte Pulpaüberkappung"],
  ["Δοκιμασία ζωτικότητας πολφού", "Pulp vitality test", "Vitalitätsprüfung der Pulpa"],
  ["Ανεπαρκής ενδοδοντική θεραπεία", "Inadequate root canal treatment", "Unzureichende Wurzelkanalbehandlung"],
  ["Νέκρωση πολφού", "Pulp necrosis", "Pulpanekrose"],
  ["Παλιά έμφραξη αμαλγάματος", "Old amalgam restoration", "Alte Amalgamfüllung"],
  ["Παλιά έμφραξη ρητίνης", "Old composite restoration", "Alte Kompositfüllung"],
  ["Αφαίρεση παλιάς", "Removal of old", "Entfernung einer alten"],
  ["Αφαίρεση στεφάνης", "Crown removal", "Kronenentfernung"],
  ["Αφαίρεση καλύπτρας", "Removal of operculum", "Entfernung der Schleimhautkappe"],
  ["Αποκάλυψη εμφυτεύματος", "Implant uncovering", "Implantatfreilegung"],
  ["Χειρουργική αφαίρεση εμφυτεύματος", "Surgical implant removal", "Operative Implantatentfernung"],
  ["Τοποθέτηση εμφυτεύματος", "Implant placement", "Implantatinsertion"],
  ["Εμφύτευμα", "Implant", "Implantat"],
  ["Γέφυρα επί εμφυτευμάτων", "Implant-supported bridge", "Implantatgetragene Brücke"],
  ["Στεφάνη επί εμφυτεύματος", "Implant-supported crown", "Implantatgetragene Krone"],
  ["Γέφυρα", "Bridge", "Brücke"],
  ["Ενδιάμεσο", "Pontic", "Brückenglied"],
  ["Στεφάνη", "Crown", "Krone"],
  ["Όψη πορσελάνης", "Porcelain veneer", "Keramikveneer"],
  ["Όψη ρητίνης", "Composite veneer", "Kompositveneer"],
  ["Ένθετο/υπερένθετο", "Inlay/onlay", "Inlay/Onlay"],
  ["Ακρυλική προσωρινή", "Temporary acrylic", "Provisorische Acryl-"],
  ["ολικής χυτής", "full-cast", "Vollguss-"],
  ["μεταλλοκεραμική", "metal-ceramic", "metallkeramisch"],
  ["μεταλλοκεραμικό", "metal-ceramic", "metallkeramisch"],
  ["μεταλλοακρυλική", "metal-acrylic", "metallakryl"],
  ["ολοκεραμική", "all-ceramic", "vollkeramisch"],
  ["ζιρκονίας", "zirconia", "Zirkonoxid"],
  ["κεραμικό", "ceramic", "Keramik"],
  ["ρητίνης", "resin", "Komposit"],
  ["Ακρορριζεκτομή", "Apicoectomy", "Wurzelspitzenresektion"],
  ["Επανεμφύτευση οδόντος", "Tooth replantation", "Zahnreplantation"],
  ["Θεραπεία ξηρού φατνίου", "Dry socket treatment", "Behandlung einer Alveolitis sicca"],
  ["Σχάση αποστήματος", "Abscess incision", "Abszessinzision"],
  ["Εκπυρήνιση κύστης", "Cyst enucleation", "Zystektomie"],
  ["Χειρουργική επιμήκυνση μύλης", "Surgical crown lengthening", "Chirurgische Kronenverlängerung"],
  ["Ουλεκτομή / επιμήκυνση μύλης", "Gingivectomy / crown lengthening", "Gingivektomie / Kronenverlängerung"],
  ["Εξαγωγή νεογιλού", "Extraction of primary tooth", "Extraktion eines Milchzahns"],
  ["Εξαγωγή ρίζας", "Root extraction", "Wurzelentfernung"],
  ["Εξαγωγή", "Extraction", "Extraktion"],
  ["Αναγόμωση μερικής οδοντοστοιχίας", "Relining of partial denture", "Unterfütterung einer Teilprothese"],
  ["Αναγόμωση ολικής οδοντοστοιχίας", "Relining of complete denture", "Unterfütterung einer Totalprothese"],
  ["Επιδιόρθωση μερικής οδοντοστοιχίας", "Repair of partial denture", "Reparatur einer Teilprothese"],
  ["Επιδιόρθωση ολικής οδοντοστοιχίας", "Repair of complete denture", "Reparatur einer Totalprothese"],
  ["Μερική οδοντοστοιχία", "Partial denture", "Teilprothese"],
  ["Μερική οδοντοστοιχιά", "Partial denture", "Teilprothese"],
  ["Ολική οδοντοστοιχία", "Complete denture", "Totalprothese"],
  ["Μεταβατική οδοντοστοιχία", "Transitional denture", "Interimsprothese"],
  ["Μεταβατική μερική", "Transitional partial denture", "Interimsteilprothese"],
  ["Μεταβατική ολική", "Transitional complete denture", "Interimstotalprothese"],
  ["Προσθήκη δοντιού οδοντοστοιχίας", "Addition of a denture tooth", "Erweiterung um einen Prothesenzahn"],
  ["Παράδοση οδοντοστοιχίας", "Denture delivery", "Protheseneingliederung"],
  ["Ατομικά δισκάρια", "Custom impression trays", "Individuelle Abformlöffel"],
  ["Εξισορρόπηση σύγκλισης", "Occlusal adjustment", "Okklusionskorrektur"],
  ["Διατηρητής χώρου", "Space maintainer", "Platzhalter"],
  ["Ορθοδοντικό μηχάνημα", "Orthodontic appliance", "Kieferorthopädisches Gerät"],
  ["Μέτρηση / Περιοδοντόγραμμα", "Periodontal charting", "Parodontalstatus"],
  ["Ναρθηκοποίηση", "Splinting", "Schienung"],
  ["Λεύκανση με νάρθηκα νυχτός", "Whitening with night tray", "Bleaching mit Nachtschiene"],
  ["Λεύκανση στο ιατρείο", "In-office whitening", "In-Office-Bleaching"],
  ["Νάρθηκας βρουξισμού", "Bruxism splint", "Knirscherschiene"],
  ["Νάρθηκας αθλητικός", "Sports mouthguard", "Sportmundschutz"],
  ["Περιεμφυτευματίτιδα", "Peri-implantitis", "Periimplantitis"],
  ["Περιοδοντίτιδα", "Periodontitis", "Parodontitis"],
  ["Περιστεφανίτιδα", "Pericoronitis", "Perikoronitis"],
  ["Γενικευμένη ουλίτιδα", "Generalized gingivitis", "Generalisierte Gingivitis"],
  ["Ακτινογραφία δήξεως", "Bitewing radiograph", "Bissflügelaufnahme"],
  ["Ακτινογραφία ενδοστοματική", "Intraoral radiograph", "Intraorale Röntgenaufnahme"],
  ["Ακτινογραφία εδάφους στόματος", "Occlusal radiograph", "Okklusalaufnahme"],
  ["Πανοραμική ακτινογραφία", "Panoramic radiograph", "Panoramaschichtaufnahme"],
  ["Ακτινογραφία", "Radiograph", "Röntgenaufnahme"],
  ["Αντιστρεπτή πολφίτιδα", "Reversible pulpitis", "Reversible Pulpitis"],
  ["Μη αντιστρεπτή πολφίτιδα", "Irreversible pulpitis", "Irreversible Pulpitis"],
  ["Ακρορυζική αλλοίωση", "Periapical lesion", "Periapikale Läsion"],
  ["Ακρορριζική αλλοίωση", "Periapical lesion", "Periapikale Läsion"],
  ["Αυχενική υπερευαισθησία", "Cervical hypersensitivity", "Zervikale Überempfindlichkeit"],
  ["Αυχενική αποτριβή", "Cervical abrasion", "Zervikale Abrasion"],
  ["Σφηνοειδείς αυχενικές διαβρώσεις", "Wedge-shaped cervical lesions", "Keilförmige zervikale Läsionen"],
  ["Αποτριβές οδόντων", "Tooth wear", "Zahnabrasionen"],
  ["Κάταγμα έμφραξης", "Fractured restoration", "Füllungsfraktur"],
  ["Κάταγμα οδόντος", "Tooth fracture", "Zahnfraktur"],
  ["Ελλείπον δόντι", "Missing tooth", "Fehlender Zahn"],
  ["Υπόλοιπο ρίζας", "Retained root", "Wurzelrest"],
  ["Εσωτερική απορρόφηση", "Internal resorption", "Interne Resorption"],
  ["Εξωτερική απορρόφηση", "External resorption", "Externe Resorption"],
  ["Τερηδόνα", "Caries", "Karies"],
  ["Νέκρωση", "Necrosis", "Nekrose"],
  ["Απόστημα", "Abscess", "Abszess"],
  ["Συρίγγιο", "Fistula", "Fistel"],
  ["Υφίζηση", "Gingival recession", "Gingivarezession"],
  ["Διάβρωση οδόντος", "Tooth erosion", "Zahnerosion"],
  ["Χρωματισμός πλάκας", "Plaque disclosing", "Plaqueanfärbung"],
  ["Φθορίωση με νάρθηκα", "Fluoride treatment with tray", "Fluoridierung mit Schiene"],
  ["Πολφοτομή", "Pulpotomy", "Pulpotomie"],
  ["Τελική έμφραξη", "Final root filling", "Definitive Wurzelfüllung"],
  ["Διάνοιξη", "Access opening", "Trepanation"],
  ["Διεύρυνση ΡΣ", "Root-canal enlargement", "Wurzelkanalerweiterung"],
  ["Τοποθέτηση", "Placement of", "Einbringen von"],
  ["Αφαίρεση", "Removal of", "Entfernung von"],
  ["Επισκευή", "Repair of", "Reparatur von"],
  ["Συγκόλληση", "Cementation with", "Zementierung mit"],
  ["Κλείσιμο διαστήματος", "Diastema closure", "Diastemaschluss"],
  ["Απευαισθητοποίηση", "Desensitization", "Desensibilisierung"],
  ["Ουδέτερο στρώμα", "Liner/base", "Unterfüllung"],
  ["Προσωρινή έμφραξη", "Temporary restoration", "Provisorische Füllung"],
  ["Έλεγχος τραύματος", "Trauma review", "Traumakontrolle"],
  ["Ράματα", "Sutures", "Nähte"],
  ["Βιοψία", "Biopsy", "Biopsie"],
  ["Διάτρηση ιγμορείου", "Sinus perforation", "Kieferhöhlenperforation"],
  ["Θεραπεία", "Treatment of", "Behandlung von"],
];

const wordPairs = [
  ["γομφίου", "molar", "Molaren"], ["προγόμφιου", "premolar", "Prämolaren"],
  ["μονόριζου", "single-rooted tooth", "einwurzeligen Zahns"], ["προσθίου", "anterior tooth", "Frontzahns"],
  ["νεογιλού", "primary tooth", "Milchzahns"], ["εγκλείστου", "impacted tooth", "retinierten Zahns"],
  ["ημιεγκλείστου", "partially impacted tooth", "teilretinierten Zahns"], ["οδόντος", "tooth", "Zahns"],
  ["δοντιών", "teeth", "Zähnen"], ["δόντι", "tooth", "Zahn"], ["ρίζας", "root", "Wurzel"],
  ["άνω γνάθος", "upper jaw", "Oberkiefer"], ["κάτω γνάθος", "lower jaw", "Unterkiefer"],
  ["άνω", "upper", "oben"], ["κάτω", "lower", "unten"],
  ["παριακού βοθρίου", "buccal pit", "Bukkalgrübchen"], ["υπερώια αύλακα", "palatal groove", "Palatinalfurche"],
  ["κοπτικής γωνίας", "incisal angle", "Schneidekante"], ["ολόκληρο δόντι", "whole tooth", "ganzer Zahn"],
  ["προσωρινή", "temporary", "provisorisch"], ["παλιά", "old", "alt"], ["παλιό", "old", "alt"],
  ["παλιός", "old", "alt"], ["ανεπαρκής", "inadequate", "unzureichend"], ["ανεπαρκούς", "inadequate", "unzureichenden"],
  ["γενικευμένη", "generalized", "generalisiert"], ["εντοπισμένη", "localized", "lokalisiert"],
  ["μερικής", "partial", "Teil-"], ["ολικής", "complete", "Total-"], ["θερμοπλαστική", "thermoplastic", "thermoplastisch"],
  ["ακρυλική", "acrylic", "Acryl"], ["μαλακός", "soft", "weich"], ["με τόξο καταγραφής", "with facebow", "mit Gesichtsbogen"],
  ["ανά ημιμόριο", "per half-arch", "pro Kieferhälfte"], ["ανά τεταρτημόριο", "per quadrant", "pro Quadrant"],
  ["προσθίων", "anterior teeth", "Frontzähne"], ["οπισθίων", "posterior teeth", "Seitenzähne"],
  ["σκελετού", "framework", "Gerüst"], ["μύλης", "crown", "Krone"], ["στόματος", "mouth", "Mund"],
  ["φαρμάκου", "medicament", "Medikaments"], ["ευγενόλης", "eugenol", "Eugenol"],
];

function normalize(value) {
  return String(value ?? "")
    .trim().toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "")
    .replace(/ς/g, "σ").replace(/\s+/g, " ");
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

const exactTranslationMap = new Map(
  Object.entries(exactTranslations).map(([key, value]) => [normalize(key), value]),
);

function replaceInsensitive(value, needle, replacement) {
  return value.replace(new RegExp(escapeRegExp(needle), "giu"), replacement);
}

function expandSurfaceCodes(value, language) {
  const en = { mod: "mesio-occluso-distal", mo: "mesio-occlusal", od: "occluso-distal", m: "mesial", d: "distal", o: "occlusal", b: "buccal" };
  const de = { mod: "mesio-okkluso-distal", mo: "mesio-okklusal", od: "okkluso-distal", m: "mesial", d: "distal", o: "okklusal", b: "bukkal" };
  return value.replace(/\b(mod|mo|od|m|d|o|b)\b/gi, (match) => `(${(language === "en" ? en : de)[match.toLowerCase()]})`);
}

function translateDraft(original) {
  const key = normalize(original);
  const exact = exactTranslationMap.get(key);
  if (exact) {
    return {
      en: exact[0],
      de: exact[1],
      confidence: exact[2] ?? "High",
      reason: exact[3] ?? "Exact catalogue translation",
    };
  }

  let en = original;
  let de = original;
  let replacements = 0;
  for (const [greek, english, german] of phrasePairs) {
    const nextEn = replaceInsensitive(en, greek, english);
    const nextDe = replaceInsensitive(de, greek, german);
    if (nextEn !== en || nextDe !== de) replacements += 1;
    en = nextEn;
    de = nextDe;
  }
  for (const [greek, english, german] of wordPairs) {
    const nextEn = replaceInsensitive(en, greek, english);
    const nextDe = replaceInsensitive(de, greek, german);
    if (nextEn !== en || nextDe !== de) replacements += 1;
    en = nextEn;
    de = nextDe;
  }
  en = expandSurfaceCodes(en, "en").replace(/\s+/g, " ").trim();
  de = expandSurfaceCodes(de, "de").replace(/\s+/g, " ").trim();
  const hasGreek = /[\u0370-\u03ff]/iu.test(en) || /[\u0370-\u03ff]/iu.test(de);
  const legacyAbbreviation = /\b(χρ\.|συντ\.|τε\b|ρσ\b)|\bDF\d+/iu.test(original);
  const confidence = hasGreek || legacyAbbreviation ? "Needs review" : replacements > 0 ? "Medium" : "High";
  const reason = hasGreek
    ? "Draft still contains an untranslated Greek term"
    : legacyAbbreviation
      ? "Legacy abbreviation requires clinical confirmation"
      : replacements > 0
        ? "Phrase-based clinical draft; language review recommended"
        : "Existing English/German or trade name preserved";
  return { en, de, confidence, reason };
}

function includesAny(text, values) {
  const normalized = normalize(text);
  return values.some((value) => normalized.includes(normalize(value)));
}

function materialAndColour(name, groupSourceID) {
  const checks = [
    [["αμαλγαμ", "amalgam"], "Amalgam", "#64748B"],
    [["υαλοιονομερ", "glass-ionomer"], "Glass ionomer", "#14B8A6"],
    [["ρητιν", "composite", "bonding"], "Composite resin", "#2563EB"],
    [["ζιρκον"], "Zirconia", "#7C3AED"],
    [["μεταλλοκεραμ"], "Metal-ceramic", "#4F46E5"],
    [["ολοκεραμ", "porcelain", "κεραμικ"], "Ceramic", "#DB2777"],
    [["ακρυλ", "acrylic"], "Acrylic", "#F97316"],
    [["ολικη χυτη", "full-cast"], "Cast metal", "#B7791F"],
    [["caoh"], "Calcium hydroxide", "#0D9488"],
    [["mta"], "MTA", "#0F766E"],
    [["irm"], "IRM", "#F59E0B"],
    [["zno"], "Zinc oxide-eugenol", "#F59E0B"],
    [["eugen", "ευγεν"], "Eugenol", "#F59E0B"],
    [["implant", "εμφυτευ"], "Implant / titanium", "#475569"],
  ];
  for (const [needles, material, colour] of checks) {
    if (includesAny(name, needles)) return { material, colour };
  }
  const groupColours = {
    "1": "#2563EB", "13": "#2563EB", "2": "#0F766E", "3": "#D97706", "4": "#DC2626",
    "5": "#7C3AED", "7": "#F97316", "9": "#059669", "10": "#9333EA", "11": "#475569",
    "12": "#0891B2", "14": "#0EA5E9", "15": "#64748B", "16": "#64748B", "0": "#64748B",
  };
  return { material: "Not specified", colour: groupColours[groupSourceID] ?? "#64748B" };
}

function classifyProcedure(item, group) {
  const name = item.title ?? item.name ?? "";
  const groupID = String(item.therapyGroupSourceID ?? group?.sourceID ?? "0");
  const n = normalize(name);
  let workflow = "Patient-level / history only";
  let target = "Patient";
  let currentOverlay = "none";
  let futureIcon = "general-note";
  let confidence = "Medium";
  let rule = "Group-level conservative default";

  if (includesAny(n, ["γεφυρ", "bridge", "maryland", "ενδιαμεσο", "pontic"])) {
    workflow = "Bridge"; target = "Multi-tooth bridge units"; currentOverlay = "bridge"; futureIcon = "bridge"; confidence = "High"; rule = "Bridge/pontic keyword";
  } else if (groupID === "7" || includesAny(n, ["οδοντοστοιχ", "denture", "reline", "αναγομωση", "locator", "attachment", "dolder", "flipper", "φλιπερ"])) {
    workflow = "Removable prosthesis"; target = "Arch / removable components"; currentOverlay = "none"; futureIcon = "removable-prosthesis"; confidence = "High"; rule = "Removable-prosthesis group/keyword";
  } else if (includesAny(n, ["εμφραξ", "filling", "restoration", "amalgam", "inlay", "onlay", "ενθετο", "ανασυσταση", "sealant", "bonding", "ρητιν"])) {
    workflow = "Surface-based"; target = "Tooth surfaces (optional)"; currentOverlay = "filling"; futureIcon = includesAny(n, ["inlay", "onlay", "ενθετο"]) ? "inlay-onlay" : "filling"; confidence = "High"; rule = "Restoration/surface keyword";
  } else if (includesAny(n, ["στεφαν", "crown", "οψη", "veneer"])) {
    workflow = "Whole tooth"; target = "Single tooth"; currentOverlay = "crown"; futureIcon = includesAny(n, ["οψη", "veneer"]) ? "veneer" : "crown"; confidence = "High"; rule = "Crown/veneer keyword";
  } else if (includesAny(n, ["εξαγωγ", "extraction"])) {
    workflow = "Whole tooth"; target = "Single tooth"; currentOverlay = "extraction"; futureIcon = "extraction"; confidence = "High"; rule = "Extraction keyword";
  } else if (includesAny(n, ["εμφυτευ", "implant"])) {
    workflow = "Whole tooth"; target = "Single tooth / implant site"; currentOverlay = "implant"; futureIcon = "implant"; confidence = "High"; rule = "Implant keyword";
  } else if (groupID === "2" || includesAny(n, ["ενδοδοντ", "root canal", "πολφοτομ", "pulpotom", "πολφ", "caoh", "mta", "ριζεκτομ"])) {
    workflow = "Whole tooth"; target = "Single tooth"; currentOverlay = "rootCanal"; futureIcon = "root-canal"; confidence = groupID === "2" ? "High" : "Medium"; rule = "Endodontic group/keyword";
  } else if (groupID === "11") {
    workflow = "Whole tooth"; target = "Single tooth / implant site"; currentOverlay = "implant"; futureIcon = "implant-component"; confidence = "High"; rule = "Implantology group";
  } else if (groupID === "3") {
    if (includesAny(n, ["παλια εμφραξ", "old composite", "old amalgam"])) {
      workflow = "Surface-based"; target = "Tooth surfaces (optional)"; currentOverlay = "filling"; futureIcon = "existing-restoration"; confidence = "High"; rule = "Existing restoration diagnosis";
    } else if (includesAny(n, ["παλια στεφαν", "old crown"])) {
      workflow = "Whole tooth"; target = "Single tooth"; currentOverlay = "crown"; futureIcon = "existing-crown"; confidence = "High"; rule = "Existing crown diagnosis";
    } else if (includesAny(n, ["παλια γεφυρ", "old bridge"])) {
      workflow = "Bridge"; target = "Multi-tooth bridge units"; currentOverlay = "bridge"; futureIcon = "existing-bridge"; confidence = "High"; rule = "Existing bridge diagnosis";
    } else if (includesAny(n, ["ακτινογραφ", "radiograph", "panoram"])) {
      workflow = "Patient-level / history only"; target = "Patient / imaging record"; futureIcon = "radiograph"; confidence = "High"; rule = "Imaging diagnosis";
    } else {
      workflow = "Whole tooth"; target = "Single tooth (if clinically specific)"; futureIcon = includesAny(n, ["τερηδον", "caries"]) ? "caries" : includesAny(n, ["καταγμα", "fracture"]) ? "fracture" : includesAny(n, ["ελλειπον", "missing tooth"]) ? "missing-tooth" : "diagnosis-marker"; confidence = item.toothRequired === false ? "Medium" : "High"; rule = "Tooth diagnosis group";
    }
  } else if (groupID === "4") {
    workflow = item.toothRequired === false ? "Patient-level / history only" : "Whole tooth";
    target = item.toothRequired === false ? "Patient / surgical episode" : "Single tooth";
    futureIcon = "oral-surgery"; confidence = item.toothRequired == null ? "Medium" : "High"; rule = "Oral-surgery group with legacy tooth flag";
  } else if (groupID === "5") {
    workflow = "Whole tooth"; target = "Single tooth"; futureIcon = "fixed-prosthetic"; confidence = "Medium"; rule = "Fixed-prosthodontic group fallback";
  } else if (groupID === "9") {
    workflow = "Patient-level / history only"; target = "Patient / quadrant / periodontal chart"; futureIcon = "periodontal"; confidence = "Medium"; rule = "Periodontology group; exact target varies";
  } else if (groupID === "10") {
    workflow = "Patient-level / history only"; target = "Patient / arch"; futureIcon = "orthodontic"; confidence = "High"; rule = "Orthodontic group";
  } else if (groupID === "12") {
    workflow = "Patient-level / history only"; target = "Patient / arch"; futureIcon = includesAny(n, ["λευκαν", "whitening"]) ? "whitening" : includesAny(n, ["ναρθηκ", "splint"]) ? "splint" : "prevention"; confidence = "High"; rule = "Prevention group";
  } else if (groupID === "14") {
    workflow = includesAny(n, ["εμφραξ", "filling"]) ? "Surface-based" : "Patient-level / history only";
    target = workflow === "Surface-based" ? "Tooth surfaces (optional)" : "Patient / tooth as documented";
    currentOverlay = workflow === "Surface-based" ? "filling" : "none"; futureIcon = workflow === "Surface-based" ? "filling" : "pediatric-prevention"; confidence = "High"; rule = "Pediatric procedure keyword/group";
  } else if (groupID === "15") {
    workflow = "Patient-level / history only"; target = "Patient"; futureIcon = includesAny(n, ["συνταγ", "prescription"]) ? "prescription" : includesAny(n, ["παραπομπ", "referral"]) ? "referral" : includesAny(n, ["cbct", "ακτινογραφ", "radiograph"]) ? "radiograph" : "general-note"; confidence = "High"; rule = "General-work group";
  } else {
    confidence = "Needs review"; rule = "Uncategorized legacy item; safe patient-level fallback";
  }

  if (groupID === "0" || groupID === "16") {
    confidence = "Needs review";
    rule = `${rule}; legacy source category requires confirmation`;
  }
  if (item.toothRequired === false && ["Whole tooth", "Surface-based", "Bridge"].includes(workflow)) {
    confidence = confidence === "High" ? "Medium" : confidence;
    rule = `${rule}; source toothRequired=false conflicts with suggested target`;
  }
  return { workflow, target, currentOverlay, futureIcon, confidence, rule };
}

function signedColourToHex(value) {
  const unsigned = Number(value ?? 0) >>> 0;
  return `#${(unsigned & 0xffffff).toString(16).padStart(6, "0").toUpperCase()}`;
}

const groupsById = new Map(source.therapy_groups.map((group) => [String(group.id), group]));
const groupsBySource = new Map(source.therapy_groups.map((group) => [String(group.sourceID ?? "0"), group]));
const auditRows = source.procedure_catalog.map((item) => {
  const group = groupsById.get(String(item.therapyGroupID)) ?? groupsBySource.get(String(item.therapyGroupSourceID ?? "0"));
  const groupSourceID = String(item.therapyGroupSourceID ?? group?.sourceID ?? "0");
  const translation = translateDraft(item.title ?? item.name ?? "");
  const classification = classifyProcedure(item, group);
  const material = materialAndColour(item.title ?? item.name ?? "", groupSourceID);
  // Preserve DentalWin's imported group colour as the actual default. Material
  // recognition remains useful metadata, while a later settings override can
  // intentionally replace the inherited colour for a procedure.
  material.colour = group == null ? material.colour : signedColourToHex(group.colorValue);
  const reviewNeeded = translation.confidence === "Needs review" || classification.confidence !== "High" || groupSourceID === "0" || groupSourceID === "16";
  return {
    groupSourceID,
    sourceCode: String(item.sourceCode ?? ""),
    groupGreek: group?.title ?? group?.name ?? "Uncategorized legacy review",
    procedureGreek: item.title ?? item.name ?? "",
    english: translation.en,
    german: translation.de,
    basePrice: Number(item.basePrice ?? 0),
    toothRequired: item.toothRequired == null ? "Unknown" : item.toothRequired ? "Yes" : "No",
    ...classification,
    material: material.material,
    colour: material.colour,
    translationConfidence: translation.confidence,
    translationReason: translation.reason,
    reviewNeeded: reviewNeeded ? "Yes" : "No",
    reviewerDecision: "",
    reviewerNotes: "",
    recordID: String(item.record_id ?? item.id ?? ""),
  };
}).sort((a, b) => Number(a.groupSourceID || 999) - Number(b.groupSourceID || 999) || a.procedureGreek.localeCompare(b.procedureGreek, "el"));

const reviewRows = auditRows.filter((row) => row.reviewNeeded === "Yes");
const lastAuditRow = 5 + auditRows.length;

await fs.mkdir(path.join(workspace, "tmp", "catalogue-audit"), { recursive: true });
await fs.writeFile(
  path.join(workspace, "tmp", "catalogue-audit", "audit_rows.json"),
  JSON.stringify(auditRows, null, 2),
  "utf8",
);

const workbook = Workbook.create();
const summarySheet = workbook.worksheets.add("Summary");
const auditSheet = workbook.worksheets.add("Catalogue Audit");
const reviewSheet = workbook.worksheets.add("Review Queue");
const groupsSheet = workbook.worksheets.add("Groups");
const guideSheet = workbook.worksheets.add("Icon Colour Guide");
const methodSheet = workbook.worksheets.add("Method");

const palette = {
  navy: "#12304A", teal: "#0F766E", aqua: "#DFF7F3", sky: "#E8F3FB", white: "#FFFFFF",
  ink: "#17212B", muted: "#5F6B76", line: "#D6E2EA", amber: "#FEF3C7", red: "#FEE2E2", green: "#DCFCE7",
};

function titleBand(sheet, title, subtitle, endColumn) {
  sheet.showGridLines = false;
  sheet.getRange(`A1:${endColumn}2`).merge();
  sheet.getRange("A1").values = [[title]];
  sheet.getRange(`A1:${endColumn}2`).format = {
    fill: palette.navy,
    font: { bold: true, color: palette.white, size: 18 },
    verticalAlignment: "center",
    wrapText: true,
  };
  sheet.getRange(`A3:${endColumn}3`).merge();
  sheet.getRange("A3").values = [[subtitle]];
  sheet.getRange(`A3:${endColumn}3`).format = {
    fill: palette.aqua,
    font: { color: palette.ink, italic: true, size: 10 },
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "outside", style: "thin", color: palette.line },
  };
  sheet.getRange("1:3").format.rowHeight = 25;
}

function styleHeader(range) {
  range.format = {
    fill: palette.teal,
    font: { bold: true, color: palette.white, size: 10 },
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "all", style: "thin", color: palette.line },
  };
  range.format.rowHeight = 36;
}

titleBand(summarySheet, "Apexo × DentalWin — Therapy Catalogue Audit", "Read-only review workbook. No catalogue records were modified. Draft translations, workflow classifications, icons, and colours require approval before any import/update.", "J");
summarySheet.getRange("A5:B10").values = [
  ["Audit metric", "Value"], ["Total procedures", null], ["Procedures needing review", null],
  ["High-confidence workflow mappings", null], ["High-confidence translations", null], ["Imported therapy groups", null],
];
summarySheet.getRange("B6:B10").formulas = [
  [`=COUNTA('Catalogue Audit'!$D$6:$D$${lastAuditRow})`],
  [`=COUNTIF('Catalogue Audit'!$S$6:$S$${lastAuditRow},"Yes")`],
  [`=COUNTIF('Catalogue Audit'!$P$6:$P$${lastAuditRow},"High")`],
  [`=COUNTIF('Catalogue Audit'!$O$6:$O$${lastAuditRow},"High")`],
  [`=COUNTA(Groups!$A$6:$A$${5 + source.therapy_groups.length})`],
];
styleHeader(summarySheet.getRange("A5:B5"));
summarySheet.getRange("A6:B10").format = { borders: { preset: "all", style: "thin", color: palette.line } };
summarySheet.getRange("D5:E11").values = [
  ["Suggested workflow", "Count"], ["Surface-based", null], ["Whole tooth", null], ["Bridge", null],
  ["Removable prosthesis", null], ["Patient-level / history only", null], ["Other", null],
];
summarySheet.getRange("E6:E10").formulas = [
  [`=COUNTIF('Catalogue Audit'!$I$6:$I$${lastAuditRow},D6)`],
  [`=COUNTIF('Catalogue Audit'!$I$6:$I$${lastAuditRow},D7)`],
  [`=COUNTIF('Catalogue Audit'!$I$6:$I$${lastAuditRow},D8)`],
  [`=COUNTIF('Catalogue Audit'!$I$6:$I$${lastAuditRow},D9)`],
  [`=COUNTIF('Catalogue Audit'!$I$6:$I$${lastAuditRow},D10)`],
];
summarySheet.getRange("E11").formulas = [[`=B6-SUM(E6:E10)`]];
styleHeader(summarySheet.getRange("D5:E5"));
summarySheet.getRange("D6:E11").format = { borders: { preset: "all", style: "thin", color: palette.line } };
summarySheet.getRange("G5:J5").merge();
summarySheet.getRange("G5").values = [["How to review"]];
styleHeader(summarySheet.getRange("G5:J5"));
summarySheet.getRange("G6:J11").merge();
summarySheet.getRange("G6").values = [[
  "1. Filter Catalogue Audit by Review needed = Yes or open Review Queue.\n2. Confirm the automatic workflow, target, and overlay/icon.\n3. Review the English/German drafts, especially rows marked Needs review.\n4. Source group colours are retained by default; override a treatment only when intentionally desired.\n5. Set Reviewer decision to Approve, Change, Skip, or Needs discussion.\n\nThis workbook is a proposal—not a clinical or accounting source of truth."
]];
summarySheet.getRange("G6:J11").format = { fill: palette.sky, font: { color: palette.ink }, wrapText: true, verticalAlignment: "top", borders: { preset: "all", style: "thin", color: palette.line } };
summarySheet.getRange("A13:J13").merge();
summarySheet.getRange("A13").values = [["Important: implemented overlay keys are currently limited to none, filling, crown, rootCanal, extraction, implant, and bridge. The Future icon column deliberately proposes a broader vocabulary for later design work."]];
summarySheet.getRange("A13:J13").format = { fill: palette.amber, font: { color: palette.ink, bold: true }, wrapText: true, borders: { preset: "outside", style: "thin", color: "#F59E0B" } };
summarySheet.getRange("A5:J13").format.verticalAlignment = "center";
summarySheet.getRange("A1:J13").format.autofitRows();
for (const [column, width] of Object.entries({ A: 30, B: 14, C: 3, D: 31, E: 14, F: 3, G: 18, H: 18, I: 18, J: 18 })) summarySheet.getRange(`${column}1:${column}13`).format.columnWidth = width;
summarySheet.freezePanes.freezeRows(4);

titleBand(auditSheet, "Catalogue Audit — all imported procedures", "Filter by workflow, icon, confidence, material, or review status. Greek source names and IDs are preserved exactly; reviewer decision and notes are intentionally blank/editable.", "V");
const auditHeaders = ["Group source ID", "Source code", "Group — Greek", "Procedure — Greek (source)", "English draft", "German draft", "Base price", "Tooth required (source)", "Suggested workflow", "Suggested target", "Current overlay key", "Future icon suggestion", "Material / brand family", "Suggested colour (HEX)", "Translation confidence", "Mapping confidence", "Mapping rule / reason", "Translation note", "Review needed", "Reviewer decision", "Reviewer notes", "Source record ID"];
const auditMatrix = [auditHeaders, ...auditRows.map((r) => [r.groupSourceID, r.sourceCode, r.groupGreek, r.procedureGreek, r.english, r.german, r.basePrice, r.toothRequired, r.workflow, r.target, r.currentOverlay, r.futureIcon, r.material, r.colour, r.translationConfidence, r.confidence, r.rule, r.translationReason, r.reviewNeeded, r.reviewerDecision, r.reviewerNotes, r.recordID])];
auditSheet.getRangeByIndexes(4, 0, auditMatrix.length, auditHeaders.length).values = auditMatrix;
styleHeader(auditSheet.getRange("A5:V5"));
const auditTable = auditSheet.tables.add(`A5:V${lastAuditRow}`, true, "CatalogueAuditTable");
auditTable.style = "TableStyleMedium2";
auditTable.showFilterButton = true;
auditSheet.freezePanes.freezeRows(5);
auditSheet.freezePanes.freezeColumns(4);
auditSheet.getRange(`G6:G${lastAuditRow}`).setNumberFormat("0.00");
auditSheet.getRange(`N6:N${lastAuditRow}`).setNumberFormat("@");
auditSheet.getRange(`T6:T${lastAuditRow}`).dataValidation = { rule: { type: "list", values: ["Approve", "Change", "Skip", "Needs discussion"] } };
auditSheet.getRange(`D6:F${lastAuditRow}`).format.wrapText = true;
auditSheet.getRange(`I6:R${lastAuditRow}`).format.wrapText = true;
auditSheet.getRange(`U6:U${lastAuditRow}`).format.wrapText = true;
auditSheet.getRange(`A5:V${lastAuditRow}`).format.verticalAlignment = "top";
for (let i = 0; i < auditRows.length; i += 1) {
  const row = 6 + i;
  const translationCell = auditSheet.getRange(`O${row}`);
  const mappingCell = auditSheet.getRange(`P${row}`);
  const reviewCell = auditSheet.getRange(`S${row}`);
  const colourCell = auditSheet.getRange(`N${row}`);
  const fillFor = (value) => value === "High" ? palette.green : value === "Medium" ? palette.amber : palette.red;
  translationCell.format.fill = fillFor(auditRows[i].translationConfidence);
  mappingCell.format.fill = fillFor(auditRows[i].confidence);
  reviewCell.format.fill = auditRows[i].reviewNeeded === "Yes" ? palette.red : palette.green;
  colourCell.format.fill = auditRows[i].colour;
  colourCell.format.font = { color: "#FFFFFF", bold: true };
}
const auditWidths = { A: 12, B: 12, C: 24, D: 36, E: 38, F: 38, G: 12, H: 16, I: 23, J: 28, K: 18, L: 23, M: 23, N: 18, O: 18, P: 18, Q: 42, R: 38, S: 14, T: 20, U: 30, V: 20 };
for (const [column, width] of Object.entries(auditWidths)) auditSheet.getRange(`${column}5:${column}${lastAuditRow}`).format.columnWidth = width;

titleBand(reviewSheet, "Review Queue", "Static snapshot of rows with non-high mapping confidence, untranslated Greek fragments, legacy abbreviations, or legacy categories. Final decisions should also be recorded in Catalogue Audit.", "N");
const reviewHeaders = ["Group ID", "Source code", "Group — Greek", "Procedure — Greek", "English draft", "German draft", "Suggested workflow", "Target", "Current overlay", "Future icon", "Colour", "Translation confidence", "Mapping confidence", "Why review"];
const reviewMatrix = [reviewHeaders, ...reviewRows.map((r) => [r.groupSourceID, r.sourceCode, r.groupGreek, r.procedureGreek, r.english, r.german, r.workflow, r.target, r.currentOverlay, r.futureIcon, r.colour, r.translationConfidence, r.confidence, `${r.rule}; ${r.translationReason}`])];
reviewSheet.getRangeByIndexes(4, 0, reviewMatrix.length, reviewHeaders.length).values = reviewMatrix;
styleHeader(reviewSheet.getRange("A5:N5"));
if (reviewRows.length > 0) {
  const reviewTable = reviewSheet.tables.add(`A5:N${5 + reviewRows.length}`, true, "ReviewQueueTable");
  reviewTable.style = "TableStyleMedium9";
  reviewTable.showFilterButton = true;
  reviewSheet.getRange(`D6:N${5 + reviewRows.length}`).format.wrapText = true;
  for (let i = 0; i < reviewRows.length; i += 1) {
    const row = 6 + i;
    reviewSheet.getRange(`K${row}`).format.fill = reviewRows[i].colour;
    reviewSheet.getRange(`K${row}`).format.font = { color: "#FFFFFF", bold: true };
  }
}
reviewSheet.freezePanes.freezeRows(5);
reviewSheet.freezePanes.freezeColumns(4);
const reviewWidths = { A: 10, B: 12, C: 23, D: 34, E: 36, F: 36, G: 22, H: 26, I: 18, J: 22, K: 14, L: 18, M: 18, N: 48 };
for (const [column, width] of Object.entries(reviewWidths)) reviewSheet.getRange(`${column}5:${column}${Math.max(6, 5 + reviewRows.length)}`).format.columnWidth = width;

titleBand(groupsSheet, "Therapy Groups", "Imported groups keep their DentalWin source colours. Procedure counts and proposed bilingual labels are shown alongside the legacy categories that still need cleanup.", "J");
const orderedGroups = [...source.therapy_groups].sort((a, b) => Number(a.displayOrder ?? 999) - Number(b.displayOrder ?? 999) || String(a.title).localeCompare(String(b.title), "el"));
const groupHeaders = ["Source ID", "Greek source name", "English draft", "German draft", "Source colour", "Procedure count", "Suggested default colour", "Hidden", "Review status", "Notes"];
const groupMatrix = [groupHeaders, ...orderedGroups.map((g) => {
  const sid = String(g.sourceID ?? "0");
  const tr = groupTranslations[sid] ?? [g.title ?? g.name ?? "", g.title ?? g.name ?? ""];
  const needsReview = sid === "0" || sid === "16" || !groupTranslations[sid];
  const sourceColour = signedColourToHex(g.colorValue);
  return [sid, g.title ?? g.name ?? "", tr[0], tr[1], sourceColour, null, sourceColour, Boolean(g.hidden), needsReview ? "Needs review" : "Draft ready", needsReview ? "Legacy category; source colour retained while merge/rename/archive is decided." : "DentalWin source colour retained as the default."];
})];
groupsSheet.getRangeByIndexes(4, 0, groupMatrix.length, groupHeaders.length).values = groupMatrix;
styleHeader(groupsSheet.getRange("A5:J5"));
for (let i = 0; i < orderedGroups.length; i += 1) groupsSheet.getRange(`F${6 + i}`).formulas = [[`=COUNTIF('Catalogue Audit'!$A$6:$A$${lastAuditRow},A${6 + i})`]];
const groupsTable = groupsSheet.tables.add(`A5:J${5 + orderedGroups.length}`, true, "TherapyGroupsTable");
groupsTable.style = "TableStyleMedium2";
groupsTable.showFilterButton = true;
for (let i = 0; i < orderedGroups.length; i += 1) {
  const row = 6 + i;
  groupsSheet.getRange(`E${row}`).format.fill = groupMatrix[i + 1][4];
  groupsSheet.getRange(`G${row}`).format.fill = groupMatrix[i + 1][6];
  groupsSheet.getRange(`E${row}:G${row}`).format.font = { color: "#FFFFFF", bold: true };
  groupsSheet.getRange(`I${row}`).format.fill = groupMatrix[i + 1][8] === "Needs review" ? palette.red : palette.green;
}
groupsSheet.freezePanes.freezeRows(5);
for (const [column, width] of Object.entries({ A: 10, B: 30, C: 30, D: 32, E: 16, F: 16, G: 22, H: 10, I: 18, J: 46 })) groupsSheet.getRange(`${column}5:${column}${5 + orderedGroups.length}`).format.columnWidth = width;

titleBand(guideSheet, "Icon & Colour Guide", "Controlled vocabulary for current overlays and future icon suggestions. DentalWin group colours remain the actual defaults; colours below are optional reference ideas for deliberate per-treatment overrides.", "H");
const iconGuide = [
  ["Icon key", "Meaning", "Implemented now", "Typical workflow", "Visual placement", "Suggested default", "Material variants", "Notes"],
  ["none", "No tooth drawing", "Yes", "Patient-level", "Timeline only", "#64748B", "N/A", "Treatment remains in history without a tooth overlay."],
  ["filling", "Restoration", "Yes", "Surface-based", "Selected surfaces", "#2563EB", "Composite, amalgam, glass ionomer, temporary", "Colour should follow recognised material, then user override."],
  ["crown", "Crown", "Yes", "Whole tooth", "Crown contour; facial/occlusal/oral", "#7C3AED", "Zirconia, metal-ceramic, ceramic, acrylic, cast metal", "Use full-tooth coverage; do not cover the root."],
  ["rootCanal", "Root-canal treatment", "Yes", "Whole tooth", "Root path on facial view only", "#0F766E", "Material-independent", "No lingual/oral duplicate is needed."],
  ["extraction", "Extraction / absent after extraction", "Yes", "Whole tooth", "X / absent-tooth state", "#DC2626", "N/A", "X may remain on the facial and occlusal views."],
  ["implant", "Implant", "Yes", "Whole tooth", "Implant fixture/root region", "#475569", "Titanium, zirconia, brand variants", "Brand can be stored separately from colour."],
  ["bridge", "Bridge span and units", "Yes", "Bridge", "Connected multi-tooth units", "#7C3AED", "Crown material variants", "Unit roles: abutment, pontic, cantilever."],
  ["inlay-onlay", "Inlay / onlay", "Future", "Surface-based", "Occlusal/surface geometry", "#DB2777", "Ceramic, composite, zirconia", "Can reuse surface selection but should have a distinct visual."],
  ["veneer", "Veneer", "Future", "Whole tooth", "Facial crown surface", "#EC4899", "Porcelain, composite", "Prefer a facial-only shell marker."],
  ["removable-prosthesis", "Denture / removable component", "Future", "Removable prosthesis", "Arch-level diagram", "#F97316", "Acrylic, thermoplastic, metal framework", "Do not force it into a single-tooth overlay."],
  ["diagnosis-marker", "Tooth diagnosis", "Future", "Whole tooth", "Small badge or contour", "#D97706", "Caries, lesion, fracture, sensitivity", "Use separate symbols rather than one generic square."],
  ["caries", "Caries", "Future", "Whole tooth / surface", "Surface or small lesion marker", "#B45309", "N/A", "Can be surface-selectable when known."],
  ["missing-tooth", "Missing tooth", "Future", "Whole tooth", "Absent-tooth state", "#6B7280", "N/A", "Distinguish pre-existing absence from completed extraction."],
  ["radiograph", "Imaging", "Future", "Patient-level", "Timeline badge", "#0EA5E9", "Periapical, bitewing, panoramic, CBCT", "Not a tooth overlay unless linked to a tooth record."],
  ["periodontal", "Periodontal work", "Future", "Patient/quadrant", "Chart/quadrant badge", "#059669", "N/A", "Better represented in a periodontal chart than on one tooth."],
  ["orthodontic", "Orthodontic work", "Future", "Patient/arch", "Arch badge", "#9333EA", "Appliance-specific", "Retainers and appliances need arch-level representation."],
  ["splint", "Splint / guard", "Future", "Patient/arch", "Arch badge", "#0891B2", "Hard, soft, sports", "Material/type remains editable."],
  ["prescription", "Prescription", "Future", "Patient-level", "Timeline badge", "#64748B", "N/A", "No odontogram overlay."],
  ["referral", "Referral", "Future", "Patient-level", "Timeline badge", "#64748B", "N/A", "No odontogram overlay."],
];
guideSheet.getRangeByIndexes(4, 0, iconGuide.length, iconGuide[0].length).values = iconGuide;
styleHeader(guideSheet.getRange("A5:H5"));
const guideTable = guideSheet.tables.add(`A5:H${4 + iconGuide.length}`, true, "IconColourGuideTable");
guideTable.style = "TableStyleMedium4";
for (let i = 1; i < iconGuide.length; i += 1) {
  const row = 5 + i;
  guideSheet.getRange(`F${row}`).format.fill = iconGuide[i][5];
  guideSheet.getRange(`F${row}`).format.font = { color: "#FFFFFF", bold: true };
  guideSheet.getRange(`C${row}`).format.fill = iconGuide[i][2] === "Yes" ? palette.green : palette.amber;
}
guideSheet.getRange(`B6:H${4 + iconGuide.length}`).format.wrapText = true;
guideSheet.freezePanes.freezeRows(5);
for (const [column, width] of Object.entries({ A: 24, B: 27, C: 16, D: 23, E: 31, F: 20, G: 36, H: 50 })) guideSheet.getRange(`${column}5:${column}${4 + iconGuide.length}`).format.columnWidth = width;

titleBand(methodSheet, "Method, limits, and approval gates", "This sheet explains exactly what the audit did and did not do.", "H");
const methodRows = [
  ["Topic", "Method / decision", "Why it matters"],
  ["Scope", "Read-only extraction of therapy_groups and procedure_catalog from the local Apexo PocketBase SQLite file.", "No patient, appointment, treatment-history, or financial records were included in the workbook."],
  ["Source fidelity", "Original Greek group/procedure names, source codes, prices, toothRequired flags, and record IDs were preserved.", "Nothing is silently renamed or discarded."],
  ["Workflow classification", "Procedure-specific keywords take priority, then group-level fallbacks. Ambiguous items use a conservative patient-level/history-only or medium-confidence suggestion.", "Prevents the fixed/removable Greek substring error and avoids forcing uncertain items onto teeth."],
  ["Surface selection", "Only fillings/restorations and a small related set default to surface-based. Crowns, extractions, implants, and endodontic work default to whole-tooth workflows.", "Reduces unnecessary clicks during daily use."],
  ["Overlays", "Current overlay keys match Apexo's implemented enum. Future icon suggestions are a separate design backlog.", "A procedure can be recognised without pretending an unimplemented icon already exists."],
  ["Colours", "DentalWin source group colours are retained as the inherited defaults for every treatment. Material/brand recognition does not silently replace them.", "The settings colour picker can deliberately override an individual treatment when wanted."],
  ["Translations", "English and German are draft clinical translations. Trade names are preserved. Mixed-language legacy abbreviations and residual Greek fragments are flagged Needs review.", "Prevents an uncertain translation from becoming clinical truth."],
  ["Review queue", "A static snapshot includes any non-high mapping confidence, Needs-review translation, or legacy category.", "Makes human review practical without hiding the complete catalogue."],
  ["Approval gate", "Do not import these suggestions into the live catalogue until the clinic approves workflow, icon, colour, English, and German fields.", "The audit itself makes no live changes."],
  ["Generated", "29 August 2026, Europe/Athens", "Snapshot date for traceability."],
];
methodSheet.getRangeByIndexes(4, 0, methodRows.length, 3).values = methodRows;
styleHeader(methodSheet.getRange("A5:C5"));
const methodTable = methodSheet.tables.add(`A5:C${4 + methodRows.length}`, true, "MethodTable");
methodTable.style = "TableStyleMedium2";
methodSheet.getRange(`B6:C${4 + methodRows.length}`).format.wrapText = true;
methodSheet.getRange(`A5:C${4 + methodRows.length}`).format.verticalAlignment = "top";
methodSheet.getRange(`A5:A${4 + methodRows.length}`).format.columnWidth = 24;
methodSheet.getRange(`B5:B${4 + methodRows.length}`).format.columnWidth = 78;
methodSheet.getRange(`C5:C${4 + methodRows.length}`).format.columnWidth = 54;
methodSheet.freezePanes.freezeRows(5);

await fs.mkdir(outputDir, { recursive: true });
await fs.mkdir(renderDir, { recursive: true });

const formulaInspection = await workbook.inspect({ kind: "formula", sheetId: "Summary", range: "A1:J20", maxChars: 6000, options: { maxResults: 50 } });
console.log("SUMMARY_FORMULAS\n" + formulaInspection.ndjson);
const summaryInspection = await workbook.inspect({ kind: "region", sheetId: "Summary", range: "A1:J14", maxChars: 8000 });
console.log("SUMMARY_REGION\n" + summaryInspection.ndjson);
const auditInspection = await workbook.inspect({ kind: "region", sheetId: "Catalogue Audit", range: "A1:V12", maxChars: 12000 });
console.log("AUDIT_REGION\n" + auditInspection.ndjson);

for (const sheetName of ["Summary", "Catalogue Audit", "Review Queue", "Groups", "Icon Colour Guide", "Method"]) {
  const preview = await workbook.render({ sheetName, autoCrop: "all", scale: sheetName === "Catalogue Audit" || sheetName === "Review Queue" ? 0.35 : 0.8, format: "png" });
  const previewBytes = new Uint8Array(await preview.arrayBuffer());
  await fs.writeFile(path.join(renderDir, `${sheetName.replaceAll(" ", "_")}.png`), previewBytes);
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);

const residualGreek = auditRows.filter((row) => row.translationConfidence === "Needs review");
console.log(JSON.stringify({
  outputPath,
  procedures: auditRows.length,
  groups: orderedGroups.length,
  reviewQueue: reviewRows.length,
  translationNeedsReview: residualGreek.length,
  renderedSheets: 6,
}, null, 2));
