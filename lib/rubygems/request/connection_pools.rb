require 'thread'

class Gem::Request::ConnectionPools # :nodoc:

  @client = Net::HTTP

  class << self
    attr_accessor :client
  end

  def initialize proxy_uri, cert_files
    @proxy_uri  = proxy_uri
    @cert_files = cert_files
    @pools      = {}
    @pool_mutex = Mutex.new
  end

  def pool_for uri
    http_args = net_http_args(uri, @proxy_uri)
    key       = http_args + [https?(uri)]
    @pool_mutex.synchronize do
      @pools[key] ||=
        if https? uri then
          Gem::Request::HTTPSPool.new(http_args, @cert_files, @proxy_uri)
        else
          Gem::Request::HTTPPool.new(http_args, @cert_files, @proxy_uri)
        end
    end
  end

  private

  ##
  # Returns list of no_proxy entries (if any) from the environment

  def get_no_proxy_from_env
    env_no_proxy = ENV['no_proxy'] || ENV['NO_PROXY']

    return [] if env_no_proxy.nil?  or env_no_proxy.empty?

    env_no_proxy.split(/\s*,\s*/)
  end

  def https? uri
    uri.scheme.downcase == 'https'
  end

  def no_proxy? host, env_no_proxy
    host = host.downcase
    env_no_proxy.each do |pattern|
      pattern = pattern.downcase
      return true if host[-pattern.length, pattern.length ] == pattern
    end
    return false
  end

  def net_http_args uri, proxy_uri
    net_http_args = [uri.host, uri.port]

    no_proxy = get_no_proxy_from_env

    if proxy_uri and not no_proxy?(uri.host, no_proxy) then
      net_http_args + [
        proxy_uri.host,
        proxy_uri.port,
        Gem::UriFormatter.new(proxy_uri.user).unescape,
        Gem::UriFormatter.new(proxy_uri.password).unescape,
      ]
    elsif no_proxy? uri.host, no_proxy then
      net_http_args += [nil, nil]
    else
      net_http_args
    end
  end

end

