require 'sinatra'
require 'httparty'
require 'active_support/all'
require 'json'

class Proxy < Sinatra::Base
  configure :production, :development do
    enable :logger
  end

  def logger
    return @logger unless @logger.nil?
    file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    file.sync = true
    @logger = Logger.new(file)
    @logger.level = Logger::DEBUG if settings.development?
    @logger
  end
end
