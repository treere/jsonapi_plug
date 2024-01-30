defmodule JSONAPIPlug.Plug do
  @moduledoc """
  Implements validation and parsing of `JSON:API` requests

  This plug handles the specification defined `JSON:API` request body and query parameters
  (`fields`, `filter`, `include`, `page` and `sort`).

  ## Usage

  Add this plug to your plug pipeline/controller like this:

  ```
  plug JSONAPIPlug.Plug, api: MyApp.API, resource: MyApp.MyResource
  ```

  If your connection receives a valid `JSON:API` request this plug will parse it into a
  `JSONAPIPlug` struct that will be stored in the `Plug.Conn` private assign `:jsonapi_plug`.
  The final `Plug.Conn` struct will look similar to the following:

  ```
  %Plug.Conn{
    ...
    body_params: %{...},
    params: %{"data" => ...},
    private: %{
      ...
      jsonapi_plug: %JSONAPIPlug{
        api: MyApp.API,
        fields: ..., # Defaults to a map of field names by type.
        filter: ..., # Defaults to the query parameter value.
        include: ..., # Defaults to Ecto preload format.
        page: ..., # Defaults to the query parameter value.
        params: ..., # Defaults to Ecto normalized data.
        sort: ..., # Defaults to Ecto order_by format.
        resource: MyApp.MyResource
      }
      ...
    }
    ...
  }
  ```

  You can then use the contents of the struct to load data and call `JSONAPIPlug.Resource.render/5`
  or the render function generated by `use JSONAPIPlug.Resource` to generate responses and render
  them.

  ## Customizing default behaviour

  ### Body parameters

  By default, body parameters are transformed into a format that is compatible with attrs for
  `Ecto.Changeset` to perform inserts/updates of `Ecto.Schema` modules. However, you can transform
  the `JSON:API` document in any format you want by writing your own module adopting the
  `JSONAPIPlug.Normalizer` behaviour and configuring it through `JSONAPIPlug.API` configuration.

  ### Query parameters

  The `JSON:API` `fields` and `include` query parameters format is defined by the specification.
  The default implementation accepts the specification format and converts it to data usable as
  `select` and `preload` options to `Ecto.Repo` functions.

  The `JSON:API` `sort` query parameter format is not defined, however the specification suggests
  to use a format for encoding sorting by attribute names with an optional `-` prefix to invert
  ordering direction. The default implementation accepts the suggested format and converts it to
  usable as `order_by` option to `Ecto.Repo` functions.

  The `JSON:API` `filter` and `page` query parameters format is not defined by the JSON:API specification,
  therefore the default implementation just copies the value of the query parameters in `JSONAPIPlug`.

  You can transform data in any format you want for any of these parameters by implementing a module
  adopting the `JSONAPIPlug.QueryParser` behaviour and configuring it through `JSONAPIPlug.API` configuration.
  """

  @options_schema NimbleOptions.new!(
                    api: [
                      doc: "A module use-ing `JSONAPIPlug.API` to provide configuration",
                      type: :atom,
                      required: true
                    ],
                    includes: [
                      doc: "A nested keyword list of allowed includes for this endpoint",
                      type: :keyword_list,
                      keys: [*: [type: :keyword_list]]
                    ],
                    resource: [
                      doc: "The `JSONAPIPlug.Resource` used to parse the request.",
                      type: :atom,
                      required: true
                    ]
                  )

  @typedoc """
  Options:
  #{NimbleOptions.docs(@options_schema)}
  """
  @type options :: keyword()

  use Plug.Builder, copy_opts_to_assign: :jsonapi_plug
  use Plug.ErrorHandler

  require Logger

  alias JSONAPIPlug.{Document, Exceptions}

  alias JSONAPIPlug.Plug.{ContentTypeNegotiation, Params, QueryParam, ResponseContentType}

  alias Plug.Conn

  plug :config
  plug ContentTypeNegotiation
  plug ResponseContentType
  plug QueryParam, :fields
  plug QueryParam, :filter
  plug QueryParam, :include
  plug QueryParam, :page
  plug QueryParam, :sort
  plug Params

  @impl Plug
  def init(opts), do: NimbleOptions.validate!(opts, @options_schema)

  @doc false
  def config(%Conn{} = conn, _options) do
    {options, assigns} = Map.pop!(conn.assigns, :jsonapi_plug)

    %{conn | assigns: assigns}
    |> fetch_query_params()
    |> put_private(:jsonapi_plug, %JSONAPIPlug{
      allowed_includes: options[:includes],
      api: options[:api],
      resource: options[:resource]
    })
  end

  @impl Plug.ErrorHandler
  def handle_errors(
        conn,
        %{kind: :error, reason: %Exceptions.InvalidDocument{} = exception, stack: _stack}
      ) do
    send_error(conn, :bad_request, %Document.ErrorObject{
      detail: "#{exception.message}. See #{exception.reference} for more information."
    })
  end

  def handle_errors(
        conn,
        %{kind: :error, reason: %Exceptions.InvalidHeader{} = exception, stack: _stack}
      ) do
    send_error(conn, exception.status, %Document.ErrorObject{
      detail: "#{exception.message}. See #{exception.reference} for more information.",
      source: %{pointer: "/header/#{exception.header}"}
    })
  end

  def handle_errors(
        conn,
        %{kind: :error, reason: %Exceptions.InvalidQuery{} = exception, stack: _stack}
      ) do
    send_error(conn, :bad_request, %Document.ErrorObject{
      detail: exception.message,
      source: %{pointer: "/query/#{exception.param}"}
    })
  end

  def handle_errors(conn, error) do
    Logger.error("Unhandled exception: #{inspect(error)}")
    send_resp(conn, 500, "Something went wrong")
  end

  defp send_error(conn, code, error) do
    conn
    |> put_resp_content_type(JSONAPIPlug.mime_type())
    |> send_resp(
      code,
      Jason.encode!(%Document{
        errors: [
          %Document.ErrorObject{
            error
            | status: to_string(Conn.Status.code(code)),
              title: Conn.Status.reason_phrase(Conn.Status.code(code))
          }
        ]
      })
    )
    |> halt()
  end
end
