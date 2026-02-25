# Yomipv

Yomipv is a script that combines Yomitan with MPV to create Anki cards from Japanese media without leaving the player.
There's no need to alt-tab between MPV and Yomitan while mining or doing word lookups.
It was designed to be used with [Senren Note Type](https://github.com/BrenoAqua/Senren), but it should work with any note type.

https://github.com/user-attachments/assets/8ff6f71a-c961-4da1-bf9f-b1b2c00143f8

## Requirements

- **[MPV](https://mpv.io/)** (0.33.0 or higher)
- **[FFmpeg](https://ffmpeg.org/)** (Required for media extraction, falls back to MPV's internal encoder if not found)
- **[Anki](https://apps.ankiweb.net/)** with **[AnkiConnect](https://ankiweb.net/shared/info/2055492159)**
- **[Yomitan](https://yomitan.wiki/)** and **[Yomitan Api](https://github.com/yomidevs/yomitan-api)**
- **[Node.js](https://nodejs.org/)** (Required for the lookup app)
- **curl** (Usually pre-installed on Windows, used for API requests)

## Installation

1. **Clone the repository** to your MPV directory and install dependencies **(make sure you have Node.js installed)**:
   - Windows: `%APPDATA%/mpv/`
     ```
     git clone https://github.com/BrenoAqua/Yomipv && xcopy /e /i /y Yomipv . && rd /s /q Yomipv && cd scripts\yomipv\lookup-app && npm install
     ```
   
   - Linux: `~/.config/mpv/`
     ```
     git clone https://github.com/BrenoAqua/Yomipv && cp -rn Yomipv/* . && rm -rf Yomipv && cd scripts/yomipv/lookup-app && npm install
     ```
3. **Configure Settings**:
   - Open `script-opts/yomipv.conf` and update your Anki deck/note type names and field mappings.

4. **External Services**:
   - Ensure Anki is running with AnkiConnect enabled.
   - Ensure Yomitan Api is running and the browser where the Yomitan extension is installed is open, and you have dictionaries installed.

## Usage

### Basic Workflow

1. Open a video with Japanese subtitles in MPV
2. Press **`c`** to activate the word selector
3. Navigate with **mouse hover** or **arrow keys** to select a word
4. Press **`Enter`**, **`c`**, or **left-click** to create an Anki card

### Advanced Features

- **Append Mode (`Shift+C`)**: Select multiple subtitle lines before exporting
  - Press `Shift+C` to enter append mode, `c` to start the word selector, or `Shift+C` again to cancel

- **Selection Expansion**:
  - **`Ctrl+Left`** / **`Ctrl+Right`**: Expand selection to adjacent words
  - **`Shift+Left`** / **`Shift+Right`**: Expand to previous/next subtitle line

- **Mora-level Navigation**:
  - When `selector_mora_hover` is enabled, hovering over a word narrows the lookup to start from mora under your cursor instead of the full word
  - **`s`**: Toggle mora-level keyboard navigation (left/right moves by mora instead of word)

- **Lookup App (`Ctrl+c`)**: Opens a popup window powered by your Yomitan dictionaries, showing definitions, pitch accents, and frequencies
  - **Right-click** on the word in the selector to lock the lookup. It stays locked on the current word to avoid triggering another lookup when you move the cursor over other words
  - **Click any mora** in the header to narrow the lookup to a sub-word
  - **Right-click the header** in the lookup to go back to the previous word
  - See [docs/lookup-app.md](docs/lookup-app.md) for full details

- **Manual Timing**:
  - **`q`** / **`w`**: Set a custom start/end time for audio and picture extraction
  - Unset start or end times default to the subtitle boundaries when opening the selector
  - **`e`**: Clear manual timings

- **History Panel (`a`)**: Toggle subtitle history panel
  - Click on previous/next lines to select them to expand the subtitle lines (when selector is open) or seek to that timestamp (when selector is closed)

There are demos for some features [here](https://github.com/BrenoAqua/Yomipv/tree/main/features)

## Troubleshooting

### Windows
- Ensure PowerShell execution policy allows scripts
- Check that curl is available at `C:\Windows\System32\curl.exe`

> [!WARNING]
> **Linux Support Not Tested**
> This script has primarily been developed and tested on Windows. While cross-platform support is intended, Linux users may encounter issues. Please report any bugs or compatibility problems.
