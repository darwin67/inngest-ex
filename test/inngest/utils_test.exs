defmodule Inngest.UtilsTest do
  use ExUnit.Case, async: true

  alias Inngest.Utils

  describe "keys_to_atoms/1" do
    @expected %{
      hello: "world",
      yo: %{
        lo: true
      }
    }

    @str_keys %{
      "hello" => "world",
      "yo" => %{
        "lo" => true
      }
    }

    test "convert all string keys to atom" do
      assert @expected = Utils.keys_to_atoms(@str_keys)
    end

    @mixed_keys %{
      "hello" => "world",
      yo: %{
        "lo" => true
      }
    }

    test "convert all mixed keys to atom" do
      assert @expected = Utils.keys_to_atoms(@mixed_keys)
    end
  end
end
