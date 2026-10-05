defmodule CvBuilder.Renderer do
  @moduledoc """
  Zet de elementen uit `CvBuilder.Parser` om in de html van het cv.

  De renderer kijkt naar de context van een blok en niet alleen naar het blok
  zelf. Zo weet hij dat:

    * alles vóór de eerste `##` de header is: naam, foto, tagline en contact
    * een `###` onder `## Werkervaring` een *entry* is, met een datum die
      rechts uitgelijnd moet staan
    * een `## Vaardigheden` bullets als *badges* wil zien in plaats van als
      gewone lijst

  De `|` in een `###`-kop wordt daarom opgesplitst:

      ### Webdeveloper | Acme | 2025

  wordt rol, bedrijf en datum. Met twee delen wordt het rol en datum, met één
  deel alleen de rol.
  """

  alias CvBuilder.{Config, Image, Inline}

  @doc """
  Zet `elements` om in de html van het cv, zonder de html-tag eromheen.
  """
  def render(elements, config \\ Config.default())

  def render(elements, config) do
    {front, rest} = Enum.split_while(elements, &(not section?(&1)))
    {header, loose} = Enum.split_with(front, &header_block?/1)

    header = render_header(header, config)

    # Blokken die geen naam, tagline of foto zijn horen niet in de header, maar
    # moeten niet stilletjes verdwijnen.
    [header, render_blocks(loose) | render_sections(rest, config)]
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n")
  end

  @doc """
  De naam uit het cv, of "CV" als er geen `#`-kop staat.
  """
  def title(elements) do
    elements
    |> Enum.find_value("CV", fn
      {:heading, 1, text} -> Inline.render(text)
      _ -> nil
    end)
  end

  defp section?({:heading, 2, _}), do: true
  defp section?(_), do: false

  # De header bestaat uit de naam, de tagline en de foto. Alleen die drie
  # worden uit het eerste stuk markdown gehaald.
  defp header_block?({:heading, 1, _}), do: true
  defp header_block?({:paragraph, _}), do: true
  defp header_block?({:image, _, _}), do: true
  defp header_block?(_), do: false

  # ---------------------------------------------------------------- header --

  defp render_header(front, config) do
    name = front |> Enum.find_value("", &name/1)

    tagline =
      front
      |> Enum.filter(&paragraph?/1)
      |> Enum.map_join(" · ", fn {:paragraph, text} -> body(text) end)

    """
    <header class="cv-header">
      #{photo(front, name, config)}
      <div class="cv-intro">
        <h1 class="cv-name">#{name}</h1>
        #{tagline_html(tagline)}
        #{contact(config)}
      </div>
    </header>
    """
    |> String.trim()
  end

  defp tagline_html(""), do: nil
  defp tagline_html(tagline), do: ~s(<p class="cv-tagline">#{tagline}</p>)

  defp name({:heading, 1, text}), do: Inline.render(text)
  defp name(_), do: nil

  defp paragraph?({:paragraph, _}), do: true
  defp paragraph?(_), do: false

  defp photo(front, name, config) do
    path =
      Enum.find_value(front, fn
        {:image, _alt, path} -> path
        _ -> nil
      end) || config.photo

    case Image.data_uri(path, max_width: config.max_width) do
      nil ->
        nil

      uri ->
        focus = Inline.escape_attr(config.photo_focus)
        alt = Inline.escape_attr(name)
        ~s(<img class="cv-photo" src="#{uri}" alt="#{alt}" style="object-position:#{focus};">)
    end
  end

  defp contact(config) do
    items =
      config
      |> Config.contact_items()
      |> Enum.map_join(~s(<span class="cv-sep">·</span>), &contact_item/1)

    case items do
      "" -> nil
      items -> ~s(<div class="cv-contact">#{items}</div>)
    end
  end

  defp contact_item({:email, email}) do
    ~s(<a href="mailto:#{Inline.escape_attr(email)}">#{Inline.escape(email)}</a>)
  end

  defp contact_item({:phone, phone}) do
    tel = String.replace(phone, " ", "")
    ~s(<a href="tel:#{Inline.escape_attr(tel)}">#{Inline.escape(phone)}</a>)
  end

  defp contact_item({:location, location}), do: Inline.escape(location)

  defp contact_item({:link, %{label: label, url: url}}) do
    ~s(<a href="#{Inline.escape_attr(url)}" rel="noopener">#{Inline.escape(label)}</a>)
  end

  # --------------------------------------------------------------- secties --

  defp render_sections(elements, config) do
    elements
    |> build_sections()
    |> order_sections(config)
    |> Enum.map(&render_section(&1, config))
  end

  defp build_sections(elements) do
    {_leading, sections} = group(elements, &heading/2, 2)

    Enum.map(sections, fn {title, body} ->
      %{title: title, slug: Config.slug(title), body: body}
    end)
  end

  # Zet de secties in de volgorde uit de configuratie. Secties die er niet in
  # staan komen er gewoon achteraan, in de volgorde van het markdown-bestand.
  defp order_sections(sections, config) do
    case Config.section_order(config) do
      [] ->
        sections

      order ->
        {known, unknown} = Enum.split_with(sections, &(&1.slug in order))
        sorted = Enum.sort_by(known, &position(&1.slug, order))
        sorted ++ unknown
    end
  end

  defp position(slug, order), do: Enum.find_index(order, &(&1 == slug))

  defp render_section(section, config) do
    body =
      if section.slug in config.badges do
        render_badges(section.body)
      else
        render_entries(section.body)
      end

    """
    <section class="cv-section">
      <h2 class="cv-section-title">#{Inline.render(section.title)}</h2>
      #{body}
    </section>
    """
    |> String.trim()
  end

  # ---------------------------------------------------------------- entries --

  defp render_entries(body) do
    {leading, entries} = group(body, &heading/2, 3)

    join([
      render_blocks(leading),
      Enum.map_join(entries, "\n", &render_entry/1)
    ])
  end

  defp render_entry({title, blocks}) do
    {role, org, date} = split_entry(title)

    """
    <div class="entry">
      <div class="entry-head">
        <div class="entry-title">#{Inline.render(role)}#{org && org_html(org)}</div>
        #{date_html(date)}
      </div>
      #{render_blocks(blocks)}
    </div>
    """
    |> String.trim()
  end

  defp org_html(org), do: ~s( <span class="entry-org">#{Inline.render(org)}</span>)

  defp date_html(nil), do: nil
  defp date_html(date), do: ~s(<div class="entry-date">#{Inline.render(date)}</div>)

  # `### rol | bedrijf | datum`, of korter.
  defp split_entry(title) do
    case title |> String.split("|") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) do
      [] -> {"", nil, nil}
      [role] -> {role, nil, nil}
      [role, date] -> {role, nil, date}
      [role, org | rest] -> {role, org, Enum.join(rest, " | ")}
    end
  end

  # ---------------------------------------------------------------- badges --

  defp render_badges(body) do
    {leading, groups} = group(body, &heading/2, 3)

    intro =
      leading
      |> Enum.map(&leading_block/1)
      |> reject_blank()
      |> Enum.join("\n")

    labelled =
      groups
      |> Enum.map(fn {label, blocks} ->
        """
        <div class="badge-group">
          <h3 class="badge-label">#{Inline.render(label)}</h3>
          #{badges(blocks)}
        </div>
        """
        |> String.trim()
      end)
      |> Enum.join("\n")

    join([intro, labelled])
  end

  # Blokken vóór de eerste `###` horen bij de badges-sectie zelf. Een lijstje
  # wordt een groep badges, en alles wat geen lijstje is blijft gewoon een
  # alinea of citaat, zodat een profiel met een introductie niet stilletjes
  # halfwegs de alinea verliest.
  defp leading_block({:list, _ordered, _items} = list) do
    ~s(<div class="badge-group">#{badges([list])}</div>)
  end

  defp leading_block(block), do: render_block(block)

  defp badges(blocks) do
    pills =
      blocks
      |> Enum.flat_map(&items/1)
      |> Enum.map_join("", &~s(<li>#{Inline.render(&1)}</li>))

    ~s(<ul class="badges">#{pills}</ul>)
  end

  defp items({:list, _ordered, items}), do: Enum.flat_map(items, &items/1)
  defp items({:text, text}), do: [text]
  defp items(_), do: []

  # ----------------------------------------------------------------- blokken --

  defp render_blocks(blocks) do
    blocks
    |> Enum.map(&render_block/1)
    |> reject_blank()
    |> Enum.join("\n")
  end

  defp render_block({:paragraph, text}), do: ~s(<p class="cv-text">#{body(text)}</p>)

  defp render_block({:quote, text}),
    do: ~s(<blockquote class="cv-quote">#{body(text)}</blockquote>)

  defp render_block({:rule}), do: ~s(<hr class="cv-rule">)
  defp render_block({:image, alt, path}), do: render_image(alt, path)

  defp render_block({:heading, level, text}),
    do: ~s(<h#{level} class="cv-sub">#{body(text)}</h#{level}>)

  defp render_block({:list, ordered, items}) do
    tag = if ordered, do: "ol", else: "ul"
    ~s(<#{tag} class="bullets">#{Enum.map_join(items, "", &render_item/1)}</#{tag}>)
  end

  defp render_block(_), do: nil

  defp render_item({:text, text}), do: ~s(<li>#{body(text)}</li>)

  defp render_item({:list, _ordered, items}),
    do: ~s(<li>#{Enum.map_join(items, "", &render_item/1)}</li>)

  defp render_image(alt, path) do
    case Image.data_uri(path) do
      nil ->
        ~s(<span class="missing">[afbeelding: #{Inline.escape(alt)} ontbreekt]</span>)

      uri ->
        ~s(<img class="cv-inline-photo" src="#{uri}" alt="#{Inline.escape_attr(alt)}">)
    end
  end

  defp body(text), do: Inline.render(text)

  # ------------------------------------------------------------- hulpmiddelen --

  # Geeft `{kop, blokken}`-paren terug, waarbij blokken vóór de eerste kop in
  # een aparte lijst belanden.
  defp group(elements, classify, level) do
    {leading, sections} =
      Enum.reduce(elements, {[], []}, fn element, {leading, sections} ->
        case classify.(element, level) do
          {:heading, title} ->
            {leading, [{title, []} | sections]}

          :block ->
            case sections do
              [{current, blocks} | rest] -> {leading, [{current, [element | blocks]} | rest]}
              [] -> {leading ++ [element], sections}
            end
        end
      end)

    reversed =
      Enum.map(sections, fn {title, blocks} -> {title, Enum.reverse(blocks)} end)

    {leading, Enum.reverse(reversed)}
  end

  defp heading({:heading, level, text}, wanted) when level == wanted, do: {:heading, text}
  defp heading(_element, _wanted), do: :block

  defp join(parts), do: parts |> reject_blank() |> Enum.join("\n")

  defp reject_blank(parts), do: Enum.reject(parts, &blank?/1)

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false
end
