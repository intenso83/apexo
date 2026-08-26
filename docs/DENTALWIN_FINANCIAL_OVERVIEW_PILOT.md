# DentalWin Financial Overview Pilot

## Purpose

This pilot adds a read-only **Financial overview** tab inside a saved patient. It gives the owner a useful view now without pretending that unreconciled DentalWin money is an authoritative balance.

The pilot does not write payments, create invoices, change appointment money, modify DentalWin, or connect to a production server.

## What the tab shows

The screen deliberately keeps two sources separate:

1. **Current Apexo financials** — charges, payments and resulting underpaid/overpaid state calculated only from eligible completed Apexo appointments.
2. **Legacy DentalWin financial snapshot** — the raw `xreosi`, `pistosi` and `sinolo` values already preserved on imported treatment-history entries.

The legacy section is labelled as non-authoritative. It includes a discrepancy warning when the DentalWin source total does not equal recorded charges minus recorded credits. Planned treatment values are not mixed into completed-history totals.

Access to the tab follows Apexo's existing revenue read permission. The UI contains no editing controls.

## Private aggregate findings

The five-patient private pilot contained 121 historical treatment rows:

- recorded `xreosi` total: 7,250 across 59 non-zero rows;
- recorded `pistosi` total: 5,310 across 26 non-zero rows;
- recorded `sinolo` total: 4,720 across 54 non-zero rows, including three negative values;
- only 65 of 121 rows satisfied `sinolo = xreosi - pistosi`.

These totals are aggregate-only and contain no patient identity.

The analysis also found a critical false-link risk. Each of the five pilot patient numeric IDs collided with a `kinisi.ID2`, but those five movements were clinic expenses rather than patient payments. Therefore `kinisi.ID2 -> Customers.id` is not a valid patient-link rule and no `kinisi` entries are included in this overview.

## Approval boundary

This pilot approves only presentation of the already preserved treatment-level source values. It does not approve:

- a migrated active balance;
- a payment or receipt ledger;
- invoices, VAT or cancellation interpretation;
- automatic linking of `kinisi` movements to patients;
- financial editing or production import.

Before a true migrated balance can be activated, a separate reconciliation stage must verify movement types, income versus expense semantics, patient links, reversals, receipts, duplicate payments and source totals.

## Verification

Automated tests cover:

- accepted simple legacy money formats;
- separation of completed and planned treatments;
- discrepancy calculation;
- visual separation of current Apexo and legacy DentalWin values;
- absence of editable text fields.
