# CHANGELOG

## v2.0.1 (2026-07-27)

  * Fix compile-time warning when Makeup is optional
  * Disable parallel compilation to avoid compiler races

## v2.0.0 (2026-06-06)

  * Use [MDExNative](https://mdex-native.hexdocs.pm/MDExNative.html) as the Markdown engine instead of the deprecated Earmark. While Markdown engines are mostly compatible, they may have subtle differences. If you were specifying custom `:earmark_options` on `use NimblePublisher`, you will need to use `:comrak_options` instead. See the documentation for more information
  * Require Elixir v1.11+

## v1.1.1 (2025-02-21)

  * Relax language detector from Markdown snippet to support languages like C++

## v1.1.0 (2023-10-23)

  * Allow custom parsing functions to return multiple entries per file
  * Allow custom HTML converter
  * Support `.livemd` in default html converter

## v1.0.0

  * First stable release