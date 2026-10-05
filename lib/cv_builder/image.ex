defmodule CvBuilder.Image do
  @moduledoc """
  Zet een afbeelding om naar een `data:`-uri zodat de html één zelfstandig
  bestand blijft dat je per mail kunt versturen.

  Een cv-foto heeft geen 1920 pixels nodig. Standaard wordt het plaatje daarom
  verkleind tot 480 pixels breed en omgezet naar jpeg, wat een foto van 1,5 MB
  terugbrengt naar een paar tientallen kilobytes. Lukt dat niet, dan wordt het
  originele bestand alsnog ingesloten.

  Kleinschalen gebeurt met ImageMagick (`magick`) als dat geïnstalleerd is. Is
  dat niet zo, dan wordt de foto onverkleind gebruikt.
  """

  @default_max_width 480
  @cache_dir "tmp/image_cache"

  @mimes %{
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".webp" => "image/webp",
    ".gif" => "image/gif",
    ".svg" => "image/svg+xml"
  }

  @doc """
  Geeft de inhoud van `path` terug als `data:`-uri, of `nil` als het bestand
  niet gelezen kan worden.
  """
  def data_uri(path, opts \\ []) do
    max_width = Keyword.get(opts, :max_width, @default_max_width)

    case load(path, max_width) do
      {:ok, mime, bytes} -> "data:#{mime};base64,#{Base.encode64(bytes)}"
      :error -> nil
    end
  end

  # Geeft de mime-type van de bytes terug en niet van het pad, want na het
  # verkleinen is het plaatje een jpeg geworden.
  defp load(path, max_width) when is_binary(path) do
    case File.read(path) do
      {:ok, bytes} ->
        case downscale(path, max_width) do
          {:ok, smaller} -> {:ok, "image/jpeg", smaller}
          :original -> {:ok, mime(path) || "application/octet-stream", bytes}
        end

      {:error, _} ->
        :error
    end
  end

  defp load(_path, _max_width), do: :error

  defp downscale(path, max_width) do
    if max_width > 0 and wide?(path, max_width) do
      case shrink(path, max_width) do
        {:ok, smaller} -> {:ok, smaller}
        :error -> :original
      end
    else
      :original
    end
  end

  defp shrink(path, max_width) do
    File.mkdir_p!(@cache_dir)
    target = Path.join(@cache_dir, cache_name(path, max_width))

    cond do
      File.exists?(target) -> read_file(target)
      not magick_available?() -> :error
      true -> convert(path, target, max_width)
    end
  end

  @doc """
  De mime-type die bij de extensie hoort, of `nil` als de extensie onbekend is.
  """
  def mime(path) do
    case path do
      path when is_binary(path) -> Map.get(@mimes, path |> Path.extname() |> String.downcase())
      _ -> nil
    end
  end

  @doc """
  Of `magick` beschikbaar is op dit systeem.
  """
  def magick_available?, do: System.find_executable("magick") != nil

  defp convert(path, target, max_width) do
    args = [
      path,
      "-auto-orient",
      "-resize",
      "#{max_width}x",
      "-background",
      "white",
      "-alpha",
      "remove",
      "-alpha",
      "off",
      "-strip",
      "-quality",
      "85",
      "jpg:#{target}"
    ]

    case System.cmd("magick", args, stderr_to_stdout: true) do
      {_output, 0} ->
        read_file(target)

      {output, code} ->
        warn(path, "magick gaf exitcode #{code}: #{output}")
        :error
    end
  rescue
    error -> warn(path, Exception.message(error))
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, _} -> :error
    end
  end

  defp warn(path, reason) do
    IO.warn("Kon #{path} niet verkleinen (#{reason}), origineel wordt gebruikt.")
    :error
  end

  # Bepaalt de breedte met magick. Kan die niet, dan gaan we ervan uit dat de
  # afbeelding klein genoeg is.
  defp wide?(path, max_width) do
    case System.cmd("magick", [path, "-format", "%w", "info:"], stderr_to_stdout: true) do
      {output, 0} ->
        case output |> String.trim() |> Integer.parse() do
          {width, _} -> width > max_width
          :error -> false
        end

      _ ->
        false
    end
  rescue
    _ -> false
  end

  defp cache_name(path, max_width) do
    Path.rootname(Path.basename(path)) <> "-#{max_width}.jpg"
  end
end
