defmodule JSONAPIPlug.AtomicPlugTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias JSONAPIPlug.TestSupport.Plugs.AtomicOperationsPlug
  alias Plug.Conn

  @atomic_ext "https://jsonapi.org/ext/atomic"
  @content_type "application/vnd.api+json; ext=\"#{@atomic_ext}\""

  defp atomic_post(body) do
    conn(:post, "/operations", Jason.encode!(body))
    |> put_req_header("content-type", @content_type)
    |> put_req_header("accept", @content_type)
  end

  describe "POST method enforcement" do
    test "POST request with valid body is accepted" do
      body = %{
        "atomic:operations" => [
          %{"op" => "add", "data" => %{"type" => "post", "attributes" => %{"title" => "Hi"}}}
        ]
      }

      conn =
        atomic_post(body)
        |> AtomicOperationsPlug.call([])

      refute conn.halted
      assert conn.private.jsonapi_plug.operations != nil
    end

    test "GET request returns 405" do
      conn =
        conn(:get, "/operations")
        |> put_req_header("content-type", @content_type)
        |> put_req_header("accept", @content_type)
        |> AtomicOperationsPlug.call([])

      assert conn.halted
      assert conn.status == 405
    end

    test "PATCH request returns 405" do
      conn =
        conn(:patch, "/operations", "{}")
        |> put_req_header("content-type", @content_type)
        |> put_req_header("accept", @content_type)
        |> AtomicOperationsPlug.call([])

      assert conn.halted
      assert conn.status == 405
    end

    test "DELETE request returns 405" do
      conn =
        conn(:delete, "/operations")
        |> put_req_header("content-type", @content_type)
        |> put_req_header("accept", @content_type)
        |> AtomicOperationsPlug.call([])

      assert conn.halted
      assert conn.status == 405
    end
  end

  describe "content negotiation" do
    test "request with unsupported ext in Content-Type raises 415" do
      body = %{
        "atomic:operations" => [
          %{"op" => "add", "data" => %{"type" => "post", "attributes" => %{"title" => "Hi"}}}
        ]
      }

      # Sending a different (unsupported) ext URI — should get 415
      assert_raise JSONAPIPlug.Exceptions.InvalidHeader, fn ->
        conn(:post, "/operations", Jason.encode!(body))
        |> put_req_header(
          "content-type",
          "application/vnd.api+json; ext=\"https://unknown.example.com/ext\""
        )
        |> put_req_header("accept", @content_type)
        |> AtomicOperationsPlug.call([])
      end
    end

    test "request with atomic ext in Content-Type and Accept passes" do
      body = %{
        "atomic:operations" => [
          %{"op" => "add", "data" => %{"type" => "post", "attributes" => %{"title" => "Hi"}}}
        ]
      }

      conn =
        atomic_post(body)
        |> AtomicOperationsPlug.call([])

      refute conn.halted
    end

    test "request without ext in Content-Type passes content negotiation (ext not required by server)" do
      body = %{
        "atomic:operations" => [
          %{"op" => "add", "data" => %{"type" => "post", "attributes" => %{"title" => "Hi"}}}
        ]
      }

      conn =
        conn(:post, "/operations", Jason.encode!(body))
        |> put_req_header("content-type", JSONAPIPlug.mime_type())
        |> put_req_header("accept", JSONAPIPlug.mime_type())
        |> AtomicOperationsPlug.call([])

      # Content negotiation does not require ext from client; body parsing will succeed
      refute conn.halted
    end
  end

  describe "operations parsing" do
    test "valid multi-operation batch is parsed into jsonapi_plug.operations" do
      body = %{
        "atomic:operations" => [
          %{"op" => "add", "data" => %{"type" => "post", "attributes" => %{"title" => "First"}}},
          %{"op" => "remove", "ref" => %{"type" => "post", "id" => "99"}}
        ]
      }

      %Conn{private: %{jsonapi_plug: %JSONAPIPlug{operations: operations}}} =
        atomic_post(body)
        |> AtomicOperationsPlug.call([])

      assert length(operations) == 2
      assert Enum.at(operations, 0).op == "add"
      assert Enum.at(operations, 1).op == "remove"
      assert Enum.at(operations, 1).params["id"] == "99"
    end

    test "jsonapi_plug.params is nil for atomic requests" do
      body = %{
        "atomic:operations" => [
          %{"op" => "add", "data" => %{"type" => "post", "attributes" => %{"title" => "Hi"}}}
        ]
      }

      %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: params}}} =
        atomic_post(body)
        |> AtomicOperationsPlug.call([])

      assert is_nil(params)
    end
  end

  describe "pipeline isolation" do
    test "AtomicPlug does not affect single-resource plug pipelines" do
      # Verify that the regular PostResourcePlug still works independently
      alias JSONAPIPlug.TestSupport.Plugs.PostResourcePlug

      conn =
        conn(:get, "/")
        |> put_req_header("content-type", JSONAPIPlug.mime_type())
        |> put_req_header("accept", JSONAPIPlug.mime_type())
        |> PostResourcePlug.call([])

      refute conn.halted
      assert %JSONAPIPlug{} = conn.private.jsonapi_plug
      assert is_nil(conn.private.jsonapi_plug.operations)
    end
  end
end
