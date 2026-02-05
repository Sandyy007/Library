# Font Files Required

This folder should contain the following font files for proper Hindi text rendering.

## Required Fonts

### 1. Kruti Dev 010 (for legacy Hindi text)

- **File**: `kruti_dev_010.ttf`
- **Source**: Download from trusted font sources or obtain from system fonts
- **Purpose**: Renders legacy Hindi text encoded in Kruti Dev format

### 2. Noto Sans Devanagari (for Unicode Hindi)

- **Files**:
  - `NotoSansDevanagari-Regular.ttf`
  - `NotoSansDevanagari-Bold.ttf`
- **Source**: [Google Fonts](https://fonts.google.com/noto/specimen/Noto+Sans+Devanagari)
- **Purpose**: Renders modern Unicode Hindi/Devanagari text

## Installation Instructions

1. Download the font files from their respective sources
2. Place them in this `assets/fonts/` directory
3. Run `flutter pub get` to update dependencies
4. Rebuild the application

## Notes

- If Kruti Dev font is not available, the app will fall back to system fonts
- Noto Sans Devanagari is recommended for cross-platform Unicode Hindi support
- Font files are not included in the repository due to licensing considerations

## Alternative: System Fonts

If you cannot bundle the fonts, the app will automatically use these system fonts:

- **Windows**: Nirmala UI, Mangal
- **macOS/iOS**: System fonts with Devanagari support
- **Android**: Noto Sans Devanagari (usually pre-installed)
