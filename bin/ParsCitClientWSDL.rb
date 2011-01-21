#!/usr/bin/env ruby
require "soap/wsdlDriver"

sdl = "http://wing.comp.nus.edu.sg/~wing.nus/wing.nus.wsdl"
driver = SOAP::WSDLDriverFactory.new(wsdl).create_rpc_driver

output = driver.extract_citations("http://wing.comp.nus.edu.sg/~wing.nus/samples/W06-0102.txt")
# output = driver.extract_header("/home/wing.nus/public_html/samples/W06-0102.txt")
# output = driver.extract_meta("/home/wing.nus/public_html/samples/W06-0102.txt")
puts output
