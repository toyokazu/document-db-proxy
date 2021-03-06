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
    if settings.development?
      @logger.level = Logger::DEBUG
    else
      @logger.level = Logger::INFO
    end
    @logger
  end
end
