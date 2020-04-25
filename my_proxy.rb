require File.expand_path '../elasticsearch.rb', __FILE__

class MyProxy < Elasticsearch
  # override configuration parameters if necessary
  # configure :production, :development do
  #   set :uri, URI.parse("http://localhost:9200")
  #   set :owner_attr, "owner"
  # end

  # override authorization logics if necessary
  # def authorized?(username)
  #   ...
  # end
  
  # def should_be_denied?(body, r_type)
  #   ...
  # end
 
  # sample logic for allowing access to friends' data in the same teams
  #
  # def add_condition(body)
  #   return {} if body == ""
  #   response = HTTParty.get(settings.uri + "/teams/_search",
  #                           headers: {"Content-Type": "application/json"},
  #                           body: {query: {terms: {members: [get_username]}}}.to_json)
  #   friends = (JSON.parse(response.body)["hits"]["hits"].reduce([]) {|result, item| (result + item["_source"]["members"]).uniq} + [get_username]).uniq
  #   add_filter(JSON.parse(body), {"terms": {"username": friends}})
  # end
end
