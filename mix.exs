defmodule NimblePublisher.MixProject do
  use Mix.Project

  @version "2.0.1"
  @url "https://github.com/dashbitco/nimble_publisher"

  def project do
    [
      app: :nimble_publisher,
      version: @version,
      elixir: "~> 1.11",
      name: "NimblePublisher",
      description:
        "A minimal filesystem-based publishing engine with Markdown support and syntax highlighting",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mdex_native, "~> 0.1"},
      {:makeup, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.21", only: :docs},
      {:makeup_elixir, ">= 0.0.0", only: [:test, :docs]}
    ]
  end

  defp docs do
    [
      main: "NimblePublisher",
      source_ref: "v#{@version}",
      source_url: @url
    ]
  end

  defp package do
    %{
      licenses: ["Apache-2.0"],
      maintainers: ["José Valim"],
      links: %{"GitHub" => @url}
    }
  end
end
