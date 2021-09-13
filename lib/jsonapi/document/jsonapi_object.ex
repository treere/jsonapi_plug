defmodule JSONAPI.Document.JSONAPIObject do
  @moduledoc """
  JSONAPI Document JSONAPI Object
  """

  alias JSONAPI.API

  @type t :: %__MODULE__{version: API.version()}
  @enforce_keys [:version]
  defstruct version: nil
end
