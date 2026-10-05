defmodule CvBuilder.Inline do
  @moduledoc """
  Verwerkt markdown die binnen een blok staat: `**vet**`, `*cursief*`,
  `` `code` ``, `~~doorhalen~~` en `[tekst](url)`.

  Daarnaast worden kale e-mailadressen en urls automatisch klikbaar gemaakt,
  wat handig is voor een cv.

  De volgorde is belangrijk: eerst wordt de tekst ge-escaped en daarna pas
  wordt de markdown omgezet. De karakters die markdown gebruikt (`*`, `_`, `~`,
  `` ` ``, `[`, `]`) worden door het escapen niet geraakt, dus deze volgorde
  werkt en zorgt er tegelijk voor dat een `<` in je cv geen html-tag wordt.

  Elke construct heeft een eigen regex met precies één vorm, en de inhoud wordt
  uit de match gehaald door de delimiters eraf te snijden. Zo hoeft de
  implementatie niet te gokken hoe een regexp-engine met genummerde groepen
  omgaat.
  """

  @doc """
  Zet de markdown binnen `text` om naar html, inclusief het escapen.

      iex> CvBuilder.Inline.render("**stage** bij *Acme*")
      "<strong>stage</strong> bij <em>Acme</em>"
  """
  def render(text), do: text |> escape() |> markup()

  @doc """
  Escapet de html-speciale karakters in `text`.
  """
  def escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  @doc """
  Escapet `text` voor gebruik binnen een html-attribuut.
  """
  def escape_attr(text), do: escape(text)

  # Alle vormen staan in één regex, zodat één doorloop genoeg is. Met losse
  # regexen per vorm zou een url die al in een `href` staat er nog eens door
  # heen kunnen.
  #
  # De volgorde van de alternatieven telt: `**` moet voor `*` komen, anders wordt
  # een vette eerste alinea als eerste geïtaliseerd gezien.
  #
  # Bij `_` kijken we extra naar wat er ervoor staat, zodat `snake_case_var`
  # geen italics wordt.
  @inline ~r/
    `[^`]+`
    | !\[[^\]]*\]\([^)\s]+\)
    | \[[^\]]*\]\([^)\s]+\)
    | \*\*.+?\*\*
    | __.+?__
    | ~~.+?~~
    | \*.+?\*
    | (?<![A-Za-z0-9])_[^_\n]+_(?![A-Za-z0-9])
    | (?<![\w.+-])[\w.+-]+@[\w-]+(?:\.[\w-]+)*\.[A-Za-z]{2,}
    | https?:\/\/[^\s<>"']+
  /x

  @doc """
  Zet alleen de markdown om, zonder te escapen. Voor tekst die al veilig is.
  """
  def markup(text) do
    Regex.replace(@inline, text, &replace/1) |> IO.iodata_to_binary()
  end

  # De vorm van de match bepaalt wat ermee gebeurt; de inhoud halen we er door
  # de delimiters af te snijden.
  defp replace(whole) do
    cond do
      String.starts_with?(whole, "`") ->
        "<code>#{trim(whole, 1)}</code>"

      String.starts_with?(whole, "![") ->
        render_image(whole)

      String.starts_with?(whole, "[") ->
        render_link(whole)

      String.starts_with?(whole, "**") or String.starts_with?(whole, "__") ->
        wrap(whole, 2, "strong")

      String.starts_with?(whole, "~~") ->
        wrap(whole, 2, "del")

      String.starts_with?(whole, "*") or String.starts_with?(whole, "_") ->
        wrap(whole, 1, "em")

      String.starts_with?(whole, "http") ->
        render_url(whole)

      true ->
        ~s(<a href="mailto:#{whole}">#{whole}</a>)
    end
  end

  # `**tekst**` -> <strong>tekst</strong>
  defp wrap(whole, width, tag) do
    "<#{tag}>#{trim(whole, width)}</#{tag}>"
  end

  defp trim(whole, width) do
    binary_part(whole, width, byte_size(whole) - 2 * width)
  end

  # `[tekst](url)` -> de tekst staat tussen `[` en `](`, de url erachter.
  defp render_link(whole) do
    {text, url} = split_link(whole, 1)
    ~s(<a href="#{href(url)}">#{text}</a>)
  end

  defp render_image(whole) do
    {alt, src} = split_link(whole, 2)
    alt = escape_attr(alt)

    case CvBuilder.Image.data_uri(src) do
      nil -> ~s(<span class="missing">[afbeelding: #{alt}]</span>)
      uri -> ~s(<img class="inline-photo" src="#{uri}" alt="#{alt}">)
    end
  end

  defp split_link(whole, open) do
    case :binary.match(whole, "](") do
      {at, 2} ->
        text = binary_part(whole, open, at - open)
        url = binary_part(whole, at + 2, byte_size(whole) - at - 3)
        {text, url}

      :nomatch ->
        {"", ""}
    end
  end

  # Een url die met een punt of komma eindigt hoort die tekens niet bij de
  # link te staan, dus die halen we er weer af.
  defp render_url(whole) do
    case Regex.run(~r/\A(.*?)([.,;:!?]+)\z/, whole, capture: :all_but_first) do
      [link, tail] -> ~s(<a href="#{href(link)}" rel="noopener">#{link}</a>#{tail})
      _ -> ~s(<a href="#{href(whole)}" rel="noopener">#{whole}</a>)
    end
  end

  # Beschermt tegen `javascript:`-urls en zet de rest goed in een attribuut.
  defp href(url) do
    trimmed = String.trim(url)

    if String.downcase(trimmed) =~ ~r{\A(?:javascript|data|vbscript):} do
      "#"
    else
      escape_attr(trimmed)
    end
  end

  @doc """
  Maakt van losse tekst een klikbaar e-mailadres of url.

      iex> CvBuilder.Inline.autolink("mail me op jan@voorbeeld.nl")
      ~s(mail me op <a href="mailto:jan@voorbeeld.nl">jan@voorbeeld.nl</a>)
  """
  def autolink(text), do: markup(text)
end
