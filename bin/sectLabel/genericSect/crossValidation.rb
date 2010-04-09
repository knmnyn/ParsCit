#!/usr/bin/env ruby
require 'find'

pwd = File.dirname(__FILE__)

@CRFPP  = "#{pwd}/../../../crfpp"
@RESOURCES   = "#{pwd}/../../../crfpp/traindata/"
@TEST_DIR = "#{pwd}/run"
@CONLLEVAL = "#{pwd}/../../conlleval.pl"
if ARGV.length == 2
dataFile = ARGV[0]
numFold  = ARGV[1].to_i
f = File.open("#{dataFile}")
contentArray = Array.new
while !f.eof do
	l = f.gets.chomp
	contentArray << l
end
f.close

numInstances = (contentArray.length/numFold).to_i

iFold = 1
while iFold <= numFold do
	startIndex = (iFold - 1)*numInstances
	endIndex = iFold*numInstances - 1
	if iFold == numFold
		endIndex = contentArray.length - 1
	end

	i = 0
	f = File.open("#{@TEST_DIR}/gs_train.txt","w")
	g = File.open("#{@TEST_DIR}/gs_test.txt","w")
	while i < contentArray.length do
		str = contentArray[i]
		if i >= startIndex and i <= endIndex
			g.write("#{str}\n")
		else
			f.write("#{str}\n")
		end
		i = i + 1
	end
	f.close
	g.close

	cmd = "#{pwd}/../single2multi.pl -in #{@TEST_DIR}/gs_train.txt -out #{@TEST_DIR}/gs_train_#{iFold}.txt"
	puts "#{cmd}"
	system(cmd)
	cmd = "#{pwd}/../single2multi.pl -in #{@TEST_DIR}/gs_test.txt -out #{@TEST_DIR}/gs_test_#{iFold}.txt"
	system(cmd)
	
	#create train and test file
	cmd = "ruby extractFeature.rb #{@TEST_DIR}/gs_train_#{iFold}.txt  > #{@TEST_DIR}/gs_train_#{iFold}.train "
	system(cmd)
	cmd = "ruby extractFeature.rb #{@TEST_DIR}/gs_test_#{iFold}.txt > #{@TEST_DIR}/gs_test_#{iFold}.test"
	system(cmd)

	#run crf

	cmd = "#{@CRFPP}/crf_learn #{@RESOURCES}/genericSect.template #{@TEST_DIR}/gs_train_#{iFold}.train #{@TEST_DIR}/gs_train_#{iFold}.model"
	system(cmd)

	cmd = "#{@CRFPP}/crf_test  -m #{@TEST_DIR}/gs_train_#{iFold}.model #{@TEST_DIR}/gs_test_#{iFold}.test > #{@TEST_DIR}/gs_test_#{iFold}.out"
	system(cmd)

	cmd = "cat #{@TEST_DIR}/gs_test_#{iFold}.out >> #{@TEST_DIR}/gs_#{numFold}_result.txt"
	system(cmd)

	iFold = iFold + 1
end
cmd = "#{@CONLLEVAL} -r  -d \"\t\" <  #{@TEST_DIR}/gs_#{numFold}_result.txt"
puts "#{cmd}"
system(cmd)

cmd = "rm #{@TEST_DIR}/gs_*"
system(cmd)

else
	puts "Usage ruby crossValidation.rb dataFile numFold"

end
