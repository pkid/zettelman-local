# TODO

Based on these reference zettels:

- `/Users/yashu/Downloads/IMG_6829.HEIC`
- `/Users/yashu/Downloads/IMG_6830.HEIC`
- `/Users/yashu/Downloads/IMG_6831.HEIC`
- `/Users/yashu/Downloads/IMG_6832.HEIC`

## Observations From The Samples

- Notes can be rotated sideways in the photo.
- Two notes mix printed practice details with handwritten date/time.
- One note is fully structured and includes explicit labels like `Datum`, `Uhrzeit`, and `Bereich`.
- One note is a Physio reminder card where the header can leak into the `what` field.
- `what` is not always written explicitly.
- `where` is often the practice header plus address block, not a dedicated field.
- German weekday abbreviations matter: `Mo`, `Di`, `Mi`, `Do`, `Fr`.
- Two-digit years are common: `26` instead of `2026`.

## Requirement 2: OCR + Extraction

- [x] Add image pre-processing before OCR:
  - normalize rotation
  - improve contrast for handwriting
  - optionally crop to the zettel area

- [x] Add label-first extraction before generic heuristics:
  - prefer values next to `Datum`
  - prefer values next to `Uhrzeit`
  - prefer `Bereich` for `what`

- [x] Improve German date parsing:
  - support `14.09.26`
  - support `27.03.26`
  - support `19.3.26`
  - support weekday + date combinations like `Fr. 27.03.26`

- [x] Improve time parsing:
  - support `8:30`
  - support `08:30`
  - support `11:15`
  - support optional trailing `Uhr`

- [x] Improve location extraction:
  - capture practice name from the header
  - append address block when present
  - ignore phone/fax/website when building `where`

- [x] Improve `what` extraction with fallbacks:
  - use `Bereich` when present, for example `Labor`
  - infer from specialty when no explicit purpose is written:
    - `Zahnarztpraxis` -> `Zahnarzttermin`
    - `Frauenheilkunde` -> `Frauenarzttermin`
    - `Hausarzt und Internist` -> `Hausarzttermin`
  - fall back to `Arzttermin` if nothing better is found

- [x] Add sample-based expectations for these 4 images:
  - `IMG_6829`: `2026-09-14 08:30`, `Frauenarzttermin`, `Dr. med. Kristine Spatzier ...`
  - `IMG_6830`: `2026-03-27 08:30`, `Labor`, `Praxis Dr. med. H. Mitnacht ...`
  - `IMG_6831`: `2026-03-19 11:15`, `Zahnarzttermin`, `Zahnarztpraxis Samir Youssef ...`
  - `IMG_6832`: `2026-02-02`, `Physiotherapietermin`, `Fit & Fun physio ...`

- [x] Add parser tests for the sample layouts:
  - handwritten over printed card
  - structured table note
  - handwritten dental reminder card
  - physio reminder card with inferred `what`

## Requirement 3: Confirmation Popup

- [x] Show extracted values with confidence states:
  - high confidence
  - guessed/fallback
  - missing and needs review

- [x] Visually flag uncertain fields:
  - missing date/time
  - inferred `what`
  - long or noisy `where`

- [x] Make editing faster in the popup:
  - separate date and time controls
  - keep `what` capped to 5 words
  - support multiline `where`

- [x] Add a zoomable zettel preview in the confirmation sheet.

- [x] Highlight why a value was chosen when possible:
  - `from Bereich`
  - `from handwritten line`
  - `inferred from practice type`

- [x] Add quick actions for common corrections:
  - `Use generic Arzttermin`
  - `Clear time`
  - `Trim address`

- [x] Keep the OCR raw text collapsible, not always expanded.

## Next Steps

- [x] Turn the sample images into a local evaluation set for extraction quality.
- [x] Add a small test harness so we can compare extracted fields against expected output.
- [x] Tune the extractor against these layouts first before adding more generic heuristics.
- [x] Re-test on a real iPhone camera photo after any OCR change, not just imported gallery images.
