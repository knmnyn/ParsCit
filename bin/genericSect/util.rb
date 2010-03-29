#!/usr/bin/env ruby
require 'find'
=begin
def getPos (val)
	if val == 0
		return 0
	end
	i = 1
	while i <= 10 do
		if val <= (i/10.0) 
			return i
		end
		i = i + 1
	end
	return -1
end

def getHeader(str)
	str = str.strip
	while str.index(" ") != nil do
		str = str.sub(" ", "_")
	end
	return str.downcase
end
=end
dirPath   = ARGV[0]
files	  = Array.new
Find.find("#{dirPath}") do |path|
	if FileTest.directory?(path)
		next		
	else
		endIndex   = path.index(".")  - 1
		name	   = path[0..endIndex]
		if !files.include?(name)
			files << name
		end
	end
end

file_array = Array.new
for file in files do
	f = File.open("#{file}.ahea")
	while !f.eof do
		if f.gets.chomp == "#{ARGV[1]}"
			file_array.push(file)
			break
		end
	end
	f.close
end

for file in file_array do
	puts "#{file}"
	ahea_array = Array.new
	f = File.open("#{file}.ahea")
	while !f.eof do
		l = f.gets.chomp
		if l == "#{ARGV[1]}"
			ahea_array.push("#{ARGV[2]}")	
		else
  		    ahea_array.push(l)
		end
	end
	f.close

	f = File.open("#{file}.ahea", 'w')
	for ahea in ahea_array do
		f.puts(ahea)
	end
	f.close
end
