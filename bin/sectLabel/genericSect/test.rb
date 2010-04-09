#!/usr/bin/env ruby
require 'find'
#Author Nguyen Thuy Dung
#Create training file from labeled data
#Run: ruby train.rb filePath
#filePath is the input file which lists all headers of a document
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
file = ARGV[0]
#for file in files do
	f = File.open("#{file}")
	hea_array = Array.new
	while !f.eof do
		hea_array.push(f.gets.chomp.strip)
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
		tmp = hea_array.at(index).split(" ")
		len = tmp.length
		if  len > 3
			len = 3
		end
		firstWord = "null"
		secondWord = "null"
		
		if /[0-9].?/.match(tmp.at(0))
			if len > 2
				firstWord = tmp.at(1).downcase
			end
			if len >=3
				secondWord = tmp.at(2).downcase
			end
		else
			if len > 1
				firstWord = tmp.at(0).downcase
			end
			if len >= 2
				secondWord = tmp.at(1).downcase
			end
		end

		puts "index=#{index} pos=#{pos}/10 firstWord=#{firstWord} secondWord=#{secondWord}  currHeader=#{currHeader} ?"
		index = index + 1
	end
