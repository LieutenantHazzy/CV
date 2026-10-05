defmodule CvBuilder.RendererTest do
  use ExUnit.Case, async: true

  alias CvBuilder.{Config, Parser, Renderer}

  defp render(markdown, config \\ %Config{}) do
    markdown |> Parser.parse() |> Renderer.render(config)
  end

  describe "header" do
    test "de naam komt uit de eerste kop" do
      html = render("# Jan Jansen\n")

      assert html =~ ~s(<h1 class="cv-name">Jan Jansen</h1>)
    end

    test "een alinea onder de naam wordt de tagline" do
      html = render("# Jan\n\nSoftware Engineer in opleiding\n")

      assert html =~ ~s(<p class="cv-tagline">Software Engineer in opleiding</p>)
    end

    test "zonder tagline komt er geen lege tagline" do
      refute render("# Jan\n") =~ "cv-tagline"
    end

    test "de contactgegevens komen uit de configuratie" do
      config = %Config{email: "j@example.nl", phone: "0612345678", location: "Utrecht"}

      html = render("# Jan\n", config)

      assert html =~ ~s(<a href="mailto:j@example.nl">j@example.nl</a>)
      assert html =~ "Utrecht"
    end

    test "telefoonnummer krijgt een tel-link zonder spaties erin" do
      html = render("# Jan\n", %Config{phone: "+31 6 12 34"})

      assert html =~ ~s(<a href="tel:+3161234">+31 6 12 34</a>)
    end
  end

  describe "entries" do
    test "rol, bedrijf en datum komen uit de kop met verticale streep" do
      html = render("## Werkervaring\n\n### Webdeveloper | Acme | 2025\n")

      assert html =~ "<div class=\"entry-title\">Webdeveloper"
      assert html =~ ~s(<span class="entry-org">Acme</span>)
      assert html =~ ~s(<div class="entry-date">2025</div>)
    end

    test "twee delen is rol en datum" do
      html = render("## Werkervaring\n\n### Webdeveloper | 2025\n")

      assert html =~ "<div class=\"entry-title\">Webdeveloper</div>"
      assert html =~ ~s(<div class="entry-date">2025</div>)
      refute html =~ "entry-org"
    end

    test "een deel is alleen een rol" do
      html = render("## Werkervaring\n\n### Webdeveloper\n")

      assert html =~ ~s(<div class="entry-title">Webdeveloper</div>)
      refute html =~ "entry-date"
    end

    test "bullets onder een kop horen bij die entry" do
      markdown = """
      ## Werkervaring

      ### Eerste | 2024

      - Bullet van de eerste

      ### Tweede | 2023

      - Bullet van de tweede
      """

      html = render(markdown)
      [_header, first, second] = String.split(html, "<div class=\"entry\">")

      assert first =~ "Bullet van de eerste"
      refute first =~ "Bullet van de tweede"
      assert second =~ "Bullet van de tweede"
    end
  end

  describe "vaardigheden" do
    test "een vaardigheden-sectie toont badges met een categorie" do
      markdown = """
      ## Vaardigheden

      ### Talen

      - Java
      - SQL
      """

      html = render(markdown)

      assert html =~ ~s(<h3 class="badge-label">Talen</h3>)
      assert html =~ ~s(<ul class="badges"><li>Java</li><li>SQL</li></ul>)
      refute html =~ "bullets"
    end

    test "de badges sectie is in te stellen" do
      markdown = """
      ## Vaardigheden

      ### Talen

      - Java
      """

      html = render(markdown, %Config{badges: ["vaardigheden"]})

      assert html =~ "badges"
    end

    test "andere secties blijven gewone lijsten" do
      html = render("## Werkervaring\n\n- iets\n")

      assert html =~ ~s(<ul class="bullets">)
      refute html =~ "badges"
    end

    test "een alinea in een badges-sectie blijft staan" do
      markdown = """
      ## Profiel

      Ik heb altijd al van computers gehouden.

      ### Competenties

      - Sociaal
      - Gefocust
      """

      html = render(markdown, %Config{badges: ["profiel"]})

      assert html =~ ~s(<p class="cv-text">Ik heb altijd al van computers gehouden.</p>)
      assert html =~ ~s(<h3 class="badge-label">Competenties</h3>)
      assert html =~ ~s(<ul class="badges"><li>Sociaal</li><li>Gefocust</li></ul>)
    end

    test "een badges-sectie zonder lijst maakt geen lege groep" do
      html = render("## Profiel\n\nAlleen een alinea.\n", %Config{badges: ["profiel"]})

      assert html =~ "Alleen een alinea."
      refute html =~ "badge-group"
      refute html =~ ~s(<ul class="badges">)
    end

    test "een lijst zonder kop in een badges-sectie wordt een groep badges" do
      html = render("## Profiel\n\n- Sociaal\n- Sportief\n", %Config{badges: ["profiel"]})

      assert html =~ ~s(<div class="badge-group"><ul class="badges">)
      assert html =~ "<li>Sociaal</li>"
      refute html =~ ~s(<h3 class="badge-label">)
    end
  end

  describe "volgorde van de secties" do
    test "de configuratie bepaalt de volgorde" do
      markdown = """
      ## Vaardigheden

      - Java

      ## Profiel

      Tekst

      ## Werkervaring

      ### Rol | 2024
      """

      html = render(markdown, %Config{sections: ["werkervaring", "profiel", "vaardigheden"]})

      assert index_of(html, "Werkervaring") < index_of(html, "Profiel")
      assert index_of(html, "Profiel") < index_of(html, "Vaardigheden")
    end

    test "secties die er niet in staan komen erachter" do
      markdown = """
      ## Vaardigheden

      - Java

      ## Profiel

      Tekst
      """

      html = render(markdown, %Config{sections: ["profiel"]})

      assert index_of(html, "Profiel") < index_of(html, "Vaardigheden")
    end

    test "zonder instelling blijft de volgorde van het bestand" do
      markdown = """
      ## Vaardigheden

      - Java

      ## Werkervaring

      ### Rol | 2024
      """

      html = render(markdown)

      assert index_of(html, "Vaardigheden") < index_of(html, "Werkervaring")
    end
  end

  describe "overige blokken" do
    test "een citaat krijgt zijn eigen tag" do
      assert render("> Iets") =~ "<blockquote class=\"cv-quote\">Iets</blockquote>"
    end

    test "een horizontale lijn blijft een lijn" do
      assert render("## A\n\n---\n") =~ ~s(<hr class="cv-rule">)
    end

    test "opmaak binnen bullets blijft zichtbaar als html" do
      html = render("## Werkervaring\n\n- **Laravel** en `C#`\n")

      assert html =~ "<strong>Laravel</strong>"
      assert html =~ "<code>C#</code>"
    end
  end

  describe "titel" do
    test "komt uit de eerste kop" do
      assert "# Jan Jansen\n" |> Parser.parse() |> Renderer.title() == "Jan Jansen"
    end

    test "valt terug op CV als er geen naam staat" do
      assert "" |> Parser.parse() |> Renderer.title() == "CV"
    end
  end

  defp index_of(html, needle) do
    {position, _length} =
      case :binary.match(html, needle) do
        :nomatch -> flunk("#{inspect(needle)} komt niet voor in de html")
        match -> match
      end

    position
  end
end
