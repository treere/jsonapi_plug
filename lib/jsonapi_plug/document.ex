defmodule JSONAPIPlug.Document do
  @moduledoc """
  JSON:API Document

  This module defines the structure of a `JSON:API` document and functions that handle
  serialization and deserialization. This also handles validation of `JSON:API` documents.

  https://jsonapi.org/format/#document-structure
  """

  alias JSONAPIPlug.{
    Document.AtomicOperation,
    Document.ErrorObject,
    Document.JSONAPIObject,
    Document.LinkObject,
    Document.ResourceObject,
    Exceptions.InvalidDocument,
    Resource
  }

  @type value :: String.t() | integer() | float() | [value()] | %{String.t() => value()} | nil

  @type payload :: %{String.t() => value()}

  @typedoc """
  JSON:API Primary Data

  https://jsonapi.org/format/#document-top-level
  """
  @type data :: ResourceObject.t() | [ResourceObject.t()]

  @typedoc """
  JSON:API Errors

  https://jsonapi.org/format/#errors
  """
  @type errors :: [ErrorObject.t()]

  @typedoc """
  JSON:API Included Resources

  https://jsonapi.org/format/#document-compound-documents
  """
  @type included :: [ResourceObject.t()]

  @typedoc """
  JSON:API Object

  https://jsonapi.org/format/#document-jsonapi-object
  """
  @type jsonapi :: JSONAPIObject.t()

  @typedoc """
  JSON:API Meta Information

  https://jsonapi.org/format/#document-meta
  """
  @type meta :: payload()

  @typedoc """
  JSON:API Links

  https://jsonapi.org/format/#document-links
  """
  @type links :: %{atom() => LinkObject.t()}

  @typedoc """
  JSON:API Atomic Operations

  https://jsonapi.org/ext/atomic/
  """
  @type operations :: [AtomicOperation.t()]

  @typedoc """
  JSON:API Atomic Results

  https://jsonapi.org/ext/atomic/
  """
  @type results :: [%{optional(:data) => ResourceObject.t() | nil, optional(:meta) => meta()}]

  @typedoc """
  JSON:API Document

  https://jsonapi.org/format/#document-structure
  """
  @type t :: %__MODULE__{
          data: Resource.t() | [Resource.t()] | nil,
          errors: errors() | nil,
          included: included() | nil,
          jsonapi: jsonapi() | nil,
          links: links() | nil,
          meta: meta() | nil,
          operations: operations() | nil,
          results: results() | nil
        }
  defstruct [:data, :errors, :included, :jsonapi, :links, :meta, :operations, :results]

  @doc """
  Deserialize JSON:API Document

  Takes a map representing a JSON:API Document as input, validates it
  and parses it into a `t:t/0` struct.
  """
  @spec deserialize(payload()) :: t() | no_return()
  def deserialize(%{"atomic:operations" => _, "data" => _}) do
    raise InvalidDocument,
      message: "Document cannot contain both 'atomic:operations' and 'data' members",
      reference: "https://jsonapi.org/ext/atomic/"
  end

  def deserialize(%{"atomic:operations" => _, "errors" => _}) do
    raise InvalidDocument,
      message: "Document cannot contain both 'atomic:operations' and 'errors' members",
      reference: "https://jsonapi.org/ext/atomic/"
  end

  def deserialize(%{"atomic:operations" => operations} = data) do
    %__MODULE__{
      jsonapi: deserialize_jsonapi(data),
      links: deserialize_links(data),
      meta: deserialize_meta(data),
      operations: deserialize_operations(operations)
    }
  end

  def deserialize(data) do
    %__MODULE__{
      data: deserialize_data(data),
      errors: deserialize_errors(data),
      included: deserialize_included(data),
      jsonapi: deserialize_jsonapi(data),
      links: deserialize_links(data),
      meta: deserialize_meta(data)
    }
  end

  defp deserialize_operations([]) do
    raise InvalidDocument,
      message: "'atomic:operations' array must not be empty",
      reference: "https://jsonapi.org/ext/atomic/"
  end

  defp deserialize_operations(operations) when is_list(operations),
    do: Enum.map(operations, &AtomicOperation.deserialize/1)

  defp deserialize_operations(_operations) do
    raise InvalidDocument,
      message: "'atomic:operations' must be an array",
      reference: "https://jsonapi.org/ext/atomic/"
  end

  defp deserialize_data(%{"data" => _data, "errors" => _errors}) do
    raise InvalidDocument,
      message: "Document cannot contain both 'data' and 'errors' members",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp deserialize_data(%{"data" => resources}) when is_list(resources),
    do: Enum.map(resources, &ResourceObject.deserialize/1)

  defp deserialize_data(%{"data" => resource_object}) when is_map(resource_object),
    do: ResourceObject.deserialize(resource_object)

  defp deserialize_data(_data), do: nil

  defp deserialize_errors(%{"errors" => errors}) when is_list(errors),
    do: Enum.map(errors, &ErrorObject.deserialize/1)

  defp deserialize_errors(_data), do: nil

  defp deserialize_included(%{"data" => _data, "included" => included})
       when is_list(included) do
    Enum.map(included, &ResourceObject.deserialize/1)
  end

  defp deserialize_included(%{"included" => included})
       when is_list(included) do
    raise InvalidDocument,
      message: "Document 'included' cannot be present if 'data' isn't also present",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp deserialize_included(%{"included" => included})
       when not is_nil(included) do
    raise InvalidDocument,
      message: "Document 'included' must be a list",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp deserialize_included(_data), do: nil

  defp deserialize_jsonapi(%{"jsonapi" => jsonapi}) when is_map(jsonapi),
    do: JSONAPIObject.deserialize(jsonapi)

  defp deserialize_jsonapi(_data), do: nil

  defp deserialize_links(%{"links" => links}) when is_map(links) do
    Map.new(links, fn {name, link} -> {name, LinkObject.deserialize(link)} end)
  end

  defp deserialize_links(_data), do: nil

  defp deserialize_meta(%{"meta" => meta}) when is_map(meta),
    do: Map.reject(meta, fn {key, _value} -> String.starts_with?(key, "@") end)

  defp deserialize_meta(%{"meta" => meta}) when not is_nil(meta) do
    raise InvalidDocument,
      message: "Document 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-meta"
  end

  defp deserialize_meta(_data), do: nil

  @doc """
  Serialize a Document struct representing a JSON:API Document

  Takes a `t:t/0` struct representing a JSON:API Document as input, validates
  it and returns the struct if valid.
  """
  @spec serialize(t()) :: t() | no_return()
  def serialize(%__MODULE__{results: results} = document) when not is_nil(results) do
    %{document | results: serialize_results(results)}
  end

  def serialize(%__MODULE__{} = document) do
    %{
      document
      | data: serialize_data(document.data),
        included: serialize_included(document.included),
        meta: serialize_meta(document.meta),
        errors: serialize_errors(document.errors)
    }
    |> validate_document()
  end

  defp serialize_data(%ResourceObject{} = resource),
    do: ResourceObject.serialize(resource)

  defp serialize_data(resources) when is_list(resources),
    do: Enum.map(resources, &ResourceObject.serialize/1)

  defp serialize_data(nil), do: nil

  defp serialize_results(results) when is_list(results),
    do: Enum.map(results, &serialize_result/1)

  defp serialize_result(%{data: %ResourceObject{} = resource_object} = result) do
    %{result | data: ResourceObject.serialize(resource_object)}
  end

  defp serialize_result(result), do: result

  defp serialize_errors(errors)
       when not is_nil(errors) and not is_list(errors) do
    raise InvalidDocument,
      message: "Document 'errors' must be a list",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp serialize_errors(errors) when is_list(errors),
    do: Enum.map(errors, &ErrorObject.serialize/1)

  defp serialize_errors(errors), do: errors

  defp serialize_included(included)
       when not is_nil(included) and not is_list(included) do
    raise InvalidDocument,
      message: "Document 'included' must be a list resource objects",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp serialize_included(included) when is_list(included),
    do: Enum.map(included, &ResourceObject.serialize/1)

  defp serialize_included(nil), do: nil

  defp serialize_meta(meta) when not is_nil(meta) and not is_map(meta) do
    raise InvalidDocument,
      message: "Document 'meta' must be a map",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp serialize_meta(meta), do: meta

  defp validate_document(%__MODULE__{data: data, errors: errors})
       when not is_nil(data) and not is_nil(errors) do
    raise InvalidDocument,
      message: "Document cannot contain both 'data' and 'errors' members",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp validate_document(document), do: document
end

defimpl Jason.Encoder,
  for: [
    JSONAPIPlug.Document.ErrorObject,
    JSONAPIPlug.Document.JSONAPIObject,
    JSONAPIPlug.Document.LinkObject,
    JSONAPIPlug.Document.RelationshipObject,
    JSONAPIPlug.Document.ResourceIdentifierObject,
    JSONAPIPlug.Document.ResourceObject
  ] do
  def encode(document, options) do
    document
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn
      {_key, nil}, data -> data
      {_key, %{} = map}, data when map_size(map) == 0 -> data
      {key, value}, data -> Map.put(data, key, value)
    end)
    |> Jason.Encode.map(options)
  end
end

defimpl Jason.Encoder, for: JSONAPIPlug.Document do
  def encode(%JSONAPIPlug.Document{results: results} = document, options)
      when not is_nil(results) do
    # atomic:results response document — emit "atomic:results" with string key
    document
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn
      {:results, results}, data when not is_nil(results) ->
        Map.put(data, "atomic:results", results)

      {:data, _}, data ->
        data

      {:included, _}, data ->
        data

      {:operations, _}, data ->
        data

      {:errors, _}, data ->
        data

      {_key, nil}, data ->
        data

      {_key, %{} = map}, data when map_size(map) == 0 ->
        data

      {key, value}, data ->
        Map.put(data, key, value)
    end)
    |> Jason.Encode.map(options)
  end

  def encode(document, options) do
    document
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn
      {:operations, _}, data -> data
      {:results, _}, data -> data
      {_key, nil}, data -> data
      {_key, %{} = map}, data when map_size(map) == 0 -> data
      {key, value}, data -> Map.put(data, key, value)
    end)
    |> Jason.Encode.map(options)
  end
end
