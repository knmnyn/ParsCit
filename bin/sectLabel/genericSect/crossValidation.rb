#!/usr/bin/env ruby
require 'find'

pwd = File.dirname(__FILE__)

@CRFPP  = ENV['CRFPP_HOME'] ? "#{ENV['CRFPP_HOME']}/bin" : "#{pwd}/../../../crfpp"
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

### v100401 ###
#processed 2366 tokens with 2366 phrases; found: 2366 phrases; correct: 2259.
#accuracy:  95.48%; precision:  95.48%; recall:  95.48%; FB1:  95.48
#         abstract: precision: 100.00%; recall: 100.00%; FB1: 100.00  210
#  acknowledgments: precision:  98.08%; recall: 100.00%; FB1:  99.03  104
#       background: precision:  91.67%; recall:  39.29%; FB1:  55.00  12
#categories-and-subject-descriptors: precision: 100.00%; recall: 100.00%; FB1: 100.00  165
#      conclusions: precision:  94.82%; recall:  96.83%; FB1:  95.81  193
#      discussions: precision:  80.95%; recall:  47.22%; FB1:  59.65  21
#       evaluation: precision:  93.16%; recall:  72.19%; FB1:  81.34  117
#    general-terms: precision: 100.00%; recall: 100.00%; FB1: 100.00  142
#     introduction: precision:  99.05%; recall:  99.52%; FB1:  99.29  211
#         keywords: precision:  99.52%; recall: 100.00%; FB1:  99.76  210
#           method: precision:  88.33%; recall:  98.36%; FB1:  93.07  677
#       references: precision: 100.00%; recall: 100.00%; FB1: 100.00  211
#    related-works: precision: 100.00%; recall:  88.57%; FB1:  93.94  93
