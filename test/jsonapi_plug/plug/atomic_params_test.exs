defmodule JSONAPIPlug.Plug.AtomicParamsTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias JSONAPIPlug.Exceptions.InvalidDocument
  alias JSONAPIPlug.TestSupport.Plugs.AtomicOperationsPlug
  alias Plug.Conn

  @atomic_ext "https://jsonapi.org/ext/atomic"
  @content_type "application/vnd.api+json; ext=\"#{@atomic_ext}\""

  defp atomic_conn(body) do
    conn(:post, "/operations", Jason.encode!(body))
    |> put_req_header("content-type", @content_type)
    |> put_req_header("accept", @content_type)
  end

  describe "add operation normalisation" do
    test "add operation with attributes produces params" do
      body = %{
        "atomic:operations" => [
          %{
            "op" => "add",
            "data" => %{
              "type" => "post",
              "attributes" => %{"title" => "Hello", "body" => "World"}
            }
          }
        ]
      }

      %Conn{private: %{jsonapi_plug: %JSONAPIPlug{operations: operations, params: params}}} =
        atomic_conn(body)
        |> AtomicOperationsPlug.call([])

      assert is_nil(params)
      assert [%{op: "add", type: "post", params: op_params}] = operations
      assert op_params["title"] == "Hello"
      assert op_params["body"] == "World"
    end

    test "add operation with lid stores lid in params" do
      body = %{
        "atomic:operations" => [
          %{
            "op" => "add",
            "data" => %{"type" => "post", "lid" => "temp-1", "attributes" => %{"title" => "Hi"}}
          }
        ]
      }

      %Conn{private: %{jsonapi_plug: %JSONAPIPlug{operations: operations}}} =
        atomic_conn(body)
        |> AtomicOperationsPlug.call([])

      assert [%{op: "add", type: "post", params: op_params}] = operations
      assert op_params["lid"] == "temp-1"
    end
  end

  describe "remove operation normalisation" do
    test "remove operation with ref produces params with id" do
      body = %{
        "atomic:operations" => [
          %{
            "op" => "remove",
            "ref" => %{"type" => "post", "id" => "13"}
          }
        ]
      }

      %Conn{private: %{jsonapi_plug: %JSONAPIPlug{operations: operations}}} =
        atomic_conn(body)
        |> AtomicOperationsPlug.call([])

      assert [%{op: "remove", type: "post", params: op_params}] = operations
      assert op_params["id"] == "13"
    end
  end

  describe "update operation normalisation" do
    test "update operation produces params with id and attributes" do
      body = %{
        "atomic:operations" => [
          %{
            "op" => "update",
            "data" => %{
              "type" => "post",
              "id" => "5",
              "attributes" => %{"title" => "Updated title"}
            }
          }
        ]
      }

      %Conn{private: %{jsonapi_plug: %JSONAPIPlug{operations: operations}}} =
        atomic_conn(body)
        |> AtomicOperationsPlug.call([])

      assert [%{op: "update", type: "post", params: op_params}] = operations
      assert op_params["id"] == "5"
      assert op_params["title"] == "Updated title"
    end
  end

  describe "multiple operations" do
    test "multiple operations are all normalised" do
      body = %{
        "atomic:operations" => [
          %{
            "op" => "add",
            "data" => %{"type" => "post", "attributes" => %{"title" => "New"}}
          },
          %{
            "op" => "remove",
            "ref" => %{"type" => "post", "id" => "42"}
          }
        ]
      }

      %Conn{private: %{jsonapi_plug: %JSONAPIPlug{operations: operations}}} =
        atomic_conn(body)
        |> AtomicOperationsPlug.call([])

      assert length(operations) == 2
      assert Enum.at(operations, 0).op == "add"
      assert Enum.at(operations, 1).op == "remove"
      assert Enum.at(operations, 1).params["id"] == "42"
    end
  end

  describe "unknown resource type" do
    test "unknown type in operation raises InvalidDocument" do
      body = %{
        "atomic:operations" => [
          %{
            "op" => "add",
            "data" => %{"type" => "unknown-widget", "attributes" => %{}}
          }
        ]
      }

      assert_raise InvalidDocument, fn ->
        atomic_conn(body)
        |> AtomicOperationsPlug.call([])
      end
    end
  end

  describe "params field exclusivity" do
    test "jsonapi_plug.params is nil for atomic requests" do
      body = %{
        "atomic:operations" => [
          %{"op" => "add", "data" => %{"type" => "post", "attributes" => %{"title" => "Hi"}}}
        ]
      }

      %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: params}}} =
        atomic_conn(body)
        |> AtomicOperationsPlug.call([])

      assert is_nil(params)
    end
  end
end
