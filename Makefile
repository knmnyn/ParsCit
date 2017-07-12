CRFPP_SRC=crfpp-src
CRFPP_BIN=crfpp
# On windows, you need to append '.exe'
CRFPP_TEST=$(CRFPP_SRC)/crf_test
CRFPP_LEARN=$(CRFPP_SRC)/crf_learn

all: compile-crfpp install-crfpp clean-crfpp
	echo "ParsCit ready."


compile-crfpp:
	echo "Compile crfpp source".
	git submodule update --init
	sed -i '/#include "winmain.h"/d' $(CRFPP_SRC)/crf_test.cpp
	sed -i '/#include "winmain.h"/d' $(CRFPP_SRC)/crf_learn.cpp
	cd $(CRFPP_SRC) && ./configure && make

install-crfpp: compile-crfpp
	echo "Install binaries in crfpp"
	mkdir -p crfpp
	cp -f $(CRFPP_TEST) $(CRFPP_BIN)/crf_test
	cp -f $(CRFPP_LEARN) $(CRFPP_BIN)/crf_learn

clean-crfpp:
	echo "Cleaning up crfpp submodule"
	cd $(CRFPP_SRC) && make clean && git reset --hard


