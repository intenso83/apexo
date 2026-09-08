# Apexo Clinical Beta 0.15.0-beta.4

This beta packages the clinical work completed through 6 September 2026 for focused colleague feedback. It preserves Apexo's normal patient, calendar, notes, expenses, accounts, offline and PocketBase workflows.

## Quick start

1. Extract the beta ZIP completely.
2. Open `Apexo-Windows-Portable/apexo.exe`. Keep the executable beside its `data` and DLL folders.
3. For a safe first look, choose **Demo**. Apexo now opens a dedicated **Clinical beta** home screen with direct buttons for the new clinical tools. Demo mode uses fake patients, includes the 279-treatment demonstration catalogue, and never connects to PocketBase.
4. To test with an existing Apexo clinic, first make a PocketBase backup. Then enter the clinic's normal server URL, email and password on the login screen.

The web build is included for a tester who already knows how to serve static web files. Opening `index.html` directly is not supported.

## What is new in this beta

- **Therapy catalogue:** editable groups, source colours, prices, durations and automatic handling rules for fillings, whole-tooth work, bridges, removable prosthetics and general work. Greek treatment names include reviewed English and German translations.
- **Clinical odontogram:** 32 permanent teeth with facial, occlusal and oral views; an editable DentalWin-style surface selector; tooth-specific history; correctly filtered treatment groups; one-click clinical-status buttons with Completed as the default; connected bridge and removable-prosthesis mapping; and planned/completed overlays for fillings, crowns, endodontics, extraction and implants.
- **Treatment planning:** multiple alternatives per patient, line and whole-plan discounts, compact financial summaries, Greek/English/German patient views, branded A4 PDF, consent states, signed-file attachment and conversion of selected plan items into completed treatment records.
- **Appointments and Google Calendar:** patient search while creating an appointment, contact details from the patient record, a link back to Apexo, per-user Google authorization, manual sync, low-traffic automatic sync after changes, and consistent 24-hour time entry/display.
- **Patient record:** responsive demographic/contact fields and immutable, dated medical-history revisions.
- **Periodontal chart:** six sites per permanent tooth, rapid keyboard entry with automatic advance, PD/GM/CAL, bleeding, plaque, suppuration, mobility, furcation, missing teeth and implants. Lightweight upper/lower pocket-depth graphs and both completed and blank A4 PDF charts are included.
- **Beta navigation:** Demo opens on a clinical feature launcher. The original circular tooth wheel remains available for quick appointment notes and now links directly to the patient's richer clinical record.

## Suggested 15-minute feedback pass

1. Enter Demo and open a patient.
2. Add a filling and a crown in the odontogram; confirm planned work is visually distinct from completed work.
3. Create two treatment-plan alternatives, add a discount and preview the patient PDF in another language.
4. Create a periodontal exam and type a run of pocket depths without using the mouse; print both PDF modes.
5. If using a backed-up PocketBase clinic, create an appointment from patient search and test Google Calendar only after completing its OAuth settings.

Please report the action you attempted, what you expected, what happened, and a screenshot if possible.

## Beta boundaries

- This is a feedback build, not a production release. Use a current PocketBase backup before connecting real clinic data.
- Demo changes are disposable and Google Calendar is disabled in Demo.
- A colleague's own PocketBase clinic is not automatically populated with this practice's catalogue; administrators can add their own groups and procedures. The complete 279-item fixture is Demo-only.
- Treatment plans are local-first in this beta and do not yet synchronize between devices. Completing a plan item writes the normal treatment/odontogram event; it does not create a payment.
- The periodontal chart currently covers permanent dentition. Voice-entry architecture is reserved, but voice recording is not enabled.
- Google Calendar requires an administrator-provided public OAuth client ID and authorization by each Apexo user. OAuth tokens are not stored in PocketBase.
- The privacy-safe Google defaults use the generic `Dental appointment` title and omit the address. For this practice's agreed workflow, configure the testing user for the patient-name title and explicitly enable telephone, mobile, email, and address before the calendar test.
