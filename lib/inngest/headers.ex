defmodule Inngest.Headers do
  @moduledoc """
  Header values used by the SDK
  """

  def env, do: "X-Inngest-Env"
  def forwarded_for, do: "X-Forwarded-For"
  def framework, do: "X-Inngest-Framework"
  def platform, do: "X-Inngest-Platform"
  def sdk, do: "X-Inngest-SDK"
  def signature, do: "X-Inngest-Signature"
  def server_kind, do: "X-Inngest-Server-Kind"
  def req_version, do: "X-Inngest-Req-Version"
  def server_timing, do: "Server-Timing"

  # Retries
  def no_retry, do: "X-Inngest-No-Retry"
  def retry_after, do: "Retry-After"
end
