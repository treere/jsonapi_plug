defmodule JSONAPIPlug.RenderAtomicTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias JSONAPIPlug.Document
  alias JSONAPIPlug.Document.ResourceObject
  alias JSONAPIPlug.TestSupport.Plugs.AtomicOperationsPlug
  alias JSONAPIPlug.TestSupport.Resources.Post

  @atomic_ext "https://jsonapi.org/ext/atomic"
  @content_type "application/vnd.api+json; ext=\"#{@atomic_ext}\""

  defp build_conn do
    body = %{
      "atomic:operations" => [
        %{"op" => "add", "data" => %{"type" => "post", "attributes" => %{"title" => "Hi"}}}
      ]
    }

    conn(:post, "/operations", Jason.encode!(body))
    |> put_req_header("content-type", @content_type)
    |> put_req_header("accept", @content_type)
    |> AtomicOperationsPlug.call([])
  end

  describe "render_atomic/3" do
    test "returns nil when all results have nil resource (signals 204)" do
      conn = build_conn()
      result = JSONAPIPlug.render_atomic(conn, [{nil, nil}, {nil, nil}])
      assert is_nil(result)
    end

    test "returns nil for empty result tuple with nil resource" do
      conn = build_conn()
      assert is_nil(JSONAPIPlug.render_atomic(conn, [{nil, nil}]))
    end

    test "returns Document with atomic:results when any result has data" do
      conn = build_conn()
      post = %Post{id: "1", title: "Hello", text: "World"}
      result = JSONAPIPlug.render_atomic(conn, [{post, nil}])

      assert %Document{results: [%{data: %ResourceObject{id: "1", type: "post"}}]} = result
    end

    test "positional alignment: nil results produce empty result objects" do
      conn = build_conn()
      post = %Post{id: "2", title: "Second", text: "Text"}
      result = JSONAPIPlug.render_atomic(conn, [{nil, nil}, {post, nil}])

      assert %Document{results: [result_0, result_1]} = result
      assert result_0 == %{}
      assert %{data: %ResourceObject{id: "2", type: "post"}} = result_1
    end

    test "result with meta includes meta in result object" do
      conn = build_conn()
      post = %Post{id: "3", title: "With meta", text: "text"}
      result = JSONAPIPlug.render_atomic(conn, [{post, %{"custom" => "value"}}])

      assert %Document{results: [%{data: %ResourceObject{}, meta: %{"custom" => "value"}}]} =
               result
    end

    test "result with nil resource and meta includes meta in empty result" do
      conn = build_conn()
      result = JSONAPIPlug.render_atomic(conn, [{nil, %{"info" => "ok"}}])

      assert %Document{results: [%{meta: %{"info" => "ok"}}]} = result
    end

    test "JSON encoding of atomic results document emits atomic:results key" do
      conn = build_conn()
      post = %Post{id: "4", title: "Encoded", text: "text"}
      document = JSONAPIPlug.render_atomic(conn, [{post, nil}])

      encoded = Jason.encode!(document)
      decoded = Jason.decode!(encoded)

      assert Map.has_key?(decoded, "atomic:results")
      refute Map.has_key?(decoded, "data")
    end
  end
end
