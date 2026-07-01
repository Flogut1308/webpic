# Auftrag an Claude Code — WebPic (native macOS-App)

> **So nutzt du das:** Teile dieses Projekt via *Share* mit Claude Code (der Link enthält
> `WebPic.dc.html` als Design-Referenz). Füge dann den folgenden Prompt als ersten
> Auftrag ein. Der Prompt ist bewusst ausführlich — Claude Code soll die HTML-Referenz
> **nativ nachbauen**, nicht das HTML ausliefern.

---

## PROMPT (ab hier kopieren)

Du baust **WebPic**, eine **native macOS-App** zur Optimierung von Bildern fürs Web.

Im geteilten Projekt liegt `WebPic.dc.html` — ein **interaktiver Design-Prototyp in HTML**.
Er definiert Look, Flow, Zustände und Copy verbindlich, ist aber **keine Produktions-Codebasis
zum Kopieren**. Deine Aufgabe: die Screens und Interaktionen aus dieser Referenz **nativ in
macOS nachbauen**. Öffne die Datei und arbeite dich durch alle Screens/Zustände (Toolbar-Tabs,
Sidebar, Sheets, Segmented Controls, Slider, Toggles), bevor du beginnst.

### Tech-Stack (Vorschlag — bestätige oder schlage begründet Alternativen vor)
- **SwiftUI** (macOS 14+), AppKit-Interop wo nötig. `NavigationSplitView` für Sidebar+Detail,
  `.toolbar` für die Titelleiste, `Picker(.segmented)`, `Slider`, `Toggle`, `.sheet`,
  **SF Symbols** für alle Icons, `.tint(.blue)` als Akzent, `.regularMaterial` für die
  Frosted-Glass-Flächen (Sidebar/Toolbar).
- Kein Web-Wrapper (Electron/Tauri) außer der Nutzer wünscht es ausdrücklich — die App soll
  sich systemnativ anfühlen (das ist die Kern-Anforderung des Designs).
- Paketierung als `.app`, Distribution als notarisiertes DMG/ZIP.

### Fidelity
**High-fidelity.** Farben, Abstände, Radien und Interaktionen aus dem Prototyp möglichst genau
übernehmen — aber mit **nativen Systemkontrollen** statt Custom-UI. Wo eine native Komponente
minimal anders aussieht als das HTML (z. B. Standard-`Slider` vs. Custom-Knob), hat die native
Variante Vorrang.

### Screens & Flow (aus der Referenz)
1. **Import / Leerzustand** — große Drop-Zone + „Bilder auswählen …" / „Aus Fotos importieren".
   Drag & Drop aus Finder/Fotos, Mehrfachauswahl. Nach Import: Auswahl des ersten Bildes,
   Wechsel in die Einstellungen.
2. **Sidebar** — App-Titel + Version, „Bilder hinzufügen", Eintrag „Alle Bilder" (Batch) mit
   Count, Liste der importierten Bilder mit Thumbnail, Auflösung, Dateigröße und **Status-Punkt**;
   pro Zeile ein **Entfernen (×)**. Unten: Update-Hinweis-Pill + Hell/Dunkel-Umschalter.
3. **Einstellungen (Hauptscreen)** — Segmented „Einstellungen | Vergleich"; Ausgabe-Modus
   (Einzelbild / Responsive Set / Nur Konvertierung); Preset-Cards (Hero 1920w, Content 1200w,
   Thumbnail 400w, Icon/Avatar 256w, Custom); Format-Toggles (WebP, AVIF, JPEG-Fallback, PNG,
   mehrfach); Komprimierung mit Umschalter **Qualität ↔ Zieldateigröße** (Qualitäts-Slider mit
   Live-Dateigröße; Zielgröße-Feld KB/MB mit **Fehlerzustand** bei unrealistischem Wert +
   Hinweis auf automatisch angepasste Qualität); bei Responsive Set: Breakpoint-Checkboxen
   (400/800/1200/1920 + Custom); ausklappbar **Erweitert** (Metadaten behalten, Farbraum
   sRGB/Display P3, Dateinamen-Schema `{name}-{w}.{format}`). Rechts eine Live-Vorschau mit
   Original → Optimiert, Ersparnis in % und KB/MB, neuer Auflösung.
4. **Vorher/Nachher-Vergleich** — ziehbarer Slider über Original/Optimiert, prominente
   Kennzahlen (Ersparnis %, gespart, neue Auflösung).
5. **Export/Review** — erreichbar über den Toolbar-Button „Exportieren"; transparente
   Zusammenfassung aller Settings, Hinweis bei Zieldateigröße welche Parameter automatisch
   angepasst wurden; Aktionen **In Fotos speichern · Teilen · Code-Snippet**.
6. **Code-Snippet-Sheet** — Auswahl HTML `<picture>` / React / Next.js `<Image>` / Vue,
   syntax-highlighted Code, Copy-Button (mit Feedback), Toggle `loading="lazy"`.
7. **Batch** — Grid aller Bilder mit **Status pro Bild** (Wartend / Verarbeitet + Progress /
   Fertig / Fehler), Toggle „Alle gleich behandeln" ↔ individuell, „Alle entfernen".
8. **App-Update** — dezenter Sidebar-Banner + Modal mit Versionsnummer, Kurz-Changelog,
   Install-Button (Loading-Zustand).

### Komponenten-Zustände (bitte alle umsetzen)
- **Buttons** (Primär/Sekundär/Text): Default, Pressed, Disabled, **Loading** (während
  Verarbeitung/Speichern), **Success** (kurz nach Export).
- **Inputs** (Zielgröße): Default, Focused, Filled, **Error**, Disabled.
- **Toggle/Switch**: On/Off/Disabled. **Slider**: Default/Dragging.
- **Chips/Presets**: Default/Selected/Disabled.
- **Bild-Cards**: Default, Selected, **Verarbeitung (Progress)**, Fertig, Fehler.

### Design-Tokens (aus dem Prototyp)
- **Akzent (System Blue):** `#0A84FF` (Hover `#2A94FF`, Pressed `#0069D0`, Tint hell `#E8F1FE`).
  Nativ: `.tint(.blue)` / `Color.accentColor`.
- **Hell:** Fenster `#FFFFFF`, gruppierter Hintergrund `#F1F1F4`, Card `#FFFFFF`,
  Text `#1D1D1F` / `#605F65` / `#8E8E93`, Trennlinien `rgba(0,0,0,0.09)`.
- **Dunkel:** Fenster `#1E1E1F`, Hintergrund `#161617`, Card `#2A2A2C`,
  Text `#F5F5F7` / `#A6A6AC` / `#6E6E73`. Beide Modi über System-Appearance + manuellen Umschalter.
- **Status:** Fertig `#30D158`/`#1E9E5A`, Verarbeitung `#0A84FF`, Wartend `#8E8E93`,
  Fehler `#FF453A`/`#E5484D`.
- **Typografie:** System-Font (SF Pro) für UI; **Zahlen tabellarisch monospaced** (SF Mono /
  `.monospacedDigit()`) für Größen/Auflösungen/%. UI-Basis ~13–14 pt.
- **Radien:** Buttons 6–8, Cards 12–14, Fenster/Sheets 12–16. **Sidebar** ~250 pt,
  **Toolbar** ~46 pt. Frosted Glass für Sidebar/Toolbar (`.regularMaterial`).
- Icons ausschließlich **SF Symbols** (z. B. `photo`, `square.grid.2x2`, `chevron.left.right`,
  `arrow.up.doc`, `slider.horizontal.3`, `xmark`, `checkmark`, `arrow.down.circle`).

### Engineering hinter der UI
- **Bild-Pipeline:** Dekodieren/Skalieren via `CGImage`/ImageIO bzw. `vImage`.
  JPEG/PNG/HEIC über `CGImageDestination`. **WebP** und **AVIF** haben keinen nativen Encoder —
  nutze `libwebp`/`libavif` (SPM) oder shelle robust zu `cwebp`/`avifenc`; alternativ
  `SDWebImage`-Coder. Kläre die Encoder-Wahl mit mir, bevor du dich festlegst.
- **Zieldateigröße:** iterative Qualitätssuche (Binärsuche über Quality), bis das Ergebnis das
  Ziel möglichst knapp unterschreitet; im Review transparent machen, welche Qualität gewählt wurde.
- **Responsive Set:** pro gewähltem Breakpoint eine Variante rendern; Dateinamen-Schema anwenden.
- **Metadaten/Farbraum:** EXIF/ICC über ImageIO-Properties erhalten oder strippen; sRGB vs. P3.
- **Code-Snippet-Generator:** aus den aktiven Formaten/Breakpoints/`loading` die vier Varianten
  (HTML `<picture>`, React, Next.js `<Image>`, Vue) erzeugen; korrekte `type`-Attribute und
  `srcset`/`sizes` bei Responsive Set.
- **Verarbeitung nebenläufig** (async/`TaskGroup`), UI bleibt responsiv; echte Progress-Werte
  in den Bild-Cards.
- **Speichern/Teilen:** `NSSavePanel` bzw. Ziel-Ordner, „In Fotos" über Photos-Framework,
  `NSSharingServicePicker` für Teilen.
- **Auto-Update via GitHub Releases:** bevorzugt **Sparkle 2** (SPM) mit einem auf GitHub
  Releases gehosteten Appcast (signierte EdDSA-Updates); alternativ ein leichter Checker gegen
  die GitHub-Releases-API mit DMG/ZIP-Download. Der Update-Banner/-Dialog aus dem Design ist der
  Aufhänger dafür.

### Architektur & Vorgehen
- Sauberes SwiftUI-Projekt: Feature-Ordner (Import, Settings, Compare, Export, Batch, Update),
  ein `AppState`/Store (Observable), Services für `ImageProcessor`, `SnippetGenerator`,
  `Updater`. Value-Types für Settings/Presets.
- **Meilensteine:** (1) App-Shell + Sidebar + Theme, (2) Import + Bildmodell, (3) Settings-UI
  komplett mit Live-Schätzung (Mock-Encoder ok), (4) echte Encoder-Pipeline + Zielgröße,
  (5) Vergleich + Export/Speichern, (6) Code-Snippets, (7) Batch + nebenläufige Verarbeitung,
  (8) Sparkle-Update. Nach jedem Meilenstein baubar + kurz zeigen.
- **Akzeptanz:** Screens/Flows entsprechen der Referenz; alle o. g. Komponenten-Zustände
  vorhanden; Hell/Dunkel korrekt; echte Optimierung erzeugt kleinere Dateien; Zielgröße wird
  getroffen; Snippets sind copy-paste-korrekt; Update-Flow funktioniert.

**Bevor du Encoder-Abhängigkeiten, Signierung/Notarisierung oder das Update-Hosting festlegst,
stell mir kurz die offenen Fragen.** Beginne mit Meilenstein 1 und einem knappen Umsetzungsplan.
