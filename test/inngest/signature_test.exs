defmodule Inngest.SignatureTest do
  use ExUnit.Case, async: true

  alias Inngest.Signature

  @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"
  @hashed_signing_key "signkey-test-e4bf4a2e7f55c7eb954b6e72f8f69628fbc409fe7da6d0f6958770987dcf0e02"

  describe "hashed_signing_key/1" do
    test "should return the hash sum of the siging key" do
      assert @hashed_signing_key == Signature.hashed_signing_key(@signing_key)
    end
  end

  describe "signing_key_valid?/3" do
    @sig "t=1689920619&s=31df77f5b1b029de4bfce3a77e0517aa4ce0f5e2195a6467fc126a489ca2330b"
    @event %{
      id: "",
      name: "inngest/scheduled.timer",
      data: %{},
      user: %{},
      ts: 1_674_082_830_001,
      v: "1"
    }
    @body %{
      ctx: %{
        fn_id: "local-testing-local-cron",
        run_id: "01GQ3HTEZ01M7R8Z9PR1DMHDN1",
        step_id: "step"
      },
      event: @event,
      events: [@event],
      steps: %{},
      use_api: false
    }

    test "should return true if signature is valid" do
      assert Signature.signing_key_valid?(@sig, @signing_key, @body, ignore_ts: true)
    end

    test "should return false for expired signatures" do
      refute Signature.signing_key_valid?(@sig, @signing_key, @body)
    end

    test "should return false if signature is invalid" do
      sig = @sig <> "hello"
      refute Signature.signing_key_valid?(sig, @signing_key, @body, ignore_ts: true)
    end

    test "should return false for non binary input" do
      refute Signature.signing_key_valid?(10, @signing_key, @body)
    end
  end
end
