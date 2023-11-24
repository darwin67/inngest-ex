defmodule Inngest.Headers do
  @moduledoc """
  Header values used by the SDK
  """

  def env, do: "x-inngest-env"
  # def framework, do: "x-inngest-framework"
  # def platform, do: "x-inngest-platform"
  def sdk_version, do: "x-inngest-sdk"
  def signature, do: "x-inngest-signature"
  def server_kind, do: "x-inngest-server-kind"
  # def server_timing, do: "server-timing"

  # retries
  def no_retry, do: "x-inngest-no-retry"
  def retry_after, do: "retry-after"
end
