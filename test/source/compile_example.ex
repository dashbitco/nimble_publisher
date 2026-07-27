defmodule CompileExample do
  use NimblePublisher,
    build: Builder,
    from: "test/fixtures/**/*.md",
    as: :examples

  def examples, do: @examples
end
