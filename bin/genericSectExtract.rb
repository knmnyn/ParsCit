#!/usr/bin/env ruby
require 'find'
# Emma

pwd = File.dirname(__FILE__)

@CRFPP  = "#{pwd}/../crfpp"
@SRC    = "#{pwd}/genericSect"
@TMP    = "#{pwd}/genericSect/tmp"
@DATA   = "#{pwd}/genericSect/data"

cmd = "rm #{@TMP}/*"
system(cmd)

cmd = "cp #{ARGV[0]} #{@TMP}/tmp.hea"
system(cmd)

cmd = "ruby #{@SRC}/createFeature_test.rb #{@TMP} > #{@TMP}/tmp.test"
system(cmd)

if ARGV[1] == nil
cmd = "#{@CRFPP}/crf_test -m #{@DATA}/crf.model  #{@TMP}/tmp.test > #{@TMP}/tmp.out"
system(cmd)

f = File.open("#{@TMP}/tmp.out")
while !f.eof do
	str = f.gets.chomp.strip
	if str != ""
	l = str.split(" ")
	puts "#{l.at(l.length-1)}"
	end
end
f.close
else
cmd = "#{@CRFPP}/crf_test -m #{@DATA}/crf.model  #{@TMP}/tmp.test > #{ARGV[1]}"
system(cmd)


end
