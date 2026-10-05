defmodule CvBuilder.Template do
  @moduledoc """
  Vouwt de gegenereerde html in een volledige pagina met styling.

  De stylesheet bestaat uit twee delen: hoe het cv er op scherm uitziet (een
  witte pagina op een grijze achtergrond) en hoe het er uitziet op papier.

  Het papieren deel is het belangrijkste voor een cv, want dat is wat je
  verstuurt. Daar staan de `A4`-pagina, de marges, en vooral de regels dat een
  header of een ervaring nooit over een paginagrens heen wordt gebroken.

  De accentkleur komt uit de configuratie en staat één keer als `--accent`
  gedefinieerd; de rest van de kleuren wordt daarvan afgeleid met `color-mix`.
  """

  alias CvBuilder.Config
  alias CvBuilder.Inline

  @doc """
  Zet `body_html` in een volledige html-document.
  """
  def wrap(body_html, title \\ "CV", config \\ Config.default()) do
    """
    <!DOCTYPE html>
    <html lang="#{Inline.escape_attr(config.lang)}">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <meta name="generator" content="cv_builder">
      <title>#{title}</title>
      <style>
        #{css(config.accent)}
      </style>
    </head>
    <body>
      <main class="page">
        #{body_html}
      </main>
    </body>
    </html>
    """
    |> String.trim()
  end

  defp css(accent) do
    """
    *, *::before, *::after { box-sizing: border-box; }

    html {
      --accent: #{accent};
      --accent-10: color-mix(in srgb, var(--accent) 10%, #ffffff);
      --accent-30: color-mix(in srgb, var(--accent) 30%, #ffffff);
      --ink: #17191c;
      --muted: #5a6270;
      --hairline: #dcdfe5;
      /* anders verdwijnen de kleuren bij het opslaan als pdf */
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }

    body {
      margin: 0;
      color: var(--ink);
      font-family: "Inter", "Segoe UI", system-ui, -apple-system, "Helvetica Neue", Arial, sans-serif;
      font-size: 10pt;
      line-height: 1.45;
      -webkit-font-smoothing: antialiased;
    }

    a { color: var(--accent); }

    /* ---------------------------------------------------------- op scherm */

    @media screen {
      body { background: #eceef1; padding: 28px 12px; }
      .page {
        max-width: 190mm;
        margin: 0 auto;
        padding: 16mm 15mm;
        background: #ffffff;
        box-shadow: 0 1px 3px rgba(16, 24, 40, .10), 0 10px 28px rgba(16, 24, 40, .08);
      }
      .cv-contact a:hover { color: var(--accent); }
    }

    /* ------------------------------------------------------------- header */

    .cv-header {
      display: flex;
      align-items: flex-start;
      gap: 7mm;
    }

    .cv-photo {
      flex: 0 0 auto;
      width: 26mm;
      height: 34mm;
      object-fit: cover;
      border-radius: 1.5mm;
      background: var(--accent-10);
    }

    .cv-intro { min-width: 0; padding-top: 1mm; }

    .cv-name {
      margin: 0;
      font-size: 21pt;
      line-height: 1.15;
      font-weight: 700;
      letter-spacing: -0.015em;
    }

    .cv-tagline { margin: 1.4mm 0 0; color: var(--muted); }

    .cv-contact { margin-top: 3mm; color: var(--muted); font-size: 8.5pt; line-height: 1.75; }
    .cv-contact a { color: var(--muted); text-decoration: none; }
    .cv-sep { padding: 0 2mm; color: var(--accent-30); }

    /* ------------------------------------------------------------ secties */

    .cv-section { margin-top: 6.5mm; }

    .cv-section-title {
      margin: 0 0 2.8mm;
      padding-bottom: 1.4mm;
      border-bottom: 0.6pt solid var(--accent-30);
      color: var(--accent);
      font-size: 8.5pt;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .cv-sub { margin: 3mm 0 1mm; font-size: 10pt; }

    /* ------------------------------------------------------------ entries */

    .entry { margin-bottom: 4.2mm; }
    .entry:last-child { margin-bottom: 0; }

    .entry-head {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 6mm;
    }

    .entry-title { min-width: 0; font-weight: 600; }
    .entry-org { color: var(--muted); font-weight: 400; }
    .entry-org::before { content: "·"; margin: 0 1.4mm; color: var(--accent-30); }

    .entry-date {
      flex: 0 0 auto;
      color: var(--accent);
      font-size: 9pt;
      font-weight: 600;
      white-space: nowrap;
      font-variant-numeric: tabular-nums;
    }

    /* -------------------------------------------------------------- lijsten */

    .bullets { margin: 1.4mm 0 0; padding-left: 4.6mm; }
    .bullets li { margin: 0 0 0.7mm; padding-left: 0.5mm; }
    .bullets li::marker { color: var(--accent); font-size: .9em; }
    .bullets .bullets { margin: 0.7mm 0 0.3mm; }

    .cv-text { margin: 0 0 2mm; }
    .cv-quote {
      margin: 2mm 0;
      padding-left: 3mm;
      border-left: 1.2pt solid var(--accent-30);
      color: var(--muted);
    }
    .cv-rule { margin: 4mm 0; border: 0; border-top: 0.6pt solid var(--hairline); }

    code {
      background: var(--accent-10);
      border-radius: .5mm;
      padding: 0 .3em;
      font-family: "JetBrains Mono", "SF Mono", Menlo, Consolas, monospace;
      font-size: .92em;
    }

    /* ------------------------------------------------------------- badges */

    .badge-group { margin-bottom: 3.2mm; }
    .badge-group:last-child { margin-bottom: 0; }

    .badge-label { margin: 0 0 1.4mm; color: var(--muted); font-size: 8.5pt; font-weight: 600; }

    .badges {
      display: flex;
      flex-wrap: wrap;
      gap: 1.4mm;
      margin: 0;
      padding: 0;
      list-style: none;
    }

    .badges li {
      padding: 0.5mm 2mm;
      border: 0.4pt solid var(--accent-30);
      border-radius: 1.2mm;
      background: var(--accent-10);
      color: var(--accent);
      font-size: 8.5pt;
      font-weight: 500;
    }

    .cv-inline-photo, .inline-photo {
      max-height: 6mm;
      vertical-align: middle;
      border-radius: 0.8mm;
    }

    .missing { color: var(--muted); font-style: italic; }

    /* --------------------------------------------------------- op papier */

    @page { size: A4; margin: 13mm 14mm; }

    @media print {
      html, body { background: #ffffff; }
      body { font-size: 9.6pt; }
      .page { max-width: none; margin: 0; padding: 0; box-shadow: none; }
      a { text-decoration: none; }

      /* niets mag over een paginagrens heen worden gebroken */
      .cv-header, .entry, .badge-group, .cv-section-title {
        break-inside: avoid;
        page-break-inside: avoid;
      }
      .cv-section { break-inside: auto; }
    }
    """
  end
end
