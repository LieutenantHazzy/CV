defmodule Mix.Tasks.Cv.Pdf do
  use Mix.Task

  @shortdoc "Bouwt het cv en maakt er een A4-pdf van"

  @moduledoc """
  Bouwt eerst het cv (`output/cv.html`) en zet dat daarna om naar een pdf met
  headless Chromium.

      mix cv.pdf
      mix cv.pdf --output output/mijn-cv.pdf

  De pdf maakt gebruik van de printstylesheet in `CvBuilder.Template`, dus het
  resultaat is een A4-pagina zonder de schermopmaak eromheen.

  Chromium moet geïnstalleerd zijn. Ontbreekt het, dan staat er een foutmelding
  en kun je als alternatief `output/cv.html` in de browser openen en daar
  `Ctrl+P` doen.
  """

  @switches [input: :string, html: :string, output: :string, config: :string, accent: :string]

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: @switches)
    opts = Enum.reject(opts, fn {_key, value} -> is_nil(value) end)

    case CvBuilder.pdf(opts) do
      {:ok, path} ->
        Mix.shell().info("Klaar: #{path}")

      {:error, :no_chromium} ->
        Mix.raise("""
        Chromium is niet gevonden.

        Installeer chromium, of open output/cv.html in je browser en print die
        met Ctrl+P (kies A4 en zet "kophoofden en voetteksten" uit).
        """)

      {:error, reason} ->
        Mix.raise("Kon geen pdf maken: #{reason}")
    end
  end
end
