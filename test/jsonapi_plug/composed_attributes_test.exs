defmodule JSONAPIPlug.ComposedAttributesTest do
  use ExUnit.Case

  import Plug.Conn
  import Plug.Test

  alias JSONAPIPlug.TestSupport.Plugs.ComposedNameUserPlug
  alias JSONAPIPlug.TestSupport.Resources.{ComposedCamelUser, ComposedNameUser}
  alias Plug.Conn

  # Plug for camelCase recase testing (DefaultAPI uses :camelize by default)
  defmodule ComposedCamelUserRenderPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason

    plug JSONAPIPlug.Plug,
      api: JSONAPIPlug.TestSupport.API.DefaultAPI,
      path: "composed-camel-users",
      resource: JSONAPIPlug.TestSupport.Resources.ComposedCamelUser

    plug :passthrough

    defp passthrough(conn, _) do
      resp =
        JSONAPIPlug.render(conn, conn.assigns[:data], conn.assigns[:meta])
        |> Jason.encode!()

      send_resp(conn, 200, resp)
    end
  end

  defmodule ComposedCamelUserPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason

    plug JSONAPIPlug.Plug,
      api: JSONAPIPlug.TestSupport.API.DefaultAPI,
      path: "composed-camel-users",
      resource: JSONAPIPlug.TestSupport.Resources.ComposedCamelUser
  end

  # A plug that also renders the response, so we can test serialization end-to-end
  defmodule ComposedNameUserRenderPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason

    plug JSONAPIPlug.Plug,
      api: JSONAPIPlug.TestSupport.API.DefaultAPI,
      path: "composed-name-users",
      resource: JSONAPIPlug.TestSupport.Resources.ComposedNameUser

    plug :passthrough

    defp passthrough(conn, _) do
      resp =
        JSONAPIPlug.render(conn, conn.assigns[:data], conn.assigns[:meta])
        |> Jason.encode!()

      send_resp(conn, 200, resp)
    end
  end

  describe "serialization (struct → JSON API)" do
    test "expands composed field into derived fields" do
      conn =
        conn(:get, "/composed-name-users")
        |> assign(:data, [%ComposedNameUser{id: 1, username: "mrossi", full_name: "Mario/Rossi"}])
        |> ComposedNameUserRenderPlug.call([])

      assert %{
               "data" => [
                 %{
                   "id" => "1",
                   "type" => "composed-name-user",
                   "attributes" => attributes
                 }
               ]
             } = Jason.decode!(conn.resp_body)

      assert attributes["nome"] == "Mario"
      assert attributes["cognome"] == "Rossi"
      refute Map.has_key?(attributes, "full_name"), "real field must not appear in JSON API"
    end

    test "includes normal attributes alongside composed ones" do
      conn =
        conn(:get, "/composed-name-users")
        |> assign(:data, [%ComposedNameUser{id: 1, username: "mrossi", full_name: "Mario/Rossi"}])
        |> ComposedNameUserRenderPlug.call([])

      assert %{
               "data" => [%{"attributes" => attributes}]
             } = Jason.decode!(conn.resp_body)

      assert attributes["username"] == "mrossi"
      assert attributes["nome"] == "Mario"
      assert attributes["cognome"] == "Rossi"
    end

    test "handles nil composed field value" do
      conn =
        conn(:get, "/composed-name-users")
        |> assign(:data, [%ComposedNameUser{id: 1, username: "mrossi", full_name: nil}])
        |> ComposedNameUserRenderPlug.call([])

      assert %{
               "data" => [%{"attributes" => attributes}]
             } = Jason.decode!(conn.resp_body)

      assert is_nil(attributes["nome"])
      assert is_nil(attributes["cognome"])
    end
  end

  describe "deserialization (JSON API → params)" do
    test "composes derived fields into the real field" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: params}}} =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "type" => "composed-name-user",
                     "attributes" => %{
                       "username" => "mrossi",
                       "nome" => "Mario",
                       "cognome" => "Rossi"
                     }
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> ComposedNameUserPlug.call([])

      assert params["full_name"] == "Mario/Rossi"
      assert params["username"] == "mrossi"
    end

    test "does not include derived fields as independent params" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: params}}} =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "type" => "composed-name-user",
                     "attributes" => %{
                       "nome" => "Mario",
                       "cognome" => "Rossi"
                     }
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> ComposedNameUserPlug.call([])

      refute Map.has_key?(params, "nome"), "derived field must not appear as independent param"
      refute Map.has_key?(params, "cognome"), "derived field must not appear as independent param"
    end

    test "does not call deserialize when no derived fields are present" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: params}}} =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "type" => "composed-name-user",
                     "attributes" => %{
                       "username" => "mrossi"
                     }
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> ComposedNameUserPlug.call([])

      refute Map.has_key?(params, "full_name"),
             "real field must not appear in params when no derived fields are present"

      assert params["username"] == "mrossi"
    end

    test "calls deserialize with partial derived fields map" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: params}}} =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "type" => "composed-name-user",
                     "attributes" => %{
                       "nome" => "Mario"
                     }
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> ComposedNameUserPlug.call([])

      # deserialize is called with partial map %{nome: "Mario"}, produces "Mario/" (cognome is nil)
      assert params["full_name"] == "Mario/"
    end
  end

  describe "recase of derived fields (camelize)" do
    test "serialization recases derived field keys to camelCase" do
      conn =
        conn(:get, "/composed-camel-users")
        |> assign(:data, [%ComposedCamelUser{id: 1, full_name: "Mario Rossi"}])
        |> ComposedCamelUserRenderPlug.call([])

      assert %{"data" => [%{"attributes" => attributes}]} = Jason.decode!(conn.resp_body)

      assert attributes["firstName"] == "Mario"
      assert attributes["lastName"] == "Rossi"
      refute Map.has_key?(attributes, "first_name")
      refute Map.has_key?(attributes, "last_name")
      refute Map.has_key?(attributes, "full_name")
    end

    test "deserialization accepts camelCase derived field keys from client" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: params}}} =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "type" => "composed-camel-user",
                     "attributes" => %{
                       "firstName" => "Mario",
                       "lastName" => "Rossi"
                     }
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> ComposedCamelUserPlug.call([])

      assert params["full_name"] == "Mario Rossi"
      refute Map.has_key?(params, "firstName")
      refute Map.has_key?(params, "lastName")
      refute Map.has_key?(params, "first_name")
      refute Map.has_key?(params, "last_name")
    end
  end

  describe "compile-time validation" do
    test "raises if type: :composed is declared without composed_of" do
      assert_raise RuntimeError, ~r/composed_of/, fn ->
        defmodule InvalidComposedNoCF do
          @derive {
            JSONAPIPlug.Resource,
            type: "invalid",
            attributes: [
              full_name: [type: :composed]
            ]
          }

          defstruct id: nil, full_name: nil
        end
      end
    end

    test "raises if type: :composed is used with serialize: false" do
      assert_raise RuntimeError, ~r/serialize/, fn ->
        defmodule InvalidComposedSerializeFalse do
          @derive {
            JSONAPIPlug.Resource,
            type: "invalid",
            attributes: [
              full_name: [
                type: :composed,
                composed_of: [:nome, :cognome],
                serialize: false
              ]
            ]
          }

          defstruct id: nil, full_name: nil
        end
      end
    end

    test "raises if type: :composed is used with deserialize: false" do
      assert_raise RuntimeError, ~r/deserialize/, fn ->
        defmodule InvalidComposedDeserializeFalse do
          @derive {
            JSONAPIPlug.Resource,
            type: "invalid",
            attributes: [
              full_name: [
                type: :composed,
                composed_of: [:nome, :cognome],
                deserialize: false
              ]
            ]
          }

          defstruct id: nil, full_name: nil
        end
      end
    end
  end
end
