defmodule Mix.Tasks.Cv.Build do
  use Mix.Task

  @shortdoc "Bouwt het cv vanuit input/cv.md naar output/cv.html"

  @moduledoc """
  Bouwt het cv.

      mix cv.build
      mix cv.build --input input/andere.md
      mix cv.build --output output/betere-versie.html
      mix cv.build --accent "#0f766e"
      mix cv.build --config config.json

  Zonder `--config` wordt `config.json` gebruikt als dat bestand bestaat.
  """

  @switches [input: :string, output: :string, config: :string, accent: :string]

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: @switches)

    CvBuilder.build(Enum.reject(opts, fn {_key, value} -> is_nil(value) end))
  end
end
