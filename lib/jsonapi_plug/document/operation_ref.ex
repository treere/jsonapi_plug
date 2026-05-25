defmodule JSONAPIPlug.Document.OperationRef do
  @moduledoc """
  JSON:API Atomic Operations Extension — Operation Ref Object

  Represents the `ref` member of an operation object, used to target a specific
  resource or relationship.

  https://jsonapi.org/ext/atomic/
  """

  alias JSONAPIPlug.{Document, Exceptions.InvalidDocument}

  @type t :: %__MODULE__{
          id: Document.ResourceObject.id() | nil,
          lid: Document.ResourceObject.id() | nil,
          relationship: String.t() | nil,
          type: Document.ResourceObject.type()
        }

  defstruct id: nil, lid: nil, relationship: nil, type: nil

  @doc "Deserializes a raw map into an %OperationRef{} struct"
  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(%{"type" => type} = data)
      when is_binary(type) and byte_size(type) > 0 do
    id = deserialize_id(data)
    lid = deserialize_lid(data)

    if is_nil(id) and is_nil(lid) do
      raise InvalidDocument,
        message: "Operation 'ref' must contain either 'id' or 'lid'",
        reference: "https://jsonapi.org/ext/atomic/"
    end

    %__MODULE__{
      type: type,
      id: id,
      lid: lid,
      relationship: deserialize_relationship(data)
    }
  end

  def deserialize(_data) do
    raise InvalidDocument,
      message: "Operation 'ref' must contain a non-empty string 'type' member",
      reference: "https://jsonapi.org/ext/atomic/"
  end

  defp deserialize_id(%{"id" => id}) when is_binary(id) and byte_size(id) > 0, do: id
  defp deserialize_id(_data), do: nil

  defp deserialize_lid(%{"lid" => lid}) when is_binary(lid) and byte_size(lid) > 0, do: lid
  defp deserialize_lid(_data), do: nil

  defp deserialize_relationship(%{"relationship" => rel})
       when is_binary(rel) and byte_size(rel) > 0,
       do: rel

  defp deserialize_relationship(_data), do: nil
end
