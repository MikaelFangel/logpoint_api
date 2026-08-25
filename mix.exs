defmodule Guardsix.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/MikaelFangel/guardsix"

  def project do
    [
      app: :guardsix,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.7.2"},
      {:jason, "~> 1.4"},
      {:joken, "~> 2.6"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.2", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    A stateless Elixir wrapper for the Guardsix SIEM API.
    Covers searching, incidents, alert rules, user-defined lists, and repos
    with builder patterns for rules and notifications.
    """
  end

  defp package do
    [
      name: "guardsix",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://hexdocs.pm/guardsix"
      },
      maintainers: ["Mikael Fangel"],
      files: ~w(lib mix.exs README.md LICENSE CONTRIBUTING.md usage-rules.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CONTRIBUTING.md",
        "LICENSE",
        "guides/howtos/polling-search-results.md"
      ],
      groups_for_extras: [
        "How-To": ~r/guides\/howtos\/.*/
      ],
      groups_for_modules: [
        Errors: [
          Guardsix.Error,
          Guardsix.Error.API,
          Guardsix.Error.Auth,
          Guardsix.Error.Timeout,
          Guardsix.Error.Transport,
          Guardsix.Error.Validation
        ]
      ]
    ]
  end
end
