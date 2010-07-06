#!/usr/bin/env ruby
#Author Nguyen Thuy Dung
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


f = File.open("#{ARGV[0]}")
hea_array = Array.new
ahea_array = Array.new
while !f.eof do
	l = f.gets.chomp.strip
	if l != ""
		tmp_array = l.split("|||")
		if tmp_array.length == 1
			hea_array << tmp_array[0].strip			
			ahea_array << "?"
		else
			hea_array << tmp_array[1].strip			
			ahea_array << tmp_array[0].strip
		end
	else
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
		hea_array = Array.new
		ahea_array = Array.new
	end
end
f.close
if hea_array.length > 0
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
	
	firstWord = tmp.at(0).strip
	secondWord = "null"
	if /[0-9]+.?/.match(firstWord) and len > 1
		firstWord = tmp.at(1).strip
		if len > 2
			secondWord = tmp.at(2)
		end
	else
		if len > 1
			secondWord = tmp.at(1)
		end
	end
	puts "index=#{index} pos=#{pos}/10 firstWord=#{firstWord} secondWord=#{secondWord}  currHeader=#{currHeader} #{assignedHeader}"
	index = index + 1
end
puts ""
end
