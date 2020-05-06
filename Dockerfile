FROM debian:buster-slim

RUN apt-get update \
 && apt-get install -y g++ make libexpat1-dev perl ruby wget

RUN cpan install Class::Struct \
 && cpan install Getopt::Long \
 && cpan install Getopt::Std \
 && cpan install File::Basename \
 && cpan install File::Spec \
 && cpan install FindBin \
 && cpan install HTML::Entities \
 && cpan install IO::File \
 && cpan install POSIX \
 && cpan install XML::Parser \
 && cpan install XML::Twig \
 && cpan install XML::Writer \
 && cpan install XML::Writer::String

ADD . /ParsCit
WORKDIR /ParsCit/crfpp
RUN wget -O crf++-0.58.tar.gz 'https://drive.google.com/u/0/uc?id=0B4y35FiV1wh7QVR6VXJ5dWExSTQ&export=download' \
    && tar -xvzf crf++-0.58.tar.gz \
    && cd CRF++-0.58 \
    && ./configure \
    && make \
    && make install \
    && cp crf_learn crf_test .. \
    && cd .libs \
    && cp -Rf * ../../.libs
WORKDIR /ParsCit/bin
