defmodule Atex.HTTP.Response do
  @moduledoc """
  A generic response struct to be returned by an `Atex.HTTP.Adapter`.
  """

  use TypedStruct

  typedstruct enforce: true do
    field :status, integer()
    field :body, any()
    field :__raw__, any()
  end
end
