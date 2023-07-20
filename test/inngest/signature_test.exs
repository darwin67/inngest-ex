defmodule Inngest.SignatureTest do
  use ExUnit.Case, async: true

  alias Inngest.Signature

  describe "hashed_signing_key/1" do
    @signing_key "signkey-test-8ee2262a15e8d3c42d6a840db7af3de2aab08ef632b32a37a687f24b34dba3ff"
    @hashed_signing_key "signkey-test-e4bf4a2e7f55c7eb954b6e72f8f69628fbc409fe7da6d0f6958770987dcf0e02"

    test "should return the hash sum of the siging key" do
      assert @hashed_signing_key == Signature.hashed_signing_key(@signing_key)
    end
  end

  describe "signing_key_valid?/1" do
    @sig "hello"

    @tag :skip
    test "should return true if signature is valid" do
      assert Signature.signing_key_valid?(@sig)
    end

    @tag :skip
    test "should return false if signature is invalid" do
      refute Signature.signing_key_valid?(@sig)
    end

    test "should return false for non binary input" do
      refute Signature.signing_key_valid?(10)
    end
  end
end
