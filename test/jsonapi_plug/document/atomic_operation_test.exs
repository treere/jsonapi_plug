defmodule JSONAPIPlug.Document.AtomicOperationTest do
  use ExUnit.Case, async: true

  alias JSONAPIPlug.Document.{AtomicOperation, OperationRef, ResourceObject}
  alias JSONAPIPlug.Exceptions.InvalidDocument

  describe "deserialize/1 — valid op codes" do
    test "op code 'add' with data is accepted" do
      assert %AtomicOperation{op: "add", data: %ResourceObject{type: "articles"}} =
               AtomicOperation.deserialize(%{
                 "op" => "add",
                 "data" => %{"type" => "articles", "attributes" => %{"title" => "Hello"}}
               })
    end

    test "op code 'update' is accepted" do
      assert %AtomicOperation{op: "update", data: %ResourceObject{type: "articles", id: "1"}} =
               AtomicOperation.deserialize(%{
                 "op" => "update",
                 "data" => %{"type" => "articles", "id" => "1", "attributes" => %{"title" => "X"}}
               })
    end

    test "op code 'remove' with ref is accepted" do
      assert %AtomicOperation{op: "remove", ref: %OperationRef{type: "articles", id: "13"}} =
               AtomicOperation.deserialize(%{
                 "op" => "remove",
                 "ref" => %{"type" => "articles", "id" => "13"}
               })
    end
  end

  describe "deserialize/1 — invalid op codes" do
    test "unknown op code raises InvalidDocument" do
      assert_raise InvalidDocument, fn ->
        AtomicOperation.deserialize(%{"op" => "replace", "data" => %{"type" => "articles"}})
      end
    end

    test "op code 'create' raises InvalidDocument" do
      assert_raise InvalidDocument, fn ->
        AtomicOperation.deserialize(%{"op" => "create", "data" => %{"type" => "articles"}})
      end
    end

    test "missing op member raises InvalidDocument" do
      assert_raise InvalidDocument, fn ->
        AtomicOperation.deserialize(%{"data" => %{"type" => "articles"}})
      end
    end
  end

  describe "deserialize/1 — ref and href mutual exclusion" do
    test "both ref and href raises InvalidDocument" do
      assert_raise InvalidDocument, fn ->
        AtomicOperation.deserialize(%{
          "op" => "update",
          "ref" => %{"type" => "articles", "id" => "1"},
          "href" => "/articles/1"
        })
      end
    end

    test "only ref is accepted" do
      assert %AtomicOperation{op: "update", ref: %OperationRef{}, href: nil} =
               AtomicOperation.deserialize(%{
                 "op" => "update",
                 "ref" => %{"type" => "articles", "id" => "1"},
                 "data" => %{"type" => "articles", "attributes" => %{"title" => "New"}}
               })
    end

    test "only href is accepted" do
      assert %AtomicOperation{op: "add", href: "/blogPosts", ref: nil} =
               AtomicOperation.deserialize(%{
                 "op" => "add",
                 "href" => "/blogPosts",
                 "data" => %{"type" => "articles", "attributes" => %{"title" => "Hello"}}
               })
    end
  end

  describe "deserialize/1 — meta member" do
    test "meta is parsed when present" do
      assert %AtomicOperation{meta: %{"key" => "value"}} =
               AtomicOperation.deserialize(%{
                 "op" => "add",
                 "data" => %{"type" => "articles"},
                 "meta" => %{"key" => "value"}
               })
    end

    test "meta is nil when not present" do
      assert %AtomicOperation{meta: nil} =
               AtomicOperation.deserialize(%{
                 "op" => "add",
                 "data" => %{"type" => "articles"}
               })
    end
  end
end
