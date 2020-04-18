require File.expand_path '../elasticsearch.rb', __FILE__

class MyProxy < Elasticsearch
  # override authorization logics if necessary
  # def authorized?(username)
  #   ...
  # end
  
  # def should_be_denied?(body, r_type)
  #   ...
  # end
  
  # def add_condition(body)
  #   ...
  # end
end
