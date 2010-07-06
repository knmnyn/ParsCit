#!/usr/bin/env ruby
require 'soap/rpc/driver'
require 'optparse'
require 'ostruct'

# set up options / defaults / user customization
@@VERSION = [1,0]
options = OpenStruct.new()
#options.hostname = Default_Hostname = "wing.comp.nus.edu.sg"
options.hostname = Default_Hostname = "aye"
options.port = Default_Port = "10570"
options.service_id = Default_Service_ID = "urn:ForeCite"
options.action = Default_Action = "extract_citations"
  
opts = OptionParser.new do |opts|
  opts.banner = "usage: #{$0} [options] text_file_or_uri"

  opts.separator ""
  opts.on_tail("-h", "--help", "Show this message") do puts opts; exit end
  opts.on("-H", "--hostname [HOSTNAME]", "e.g., #{Default_Hostname}") do |o| options.hostname = o end
  opts.on("-p", "--port [PORT]", "e.g., #{Default_Port}") do |o| options.port = o end
  opts.on("-s", "--service_id [SERVICE_ID]", "default #{Default_Service_ID}") do |o| options.service_id = o end
  opts.on("-a", "--action [ACTION]", "(default:#{Default_Action}, extract_citations, extract_header, extract_meta)") do |o| options.action = o end
  opts.on("-v", "--version", "Show version") do puts "#{$0} " + @@VERSION.join('.'); exit end
end
opts.parse!(ARGV)

# puts "#{options.hostname} #{options.port} #{options.action} #{options.service_id}"

s = SOAP::RPC::Driver.new("http://#{options.hostname}:#{options.port}/", options.service_id)
case options.action 
when "extract_citations"
  s.add_method(options.action, "uri_or_path")
  puts s.extract_citations(ARGV[0])
when "extract_header"
  s.add_method(options.action, "uri_or_path")
  puts s.extract_header(ARGV[0])
when "extract_meta"
  s.add_method(options.action, "uri_or_path")
  puts s.extract_meta(ARGV[0])
when "ping"
  s.add_method(options.action)
  puts s.ping()
when "status"
  s.add_method(options.action)
  puts s.status()
when "register"
  s.add_method(options.action, "service", "machine")
  puts s.register(ARGV[0],ARGV[1])
when "deregister"
  s.add_method(options.action, "service", "machine")
  puts s.deregister(ARGV[0],ARGV[1])
end
