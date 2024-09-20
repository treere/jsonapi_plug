use Plug.Test

defmodule MyApp.UsersResource do
  use JSONAPIPlug.Resource,
    type: "user",
    attributes: [:name, :surname, :username]
end

defmodule DefaultAPI do
  use JSONAPIPlug.API, otp_app: :sibill
end

defmodule UserResourcePlug do
  use Plug.Builder

  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug JSONAPIPlug.Plug, api: DefaultAPI, resource: MyApp.UsersResource
end

data =
  Jason.encode!(%{
    "data" => %{
      "id" => "1",
      "type" => "user",
      "attributes" => %{
        "name" => "name",
        "surname" => "surname",
        "username" => "username"
      }
    }
  })

test = fn ->
  conn(:post, "/", data)
  |> put_req_header("content-type", JSONAPIPlug.mime_type())
  |> put_req_header("accept", JSONAPIPlug.mime_type())
  |> UserResourcePlug.call([])
end

bench_options = [
  time: 10,
  memory_time: 2
]

Benchee.run(
  %{
    "Test" => test
  },
  bench_options
)
