import Config

alias JSONAPI.TestSupport.APIs.{
  DasherizingAPI,
  DefaultAPI,
  OtherHostAPI,
  OtherNamespaceAPI,
  OtherSchemeAPI,
  UnderscoringAPI
}

alias JSONAPI.TestSupport.Paginators.PageBasedPaginator

config :jsonapi, DasherizingAPI, inflection: :dasherize
config :jsonapi, DefaultAPI, paginator: PageBasedPaginator
config :jsonapi, OtherHostAPI, host: "www.otherhost.com"
config :jsonapi, OtherNamespaceAPI, namespace: "somespace"
config :jsonapi, OtherSchemeAPI, scheme: :https
config :jsonapi, UnderscoringAPI, inflection: :underscore
