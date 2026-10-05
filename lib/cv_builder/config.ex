defmodule CvBuilder.Config do
  @moduledoc """
  Leest `config.json` en levert de instellingen die de renderer nodig heeft.

  Alles is optioneel: zonder `config.json` werkt de builder gewoon met de
  standaardwaarden. Zo hoeft er alleen een `.json`-bestand aangemaakt te
  worden voor wie de kleur of de contactgegevens wil aanpassen, zonder ook maar
  één regel Elixir.

  De inhoud van je cv zelf blijft in `input/cv.md` staan, zodat je cv op één
  plek blijft.

      {
        "accent": "#1d4ed8",
        "photo": "assets/photo.jpg",
        "email": "jij@voorbeeld.nl",
        "phone": "+31 6 12 34 56 78",
        "location": "Plaats",
        "links": [{ "label": "GitHub", "url": "https://github.com/jouw-handle" }]
      }
  """

  defstruct accent: "#1d4ed8",
            lang: "nl",
            photo: nil,
            photo_focus: "center 25%",
            max_width: 480,
            email: nil,
            phone: nil,
            location: nil,
            links: [],
            sections: [],
            badges: ["vaardigheden", "vaardigheden en kennis", "skills", "kennis"]

  @default_path "config.json"

  @doc """
  Standaardconfiguratie, zonder bestand.
  """
  def default, do: %__MODULE__{}

  @doc """
  Laadt de configuratie uit `path`. Geeft de standaardwaarden terug als het
  bestand er niet is.
  """
  def load(path \\ @default_path) do
    case File.read(path) do
      {:ok, contents} -> from_json(contents, path)
      {:error, :enoent} -> default()
      {:error, reason} -> raise "Kon #{path} niet lezen: #{:file.format_error(reason)}"
    end
  end

  @doc """
  Zet de standaardconfiguratie om vanuit een map met string-keys.

  Met `warn: false` worden onbekende sleutels stil genegeerd, wat handig is in
  tests.
  """
  def from_map(map, opts \\ []) when is_map(map) do
    if Keyword.get(opts, :warn, true), do: warn_about_unknown_keys(map)

    default()
    |> struct(atomize(map))
    |> normalize(opts)
  end

  # In json zijn de sleutels strings, maar de velden van de struct zijn atoms.
  # Zonder deze stap zou `struct/2` alles stilzwijgend negeren.
  defp atomize(map) do
    known = Map.new(Map.to_list(default()), fn {key, _} -> {Atom.to_string(key), key} end)

    for {key, value} <- map,
        field = Map.get(known, to_string(key)),
        not is_nil(field),
        into: %{},
        do: {field, value}
  end

  defp warn_about_unknown_keys(map) do
    known = Map.keys(default()) |> Enum.map(&Atom.to_string/1)

    for key <- Enum.map(Map.keys(map), &to_string/1),
        key not in known,
        do: IO.warn("Onbekende instelling in config: #{inspect(key)}, die wordt genegeerd.")
  end

  defp from_json(contents, path) do
    case JSON.decode(contents) do
      {:ok, map} when is_map(map) ->
        from_map(map)

      {:ok, other} ->
        raise "#{path} moet een json-object zijn, kreeg #{inspect(other)}"

      {:error, reason} ->
        raise "#{path} bevat geen geldige json: #{describe(reason)}"
    end
  end

  # JSON.decode geeft een reden terug die niet altijd een exception is.
  defp describe({:invalid_byte, position, byte}) do
    "ongeldig teken #{inspect(<<byte>>)} op positie #{position}"
  end

  defp describe({position, reason}) when is_integer(position) do
    "fout op positie #{position}: #{describe(reason)}"
  end

  defp describe(reason) when is_exception(reason), do: Exception.message(reason)
  defp describe(reason), do: inspect(reason)

  defp normalize(config, opts) do
    %{
      config
      | accent: valid_accent(config.accent, opts),
        links: links(config.links),
        max_width: max_width(config.max_width)
    }
  end

  @doc """
  Controleert een kleur en geeft de standaardkleur terug als de kleur ongeldig is.

  Een `#` mag ontbreken, dus `1d4ed8` en `#1d4ed8` zijn allebei goed.
  """
  def valid_accent(value), do: valid_accent(value, warn: true)

  defp valid_accent(value, opts)

  defp valid_accent("#" <> _ = value, opts) do
    if Regex.match?(~r/\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/, value) do
      value
    else
      warn(opts, "Ongeldige kleur #{inspect(value)}, val terug op de standaardkleur.")
      default().accent
    end
  end

  defp valid_accent(value, opts) when is_binary(value), do: valid_accent("#" <> value, opts)
  defp valid_accent(_value, _opts), do: default().accent

  defp warn(opts, message) do
    if Keyword.get(opts, :warn, true), do: IO.warn(message)
    :ok
  end

  defp max_width(value) when is_integer(value) and value >= 0, do: value

  defp max_width(value) when is_binary(value) do
    case value |> String.trim() |> Integer.parse() do
      {int, _} when int >= 0 -> int
      _ -> default().max_width
    end
  end

  defp max_width(_), do: default().max_width

  defp links(value) when is_list(value) do
    value
    |> Enum.map(&link/1)
    |> Enum.reject(&is_nil/1)
  end

  defp links(_), do: []

  defp link(%{"url" => url} = map) when is_binary(url) do
    %{label: Map.get(map, "label") || url, url: url}
  end

  defp link(_), do: nil

  @doc """
  De contactgegevens als lijstjes `{soort, tekst}`.
  """
  def contact_items(config) do
    [
      {:email, config.email},
      {:phone, config.phone},
      {:location, config.location}
    ]
    |> Enum.reject(fn {_kind, value} -> blank?(value) end)
    |> Enum.concat(Enum.map(config.links, &{:link, &1}))
  end

  @doc """
  De volgorde waarin de secties moeten verschijnen. Leeg betekent: gewoon de
  volgorde uit het markdown-bestand.
  """
  def section_order(%{sections: []}), do: []
  def section_order(%{sections: list}) when is_list(list), do: Enum.map(list, &slug/1)

  @doc """
  Maakt er een vergelijkbare slug van, zodat `## Vaardigheden` in de
  configuratie als `vaardigheden` te schrijven is.
  """
  def slug(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp blank?(nil), do: true
  defp blank?(value), do: String.trim(to_string(value)) == ""
end
