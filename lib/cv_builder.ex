defmodule CvBuilder do
  @moduledoc """
  Leest `input/cv.md` en maakt daarvan `output/cv.html` (en desgewenst
  `output/cv.pdf`).

  Vanuit een shell:

      mix cv.build
      mix cv.pdf

  Of vanuit Elixir:

      CvBuilder.build()
      CvBuilder.build(input: "input/andere.md", accent: "#0f766e")
      CvBuilder.pdf()
  """

  alias CvBuilder.{Config, Parser, Renderer, Template}

  @default_input "input/cv.md"
  @default_output "output/cv.html"
  @default_pdf "output/cv.pdf"

  @doc """
  Zet het markdown-bestand om naar html en schrijft het weg.

  Opties: `:input`, `:output`, `:config`, `:accent`. De `:config`-optie wijst
  naar het json-bestand met de instellingen, standaard `config.json`.
  """
  def build(opts \\ []) do
    input = Keyword.get(opts, :input, @default_input)
    output = Keyword.get(opts, :output, @default_output)
    config = config(opts)

    html = convert(read(input), config)

    File.mkdir_p!(Path.dirname(output))
    File.write!(output, html)

    IO.puts("cv geschreven naar #{output} (#{byte_size(html) |> div(1024)} kB)")
    output
  end

  @doc """
  Zet `markdown` om naar een volledig html-document, zonder het weg te schrijven.
  """
  def convert(markdown, config \\ %Config{}) do
    elements = Parser.parse(markdown)

    elements
    |> Renderer.render(config)
    |> Template.wrap(Renderer.title(elements), config)
  end

  @doc """
  Bouwt het cv en maakt er daarna een A4-pdf van met headless Chromium.

  Geeft `{:ok, pad}` terug als het gelukt is, anders `{:error, reden}`.
  """
  def pdf(opts \\ []) do
    output = Keyword.get(opts, :html, @default_output)
    pdf_path = Keyword.get(opts, :output, @default_pdf)

    build(Keyword.put(opts, :output, output))

    case System.find_executable("chromium") || System.find_executable("chromium-browser") do
      nil ->
        {:error, :no_chromium}

      chromium ->
        make_pdf(chromium, output, pdf_path)
    end
  end

  @doc """
  Waar het pdf terecht komt.
  """
  def pdf_path(opts \\ []), do: Keyword.get(opts, :output, @default_pdf)

  defp read(path) do
    case File.read(path) do
      {:ok, markdown} ->
        markdown

      {:error, :enoent} when path == @default_input ->
        raise """
        #{path} bestaat niet.

        Kopieer input/cv.example.md naar #{path} en vul die met je cv.
        """

      {:error, reason} ->
        raise "Kon #{path} niet lezen: #{:file.format_error(reason)}"
    end
  end

  defp config(opts) do
    config =
      case Keyword.get(opts, :config, "config.json") do
        nil -> Config.default()
        path -> Config.load(path)
      end

    case Keyword.fetch(opts, :accent) do
      {:ok, accent} -> %{config | accent: Config.valid_accent(accent)}
      :error -> config
    end
  end

  defp make_pdf(chromium, html_path, pdf_path) do
    File.mkdir_p!(Path.dirname(pdf_path))
    url = "file://" <> Path.expand(html_path)
    profile = Path.join(System.tmp_dir!(), "cv_builder_chrome")

    args = [
      "--headless",
      "--disable-gpu",
      "--no-sandbox",
      "--no-first-run",
      "--no-pdf-header-footer",
      "--user-data-dir=#{profile}",
      "--print-to-pdf=#{Path.expand(pdf_path)}",
      url
    ]

    case System.cmd(chromium, args, stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("pdf geschreven naar #{pdf_path}")
        {:ok, pdf_path}

      {output, code} ->
        {:error, "chromium gaf exitcode #{code}: #{String.trim(output)}"}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end
end
