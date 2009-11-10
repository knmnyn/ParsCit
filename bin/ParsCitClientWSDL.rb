#!/usr/bin/env ruby
require "soap/wsdlDriver"

wsdl = "http://wing.comp.nus.edu.sg/~forecite/forecite.wsdl"
driver = SOAP::WSDLDriverFactory.new(wsdl).create_rpc_driver

output = driver.extract_citations("http://wing.comp.nus.edu.sg/~forecite/samples/W06-0102.txt")
# output = driver.extract_header("/home/forecite/public_html/samples/W06-0102.txt")
# output = driver.extract_meta("/home/forecite/public_html/samples/W06-0102.txt")
puts output
