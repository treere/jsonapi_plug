defmodule JSONAPIPlug.Document.AtomicOperation do
  @moduledoc """
  JSON:API Atomic Operations Extension — Operation Object

  Represents a single operation within an `atomic:operations` request document.

  https://jsonapi.org/ext/atomic/
  """

  alias JSONAPIPlug.{
    Document,
    Document.OperationRef,
    Document.ResourceObject,
    Exceptions.InvalidDocument
  }

  @valid_ops ~w(add update remove)

  @type op :: String.t()

  @type t :: %__MODULE__{
          data: ResourceObject.t() | nil,
          href: String.t() | nil,
          meta: Document.meta() | nil,
          op: op(),
          ref: OperationRef.t() | nil
        }

  defstruct data: nil, href: nil, meta: nil, op: nil, ref: nil

  @doc "Deserializes a raw map into an %AtomicOperation{} struct"
  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(%{"op" => op} = data) when op in @valid_ops do
    validate_ref_href_mutual_exclusion(data)

    %__MODULE__{
      op: op,
      ref: deserialize_ref(data),
      href: deserialize_href(data),
      data: deserialize_data(data),
      meta: deserialize_meta(data)
    }
  end

  def deserialize(%{"op" => op}) do
    raise InvalidDocument,
      message: "Operation 'op' must be one of 'add', 'update', or 'remove', got '#{op}'",
      reference: "https://jsonapi.org/ext/atomic/"
  end

  def deserialize(_data) do
    raise InvalidDocument,
      message: "Operation object must contain an 'op' member",
      reference: "https://jsonapi.org/ext/atomic/"
  end

  defp validate_ref_href_mutual_exclusion(%{"ref" => _, "href" => _}) do
    raise InvalidDocument,
      message: "Operation object MUST NOT contain both 'ref' and 'href'",
      reference: "https://jsonapi.org/ext/atomic/"
  end

  defp validate_ref_href_mutual_exclusion(_data), do: :ok

  defp deserialize_ref(%{"ref" => ref}) when is_map(ref), do: OperationRef.deserialize(ref)
  defp deserialize_ref(_data), do: nil

  defp deserialize_href(%{"href" => href}) when is_binary(href) and byte_size(href) > 0, do: href
  defp deserialize_href(_data), do: nil

  defp deserialize_data(%{"data" => data}) when is_map(data), do: ResourceObject.deserialize(data)
  defp deserialize_data(_data), do: nil

  defp deserialize_meta(%{"meta" => meta}) when is_map(meta), do: meta
  defp deserialize_meta(_data), do: nil
end
