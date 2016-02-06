# ParsCit
#
# VERSION 1.0
FROM 32bit/debian:jessie
MAINTAINER Min-Yen Kan <knmnyn@hotmail.com>

RUN apt-get update
RUN apt-get install -y g++ make libexpat1-dev perl ruby

RUN cpan install XML::Twig
RUN cpan install XML::Writer
RUN cpan install XML::Writer::String

ADD . /ParsCit
WORKDIR /ParsCit/crfpp
RUN tar -xvzf crf++-0.51.tar.gz
WORKDIR /ParsCit/crfpp/CRF++-0.51
RUN ./configure
RUN perl -pi -e 's/#include <cmath>/#include <cmath>\n#include <iostream>/g' node.cpp
RUN make
RUN make install

RUN cp crf_learn crf_test ..
WORKDIR /ParsCit/crfpp/CRF++-0.51/.libs
RUN cp -Rf * ../../.libs

WORKDIR /ParsCit/bin
