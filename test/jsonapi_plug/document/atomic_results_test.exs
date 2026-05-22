defmodule JSONAPIPlug.Document.AtomicResultsTest do
  use ExUnit.Case, async: true

  alias JSONAPIPlug.Document
  alias JSONAPIPlug.Document.ResourceObject
  alias JSONAPIPlug.Exceptions.InvalidDocument

  describe "Document.deserialize/1 with atomic:operations" do
    test "deserializes a valid atomic:operations document" do
      assert %Document{operations: [operation], data: nil} =
               Document.deserialize(%{
                 "atomic:operations" => [
                   %{
                     "op" => "add",
                     "data" => %{"type" => "articles", "attributes" => %{"title" => "Hello"}}
                   }
                 ]
               })

      assert operation.op == "add"
    end

    test "rejects document with both atomic:operations and data" do
      assert_raise InvalidDocument, fn ->
        Document.deserialize(%{
          "atomic:operations" => [%{"op" => "add", "data" => %{"type" => "articles"}}],
          "data" => %{"type" => "articles", "id" => "1"}
        })
      end
    end

    test "rejects document with both atomic:operations and errors" do
      assert_raise InvalidDocument, fn ->
        Document.deserialize(%{
          "atomic:operations" => [%{"op" => "add", "data" => %{"type" => "articles"}}],
          "errors" => [%{"title" => "some error"}]
        })
      end
    end

    test "rejects empty atomic:operations array" do
      assert_raise InvalidDocument, fn ->
        Document.deserialize(%{"atomic:operations" => []})
      end
    end
  end

  describe "Document.serialize/1 with results" do
    test "serializes atomic:results document with data" do
      resource = %ResourceObject{id: "1", type: "articles", attributes: %{"title" => "Hello"}}
      document = Document.serialize(%Document{results: [%{data: resource}]})

      assert %Document{results: [%{data: %ResourceObject{id: "1"}}]} = document
    end

    test "serializes empty result objects for nil-data results" do
      document = Document.serialize(%Document{results: [%{}, %{data: nil}]})
      assert %Document{results: [%{}, %{data: nil}]} = document
    end

    test "serializes mixed results" do
      resource = %ResourceObject{id: "2", type: "post"}

      document =
        Document.serialize(%Document{
          results: [%{data: resource}, %{}]
        })

      assert %Document{results: [_, _]} = document
    end

    test "JSON encoding emits atomic:results key" do
      resource = %ResourceObject{id: "1", type: "articles"}
      document = Document.serialize(%Document{results: [%{data: resource}]})
      encoded = Jason.encode!(document)
      decoded = Jason.decode!(encoded)

      assert Map.has_key?(decoded, "atomic:results")
      refute Map.has_key?(decoded, "data")
      refute Map.has_key?(decoded, "included")
    end

    test "JSON encoding does not include data or included in atomic:results document" do
      resource = %ResourceObject{id: "1", type: "articles"}

      document =
        Document.serialize(%Document{
          results: [%{data: resource}],
          data: resource,
          included: [resource]
        })

      encoded = Jason.encode!(document)
      decoded = Jason.decode!(encoded)

      refute Map.has_key?(decoded, "data")
      refute Map.has_key?(decoded, "included")
      assert Map.has_key?(decoded, "atomic:results")
    end
  end

  describe "Document.serialize/1 standard (no results)" do
    test "JSON encoding does not emit atomic:results key in standard document" do
      resource = %ResourceObject{id: "1", type: "articles"}
      document = Document.serialize(%Document{data: resource})
      encoded = Jason.encode!(document)
      decoded = Jason.decode!(encoded)

      refute Map.has_key?(decoded, "atomic:results")
      assert Map.has_key?(decoded, "data")
    end
  end
end
