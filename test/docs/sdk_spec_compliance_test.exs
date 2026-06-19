defmodule Inngest.Docs.SdkSpecComplianceTest do
  use ExUnit.Case, async: true

  @doc_path Path.expand("../../docs/sdk-spec-compliance.md", __DIR__)

  test "compliance checklist does not link to local plan files" do
    markdown = File.read!(@doc_path)

    refute markdown =~ ~r/\]\(plans\//
  end
end
