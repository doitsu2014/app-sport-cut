# Bundled UI fonts

These are the product's design-system fonts, shipped offline with the macOS
client so no product code path reaches the network.

| Family | File | Weights | Source | License |
| --- | --- | --- | --- | --- |
| Archivo | `Archivo-Variable.ttf` | variable `wght` 100–900 | [Google Fonts](https://github.com/google/fonts/tree/main/ofl/archivo) | OFL-1.1 (`OFL-Archivo.txt`) |
| IBM Plex Sans | `IBMPlexSans-Variable.ttf` | variable `wght` 100–700 | [Google Fonts](https://github.com/google/fonts/tree/main/ofl/ibmplexsans) | OFL-1.1 (`OFL-IBMPlexSans.txt`) |
| IBM Plex Mono | `IBMPlexMono-Regular.ttf`, `IBMPlexMono-Medium.ttf` | 400, 500 | [Google Fonts](https://github.com/google/fonts/tree/main/ofl/ibmplexmono) | OFL-1.1 (`OFL-IBMPlexMono.txt`) |

The variable families are registered once in `pubspec.yaml`; `theme.dart` sets
the `wght` axis per text style. The license files in this folder must stay with
the binaries when the app is distributed.