defmodule JSONAPIPlug.AtomicPlug do
  @moduledoc """
  Plug pipeline for JSON:API Atomic Operations endpoints

  This plug implements the JSON:API Atomic Operations extension
  (`https://jsonapi.org/ext/atomic`) request handling pipeline:

  1. Enforces that the request method is `POST` (returns 405 otherwise).
  2. Validates `Content-Type` and `Accept` headers via `ContentTypeNegotiation`.
  3. Registers the response `Content-Type` hook via `ResponseContentType`.
  4. Parses and normalizes the `atomic:operations` request body via `AtomicParams`.

  ## Usage

  ```elixir
  plug JSONAPIPlug.AtomicPlug,
    api: MyApp.API,
    resources: [MyApp.Post, MyApp.Comment]
  ```

  After the pipeline runs, `conn.private.jsonapi_plug.operations` holds a list of
  normalised operation maps, each with `:op`, `:type`, and `:params` keys.

  ## Options

  - `api:` (required) — A module `use`-ing `JSONAPIPlug.API`.
  - `resources:` (required) — A list of resource modules used to resolve operation types.
    The JSON:API `type` string of each module is mapped to the module at init time.

  ## Notes

  - Atomicity at the database level is the responsibility of the calling application.
  - `lid` values in `add` operations are forwarded in params as `"lid"` for
    cross-operation identity resolution by the application.
  """

  @options_schema NimbleOptions.new!(
                    api: [
                      doc: "A module use-ing `JSONAPIPlug.API` to provide configuration",
                      type: :atom,
                      required: true
                    ],
                    resources: [
                      doc:
                        "List of resource modules. The JSON:API type of each is resolved at init time.",
                      type: {:list, :atom},
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

  alias JSONAPIPlug.{API, Document, Exceptions, Resource}
  alias JSONAPIPlug.Plug.{AtomicParams, ContentTypeNegotiation, ResponseContentType}
  alias Plug.Conn

  plug :enforce_post_method
  plug :config
  plug ContentTypeNegotiation
  plug ResponseContentType
  plug AtomicParams

  @impl Plug
  def init(opts) do
    opts = NimbleOptions.validate!(opts, @options_schema)
    resource_types = build_resource_types(opts[:resources])
    Keyword.put(opts, :resource_types, resource_types)
  end

  @doc false
  def enforce_post_method(%Conn{method: "POST"} = conn, _opts), do: conn

  def enforce_post_method(conn, _opts) do
    conn
    |> put_resp_content_type(JSONAPIPlug.mime_type())
    |> send_resp(
      405,
      Jason.encode!(%Document{
        errors: [%Document.ErrorObject{status: "405", title: "Method Not Allowed"}]
      })
    )
    |> halt()
  end

  @doc false
  def config(%Conn{} = conn, _options) do
    {options, assigns} = Map.pop!(conn.assigns, :jsonapi_plug)

    %{conn | assigns: assigns}
    |> fetch_query_params()
    |> put_private(:jsonapi_plug, %JSONAPIPlug{
      config: API.get_config(options[:api]),
      resource_types: options[:resource_types],
      base_url: build_base_url(conn, options)
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

  def handle_errors(conn, error) do
    Logger.error("Unhandled exception in AtomicPlug: #{inspect(error)}")
    send_resp(conn, 500, "Something went wrong")
  end

  defp send_error(conn, code, %Document.ErrorObject{} = error) do
    status_code = Conn.Status.code(code)

    conn
    |> put_resp_content_type(JSONAPIPlug.mime_type())
    |> send_resp(
      status_code,
      Jason.encode!(%Document{
        errors: [
          %{error | status: to_string(status_code), title: Conn.Status.reason_phrase(status_code)}
        ]
      })
    )
    |> halt()
  end

  defp build_resource_types(resource_modules) do
    Map.new(resource_modules, fn module ->
      resource = struct(module)
      {Resource.type(resource), module}
    end)
  end

  defp build_base_url(conn, options) do
    config = API.get_config(options[:api])

    scheme = to_string(config[:scheme] || conn.scheme)
    host = config[:host] || conn.host

    namespace =
      case config[:namespace] do
        nil -> ""
        ns -> "/" <> ns
      end

    port = config[:port] || conn.port
    port = if port != URI.default_port(scheme), do: port

    to_string(%URI{
      scheme: scheme,
      host: host,
      path: Enum.join([namespace, "operations"], "/"),
      port: port
    })
  end
end
