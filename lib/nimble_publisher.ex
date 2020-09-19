defmodule NimblePublisher do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      {from, paths} = NimblePublisher.__extract__(__MODULE__, opts)

      for path <- paths do
        @external_resource Path.relative_to_cwd(path)
      end

      def __mix_recompile__? do
        unquote(from) |> Path.wildcard() |> Enum.sort() |> :erlang.md5() !=
          unquote(:erlang.md5(paths))
      end

      # TODO: Remove me once we require Elixir v1.11+.
      def __phoenix_recompile__?, do: __mix_recompile__?()
    end
  end

  @doc false
  def __extract__(module, opts) do
    builder = Keyword.fetch!(opts, :build)
    from = Keyword.fetch!(opts, :from)
    as = Keyword.fetch!(opts, :as)
    highlighters = Keyword.get(opts, :highlighters, [])
    earmark_opts = Keyword.get(opts, :earmark_options, %Earmark.Options{})

    for highlighter <- highlighters do
      Application.ensure_all_started(highlighter)
    end

    paths = from |> Path.wildcard() |> Enum.sort()

    entries =
      for path <- paths do
        {attrs, body} = parse_contents!(path, File.read!(path))

        body =
          body
          |> Earmark.as_html!(earmark_opts)
          |> highlight(attrs)

        builder.build(path, attrs, body)
      end

    Module.put_attribute(module, as, entries)
    {from, paths}
  end

  defp parse_contents!(path, contents) do
    case parse_contents(path, contents) do
      {:ok, attrs, body} ->
        {attrs, body}

      {:error, message} ->
        raise """
        #{message}

        Each entry must have a map with attributes, followed by --- and a body. For example:

            %{
              title: "Hello World"
            }
            ---
            Hello world!

        """
    end
  end

  defp parse_contents(path, contents) do
    case :binary.split(contents, ["\n---\n", "\r\n---\r\n"]) do
      [_] ->
        {:error, "could not find separator --- in #{inspect(path)}"}

      [code, body] ->
        case Code.eval_string(code, []) do
          {%{} = attrs, _} ->
            {:ok, attrs, body}

          {other, _} ->
            {:error,
             "expected attributes for #{inspect(path)} to return a map, got: #{inspect(other)}"}
        end
    end
  end

  # calls Highlighter.highlight/1 only when needed
  defp highlight(html, %{syntax: "highlight"}) do
    NimblePublisher.Highlighter.highlight(html)
  end

  defp highlight(html, _), do: html
end
