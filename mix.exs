defmodule CvBuilder.MixProject do
  use Mix.Project

  def project do
    [
      app: :cv_builder,
      version: "1.0.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_options: [warnings_as_errors: false],
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    []
  end
end
