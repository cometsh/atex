defmodule Atex.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Atex.IdentityResolver.Cache,
      Atex.OAuth.Cache
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
