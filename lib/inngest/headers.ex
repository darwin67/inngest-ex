defmodule Inngest.Headers do
  @moduledoc false

  def env, do: "x-inngest-env"
  def sdk_version, do: "x-inngest-sdk"
  def req_version, do: "x-inngest-req-version"
  def signature, do: "x-inngest-signature"
  def server_kind, do: "x-inngest-server-kind"

  # retries
  def no_retry, do: "x-inngest-no-retry"
  def retry_after, do: "retry-after"
end
