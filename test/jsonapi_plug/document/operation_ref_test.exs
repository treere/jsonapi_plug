defmodule JSONAPIPlug.Document.OperationRefTest do
  use ExUnit.Case, async: true

  alias JSONAPIPlug.Document.OperationRef
  alias JSONAPIPlug.Exceptions.InvalidDocument

  describe "deserialize/1" do
    test "valid ref with type and id" do
      assert %OperationRef{type: "articles", id: "1", lid: nil, relationship: nil} =
               OperationRef.deserialize(%{"type" => "articles", "id" => "1"})
    end

    test "valid ref with type and lid" do
      assert %OperationRef{type: "articles", lid: "temp-1", id: nil, relationship: nil} =
               OperationRef.deserialize(%{"type" => "articles", "lid" => "temp-1"})
    end

    test "valid ref with type, id, and relationship" do
      assert %OperationRef{type: "articles", id: "1", relationship: "author"} =
               OperationRef.deserialize(%{
                 "type" => "articles",
                 "id" => "1",
                 "relationship" => "author"
               })
    end

    test "valid ref with type, lid, and relationship" do
      assert %OperationRef{type: "articles", lid: "temp-1", relationship: "tags"} =
               OperationRef.deserialize(%{
                 "type" => "articles",
                 "lid" => "temp-1",
                 "relationship" => "tags"
               })
    end

    test "missing id and lid raises InvalidDocument" do
      assert_raise InvalidDocument, fn ->
        OperationRef.deserialize(%{"type" => "articles"})
      end
    end

    test "missing type raises InvalidDocument" do
      assert_raise InvalidDocument, fn ->
        OperationRef.deserialize(%{"id" => "1"})
      end
    end

    test "empty type string raises InvalidDocument" do
      assert_raise InvalidDocument, fn ->
        OperationRef.deserialize(%{"type" => "", "id" => "1"})
      end
    end

    test "empty id string is treated as missing" do
      assert_raise InvalidDocument, fn ->
        OperationRef.deserialize(%{"type" => "articles", "id" => ""})
      end
    end

    test "relationship field is nil when not provided" do
      %OperationRef{relationship: relationship} =
        OperationRef.deserialize(%{"type" => "articles", "id" => "1"})

      assert is_nil(relationship)
    end
  end
end
