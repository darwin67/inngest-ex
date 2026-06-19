defmodule Inngest.Docs.SdkSpecComplianceTest do
  use ExUnit.Case, async: true

  @doc_path Path.expand("../../docs/sdk-spec-compliance.md", __DIR__)

  test "local plan links resolve from the compliance checklist" do
    doc_dir = Path.dirname(@doc_path)
    markdown = File.read!(@doc_path)

    links =
      ~r/\[[^\]]+\]\((?!https?:\/\/)([^)#]+)(?:#[^)]+)?\)/
      |> Regex.scan(markdown, capture: :all_but_first)
      |> List.flatten()

    assert links != []

    missing_links =
      Enum.reject(links, fn link ->
        doc_dir
        |> Path.join(link)
        |> Path.expand()
        |> File.exists?()
      end)

    assert missing_links == []
  end
end
