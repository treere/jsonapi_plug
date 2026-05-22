defmodule JSONAPIPlug.Plug.AtomicParams do
  @moduledoc """
  Plug for parsing the JSON:API Atomic Operations document in requests

  It reads `"atomic:operations"` from the request body, deserializes the document
  into a list of `%AtomicOperation{}` structs, normalizes each operation into a params map,
  and stores the resulting list in `conn.private.jsonapi_plug.operations`.

  `conn.private.jsonapi_plug.params` remains `nil` for atomic requests.
  """

  alias JSONAPIPlug.{Document, Normalizer}
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{body_params: %Conn.Unfetched{aspect: :body_params}}, _opts) do
    raise "Body unfetched when trying to parse JSON:API Atomic Operations document"
  end

  def call(
        %Conn{body_params: body_params, private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} =
          conn,
        _opts
      ) do
    document = Document.deserialize(body_params)

    operations =
      Normalizer.denormalize(document, jsonapi_plug.resource, conn)

    Conn.put_private(conn, :jsonapi_plug, %{jsonapi_plug | operations: operations, params: nil})
  end
end
