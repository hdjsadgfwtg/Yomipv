## Lookup App

The Lookup App is an interactive overlay that displays dictionary definitions, pitch accents, and frequencies for words you select in MPV directly, All data is taken from your installed dictionaries in Yomitan.

## How it Works

The lookup window appears when you search for a word. Depending on your configuration, this can happen manually or automatically.

- **Manual Lookup**: Press `Ctrl+c` (default) while hovering over a word in the selector.
- **Automatic Lookup**: Can be enabled in your settings (`selector_lookup_on_hover` or `selector_lookup_on_navigation`).

The window stays on top of MPV.

### Navigating Multiple Results
If a word has multiple entries, you will see a counter (like `1 / 3`) at the top.
- Click the Left/Right buttons of the lookup window to cycle through different entries.

### Sub-word Lookups
You can perform a new search directly from the lookup window's header.
- **Click any character** in the word at the top to start a new lookup from that position.

### Navigation History
- **Right-click the header** to go back to the previous word you were looking at.

## Working with Definitions

### Selecting Text
- Just like in Yomitan’s popup, you can select any text inside definitions to populate your Selection Text field in Anki when `popup-selection-text` is being used.

### Choosing a Specific Dictionary
- **Click the Dictionary Title** to select that specific dictionary to populate the Definition field in Anki if `selected-dict` is being used.
- When you select a dictionary, `popup-selection-text` is ignored, and you can select text from the definition to be highlighted.

## Frequencies
- By default the lookup app will show the frequencies of the word you are looking up.
- You can disable this by setting `lookup_show_frequencies=no` in your `yomipv.conf` file.

## Ptich Accents
- By default, the Lookup App shows the pitch accents (if available) of the word you are looking up and also colors the word according to its pitch accent.
- TODO: Add option to disable this.