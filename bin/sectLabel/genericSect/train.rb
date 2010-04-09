#!/usr/bin/env ruby
#Author Nguyen Thuy Dung
#Create training file from labeled data
#Run: ruby train.rb dirPath
#dirPath contains .hea and .ahea file
#Each .hea file lists headers of document, .ahea lists the corressponding manual assigned headers
require 'find'
#get relative pos in ingeter, values range from 0-10
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

#process generic headers: "related work" becomes "related_work"
def getHeader(str)
	str = str.strip
	while str.index(" ") != nil do
		str = str.sub(" ", "_")
	end
	return str.downcase
end

dirPath   = ARGV[0]
files	  = Array.new
#get stem in input folder
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

for file in files do
	f = File.open("#{file}.hea")
	hea_array = Array.new
	while !f.eof do
		hea_array.push(f.gets.chomp.strip)
	end
	f.close

	f = File.open("#{file}.ahea")
	ahea_array = Array.new
	while !f.eof do
		ahea_array.push(f.gets.chomp.strip)
	end
	f.close
	
	#process feature for each file
	index = 0
	while index < hea_array.length do
		if hea_array.length == 1
			pos = 0
		else
			pos = getPos(index*1.0/(hea_array.length - 1))	
		end
		currHeader = getHeader(hea_array.at(index))
		assignedHeader = getHeader(ahea_array.at(index))
		tmp = hea_array.at(index).split(" ")
		len = tmp.length
		if  len > 3
			len = 3
		end
		firstWord = tmp.at(0)
		secondWord = "null"
		if len >= 2
			secondWord = tmp.at(1)
		end
		puts "index=#{index} pos=#{pos}/10 firstWord=#{firstWord} secondWord=#{secondWord}  currHeader=#{currHeader} #{assignedHeader}"
		index = index + 1
	end
	puts ""
end
