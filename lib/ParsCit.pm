package ParsCit;
# ABSTRACT: An open-source CRF Reference String and Logical Document Structure Parsing Package

use strict;
use warnings;

use File::Spec;

use parent qw(Alien::Base);

sub crf_test_path {
	my ($self) = @_;
	File::Spec->catfile( File::Spec->rel2abs($self->dist_dir) , 'bin', 'crf_test' );
}
sub crf_learn_path {
	my ($self) = @_;
	File::Spec->catfile( File::Spec->rel2abs($self->dist_dir) , 'bin', 'crf_learn' );
}

1;
