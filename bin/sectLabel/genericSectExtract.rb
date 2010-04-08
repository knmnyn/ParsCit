#!/usr/bin/env ruby
require 'find'
# Emma

pwd = File.dirname(__FILE__)

@CRFPP  = "#{pwd}/../../crfpp"
@SRC    = "#{pwd}/genericSect"
@DATA   = "#{pwd}/../../resources/sectLabel/genericSect/"
@TEST_DIR = "#{pwd}/genericSect/run"

name  = "#{Time.now.to_i}-#{Process.pid}"

cmd = "ruby #{@SRC}/createFeature_test.rb #{ARGV[0]} > #{@TEST_DIR}/#{name}.test"
system(cmd)

cmd = "#{@CRFPP}/crf_test -m #{@DATA}/crf.model  #{@TEST_DIR}/#{name}.test >  #{@TEST_DIR}/#{name}.out"
system(cmd)


if ARGV[1] != nil
	g = File.open("#{ARGV[1]}", "w")
	
	cmd = "chmod 777 #{ARGV[1]}"
	system(cmd)
end

f = File.open("#{@TEST_DIR}/#{name}.out")
while !f.eof do
	str = f.gets.chomp.strip
	if str != ""
		l = str.split(" ")
		if ARGV[1] == nil
			puts "#{l.at(l.length-1)}"
		else
			g.write("#{l.at(l.length-1)}\n")
		end
	end
end
f.close
if ARGV[1] != nil
	g.close
end

File.unlink("#{@TEST_DIR}/#{name}.out")
File.unlink("#{@TEST_DIR}/#{name}.test")
