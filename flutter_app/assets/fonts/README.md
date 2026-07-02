# Font Files

This folder holds the fonts used for Hindi/Devanagari rendering.

## Bundled fonts (committed & declared in `pubspec.yaml`)

### Noto Sans Devanagari (Unicode Hindi)

- **Files**:
  - `NotoSansDevanagari-Regular.ttf`
  - `NotoSansDevanagari-Bold.ttf`
- **Source**: [Google Fonts](https://fonts.google.com/noto/specimen/Noto+Sans+Devanagari)
- **Purpose**: Renders modern Unicode Hindi/Devanagari text, including in
  generated PDFs (borrow slips, reports, member history).

These two files are declared under the `NotoSansDevanagari` family in
`pubspec.yaml` and are the only font files required for the app to build.

## Legacy Kruti Dev text

Legacy Hindi text stored in the **Kruti Dev** encoding is handled in code by the
[`krutidevtounicode`](https://pub.dev/packages/krutidevtounicode) package
(a dependency in `pubspec.yaml`), which converts Kruti Dev text to Unicode at
runtime. A Kruti Dev `.ttf` font is therefore **not** required or bundled.

See `lib/utils/hindi_text.dart` for the normalization/conversion helpers.

## Fallback (system) fonts

If a glyph isn't covered, the theme falls back to platform Devanagari fonts:

- **Windows**: Nirmala UI, Mangal
- **macOS/iOS**: system fonts with Devanagari support
- **Android**: Noto Sans Devanagari (usually pre-installed)

## After changing fonts

1. Place/replace the `.ttf` files in this directory.
2. Update the `fonts:` section of `pubspec.yaml` if you add a new family.
3. Run `flutter pub get`, then rebuild the app.
