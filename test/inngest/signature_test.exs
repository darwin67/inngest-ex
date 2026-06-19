defmodule Inngest.SignatureTest do
  use ExUnit.Case, async: true

  alias Inngest.Signature

  @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"
  @fallback_signing_key "signkey-fallback-746573742d66616c6c6261636b2d7369676e696e672d6b657921"
  @hashed_signing_key "signkey-test-e4bf4a2e7f55c7eb954b6e72f8f69628fbc409fe7da6d0f6958770987dcf0e02"

  describe "hashed_signing_key/1" do
    test "should return the hash sum of the siging key" do
      assert @hashed_signing_key == Signature.hashed_signing_key(@signing_key)
    end
  end

  describe "signing_key_valid?/4" do
    @sig "t=1689920619&s=db3352ded9110df7c6961e1c223e6691dbdb1115ac7ef94ee7bba217fac93d04"
    @body ~s({"events":[{"data":{},"id":"","name":"inngest/scheduled.timer","user":{},"v":"1","ts":1674082830001}],"event":{"data":{},"id":"","name":"inngest/scheduled.timer","user":{},"v":"1","ts":1674082830001},"ctx":{"fn_id":"local-testing-local-cron","run_id":"01GQ3HTEZ01M7R8Z9PR1DMHDN1","step_id":"step"},"steps":{},"use_api":false})

    setup do
      %{body: @body}
    end

    test "should return true if signature is valid", %{body: body} do
      assert Signature.signing_key_valid?(@sig, @signing_key, body, ignore_ts: true)
    end

    test "should return true for a signature created with a fallback key", %{body: body} do
      sig = Signature.sign("1689920619", @fallback_signing_key, body)

      assert Signature.signing_key_valid?(sig, @fallback_signing_key, body, ignore_ts: true)
    end

    test "should return true when any configured signing key matches", %{body: body} do
      sig = Signature.sign("1689920619", @fallback_signing_key, body)

      assert Signature.signing_key_valid?(
               sig,
               [@signing_key, @fallback_signing_key],
               body,
               ignore_ts: true
             )
    end

    test "should return false for expired signatures", %{body: body} do
      refute Signature.signing_key_valid?(@sig, @signing_key, body)
    end

    test "should return false if signature is invalid", %{body: body} do
      sig = @sig <> "hello"
      refute Signature.signing_key_valid?(sig, @signing_key, body, ignore_ts: true)
    end

    test "should return false if signing key is missing", %{body: body} do
      refute Signature.signing_key_valid?(@sig, "", body, ignore_ts: true)
    end

    test "should return false if signature is missing", %{body: body} do
      refute Signature.signing_key_valid?(nil, @signing_key, body, ignore_ts: true)
    end

    test "should return false for non binary input", %{body: body} do
      refute Signature.signing_key_valid?(10, @signing_key, body)
    end
  end
end
