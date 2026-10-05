# cv_builder

Een cv maken uit één markdown-bestand. Je schrijft `input/cv.md`, je draait één
commando, en je krijgt een nette `output/cv.html` en een A4-pdf van één pagina.

Alles draait op Elixir zonder externe packages. Er is geen build-stap, geen
node_modules en geen database. De pdf wordt gemaakt met de Chromium die toch
al op je systeem staat.

## Snel starten

Kopieer eerst de voorbeeldbestanden naar de plekken waar de tool ze zoekt:

```sh
cp input/cv.example.md input/cv.md      # jouw cv
cp config.example.json config.json      # jouw kleur, foto en contactgegevens
```

Daarna:

```sh
mix deps.get          # er zijn geen deps, maar dit is een nette controle
mix cv.build          # maakt output/cv.html
mix cv.pdf            # maakt output/cv.pdf
```

`mix cv.pdf` maakt ook de html aan, want de pdf heeft die nodig.

### Je cv blijft van jou

`input/cv.md`, `config.json`, je foto in `assets/` en alles in `output/` staan in
`.gitignore`. De `*.example`-bestanden wél in de repository, zodat je kunt zien
hoe het werkt zonder dat je persoonlijke gegevens mee naar Git gaan.

## Het cv-bestand

Alles wat in het cv staat staat in `input/cv.md`. Het bestand is opgebouwd uit
 vier soorten dingen: de header, secties, entries en badges.

````markdown
# Jouw Naam

Software Engineer in opleiding

## Profiel

Twee of drie alinea's over wat je wilt.

## Werkervaring

### Webdeveloper (stage) | Bedrijf | 2025
- Wat je deed
- Wat je deed

## Vaardigheden

### Talen
- Java
- SQL
````

Het volledige voorbeeld staat in `input/cv.example.md`.

De koppen `##` en `###` betekenen iets, niet alleen "koppen":

| Kop | Betekenis |
| --- | --- |
| `#` | je naam, staat linksboven naast de foto |
| `##` | een sectie, komt in de volgorde uit `config.json` |
| `###` onder `## Werkervaring` of `## Opleiding` | een entry |
| `###` onder een badges-sectie (zie `config.json`) | de naam van een badge-groep |

Een `###` voor een entry wordt met `|` opgesplitst:

```markdown
### Rol | Bedrijf | 2025     → rol, bedrijf en datum
### Rol | 2025                → rol en datum
### Rol                      → alleen een rol
```

De datum komt rechts uitgelijnd te staan, zoals je op een gewoon cv verwacht.

In een badges-sectie blijft alles wat geen lijstje is gewoon staan. Zo kan
`## Profiel` eerst een alinea hebben en daarna pas `### Competenties` en
`### Interesses`, zonder dat de alinea verdwijnt.

## Opmaak binnen de tekst

| Je schrijft | Je krijgt |
| --- | --- |
| `**vet**` of `__vet__` | vet |
| `*cursief*` of `_cursief_` | cursief |
| `` `C#` `` | code |
| `~~weg~~` | doorhalen |
| `[GitHub](https://github.com/jouw-handle)` | link |
| `jan@voorbeeld.nl` | mailto-link |
| `https://example.com` | klikbare link |

Alles wordt ge-escaped voordat het in de html komt, dus een `&` in je tekst
wordt netjes `&amp;` en je kunt geen html in je cv smuren.

## Configuratie

`config.json` staat naast je cv en bepaalt vooral dingen die geen tekst zijn. Het
voorbeeldbestand heet `config.example.json`.

```json
{
  "accent": "#1d4ed8",
  "photo": "assets/photo.jpg",
  "photo_focus": "center 25%",
  "max_width": 480,
  "email": "jij@voorbeeld.nl",
  "phone": "+31 6 12 34 56 78",
  "location": "Plaats, Nederland",
  "links": [{ "label": "GitHub", "url": "https://github.com/jouw-handle" }],
  "sections": ["profiel", "werkervaring", "opleiding", "vaardigheden"],
  "badges": ["vaardigheden"]
}
```

| Sleutel | Wat het doet |
| --- | --- |
| `accent` | de kleur van de accentstreep en de badges. Een `#` mag weg |
| `photo` | pad naar je foto, of laat het weg voor een cv zonder foto |
| `photo_focus` | welk deel van de foto zichtbaar blijft, zoals bij `object-position` |
| `max_width` | hoe breed de foto in pixels wordt voordat hij verkleind wordt |
| `sections` | volgorde van de `##`-secties. Niet opgegeven: de volgorde van je bestand |
| `badges` | secties die bullets als badges tonen in plaats van als lijst |

Onbekende sleutels geven een waarschuwing en worden genegeerd, dus een typefout
in `config.json` valt meteen op in plaats van stilletjes te verdwijnen.

## Over de foto

De foto in `assets/` (standaard `assets/photo.jpg` in het voorbeeld) is in de html
ingesloten als base64. Je cv is daardoor één bestand dat je kunt mailen zonder dat
er iets ontbreekt. Zie ook `assets/README.md`.

Een foto van een paar megabyte wordt eerst verkleind met ImageMagick tot de
breedte uit `max_width` en daarna pas ingesloten. Het verkleinde bestand komt in
`tmp/image_cache/` te staan, dus de tweede build is meteen klaar. Zonder
ImageMagick wordt de originele foto gebruikt, dan is je cv alleen wat groter.

De foto staat in een kader van 26 bij 34 millimeter met `object-fit: cover`. Een
liggende foto wordt dus in het midden uitgeknipt tot een smallere verticale
spleet. **Gebruik een staande foto**, anders zie je vooral een stuk van de
achtergrond.

## Tests

```sh
mix test
```

De tests draaien zonder ImageMagick of Chromium. `mix cv.pdf` is de enige
manier om het pdf-pad echt te testen, en dat doe je met de hand.

## Waarom het pdf er uitziet zoals het er uitziet

Dit cv is gemaakt om door een cv-systeem gelezen te worden, niet om gescoord
te worden op uiterlijk. Concreet:

- één kolom, semantische html, geen tabellen en geen frames
- koppen als echte `h1`, `h2` en `h3`
- de lettergrootte van sectietitels is klein genoeg dat ATS-systemen ze nog
  als kop lezen
- de datum staat in de tekst, niet in een element dat je kunt verbergen
- de pdf krijgt A4 met een vaste marge, dus hij past op één pagina

De `--no-pdf-header-footer`-vlag van Chromium zet geen automatische
datum- en paginanummers in de marge van de pdf, want dat is bijna altijd
verkeerd voor een cv.