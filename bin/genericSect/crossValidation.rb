#!/usr/bin/env ruby
require 'find'
@CRFPP = "/home/nguyentd/sectionHeader/crfpp"
@RESOURCES = "/home/nguyentd/sectionHeader/crf_resources"
@DATA = "/home/nguyentd/sectionHeader/data"

dirPath  = ARGV[0]
numFold  = ARGV[1].to_i
files    = Array.new

#remove files from destPath
cmd = "rm -rf #{@DATA}/*"
system(cmd)

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

index = 0
numFiles = files.length/numFold
while index < numFold do
	cmd = "mkdir #{@DATA}/train_#{index}"
	system(cmd)
	cmd = "mkdir #{@DATA}/test_#{index}"
	system(cmd)
	startIndex = index*numFiles
	endIndex   = startIndex + numFiles - 1
	if index == (numFold - 1)
		endIndex = files.length - 1
	end
	
	#copy files to coressponding folder
	i = 0
	while i < files.length do
		if startIndex <= i and i <= endIndex
			cmd = "cp #{files.at(i)}.* #{@DATA}/test_#{index}/"
			system(cmd)
		else
			cmd = "cp #{files.at(i)}.* #{@DATA}/train_#{index}/"
			system(cmd)
		end
		i = i + 1
	end

	#create train and test file
	cmd = "ruby createFeature.rb #{@DATA}/train_#{index}/ > #{@DATA}/#{index}.train"
	system(cmd)
	cmd = "ruby createFeature.rb #{@DATA}/test_#{index}/ > #{@DATA}/#{index}.test"
	system(cmd)

	#run crf

	cmd = "#{@CRFPP}/crf_learn #{@RESOURCES}/sectionHeader.template #{@DATA}/#{index}.train #{@DATA}/#{index}.model"
	system(cmd)

	cmd = "#{@CRFPP}/crf_test  -m #{@DATA}/#{index}.model #{@DATA}/#{index}.test > #{@DATA}/#{index}.out"
	system(cmd)

	cmd = "cat #{@DATA}/#{index}.out >> #{@DATA}/#{numFold}_result.txt"
	system(cmd)


	index = index + 1
end

#run evaluation 
#puts "Evaluating ..."
#cmd = "#{@CONLLEVAL} -r -c -d \"  \" < #{@DATA}/#{numFold}_result.txt 1>evaluation 2>evaluation"
#system(cmd)
