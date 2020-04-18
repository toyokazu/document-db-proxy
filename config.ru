require File.expand_path '../my_proxy.rb', __FILE__

map('/') { run MyProxy }
