#!/usr/bin/env ruby
require 'soap/rpc/standaloneServer'
require 'net/http'
require 'soap/rpc/driver'
require 'tempfile'
require 'uri'

@@PORT = 10555
@@SERVICE = 'urn:ForeCite/ParsCit'
@@ID = 'ParsCit'
@@Web_Service_ID = 'urn:ForeCite'
#@@Web_Service_Port = '4000' # changed by min '10570'
@@Web_Service_Port = '4000'
#@@Web_Service_Host = 'wing.comp.nus.edu.sg'
@@Web_Service_Host = 'aye'

class ParsCitServer < SOAP::RPC::StandaloneServer
  @@PARSCIT_CMD = "~/services/parscit/bin/citeExtract.pl"

  def on_init
    @log.level = Logger::Severity::INFO
    add_method(self, 'extract_citations', 'uri_or_path')
    add_method(self, 'extract_header', 'uri_or_path')
    add_method(self, 'extract_meta', 'uri_or_path')
    add_method(self, 'ping')
  end

  def ping 
    "ping"
  end

  def extract_citations(uri_or_path)
    extract_core(uri_or_path,"citations",@@PARSCIT_CMD + " -m extract_citations")
  end

  def extract_header(uri_or_path)
    extract_core(uri_or_path,"header",@@PARSCIT_CMD + " -m extract_header")
  end

  def extract_meta(uri_or_path)
    extract_core(uri_or_path,"extract_meta",@@PARSCIT_CMD + " -m extract_meta")
  end

  def extract_core(uri_or_path,mode,command)
    uri = URI.extract(uri_or_path)
    localfile = ""
    if (uri.size == 0) # get local file to process
      localfile = uri_or_path
    else # get file to process from uri specification
      tempfile = Tempfile.new("ParsCitServer")
      tempfile.binmode
      tempfile.puts(Net::HTTP.get(URI.parse(uri_or_path)))
      tempfile.close()
      localfile = tempfile.path()
    end
    `#{command} #{localfile}`
  end
end

if $0 == __FILE__
  if (defined? ARGV[0]) 
    case ARGV[0]
    when '-r' # use -r to register with web service server
      hostname = `hostname -f`
	  hostname.chomp!()
      s = SOAP::RPC::Driver.new("http://#{@@Web_Service_Host}:#{@@Web_Service_Port}/", @@Web_Service_ID)
      puts "# #{$0} info\tRegistering with web service server #{@@Web_Service_Host}\n"
      s.add_method('register','service','machine')
      s.register('extract_citations',hostname)
      s.register('extract_header',hostname)
      s.register('extract_meta',hostname)
    when '-h'
      puts "#{$0} Usage:\n"
      puts "\t-r\tRegister with web service server\n"
      exit()
    end
  end

  server = ParsCitServer.new(@@ID, @@SERVICE, '0.0.0.0', @@PORT)

  trap(:INT) do
    server.shutdown
  end
  server.start
end
