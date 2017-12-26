package ParsCit;
# ABSTRACT: An open-source CRF Reference String and Logical Document Structure Parsing Package

use strict;
use warnings;

use File::ShareDir qw(dist_dir);
use File::Spec;
use Env qw($CRFPP_HOME);

use parent qw(Alien::Base);

sub import {
	$CRFPP_HOME = ParsCit->dist_dir;

	return;
}

sub crf_test_path {
	my ($self) = @_;
	File::Spec->catfile( File::Spec->rel2abs($self->dist_dir) , 'bin', 'crf_test' );
}
sub crf_learn_path {
	my ($self) = @_;
	File::Spec->catfile( File::Spec->rel2abs($self->dist_dir) , 'bin', 'crf_learn' );
}

sub _resource_path {
	my ($class, $path) = @_;
	die unless $path =~ m,^resources/,;
	my @components = split '/', $path;
	my $final_path;

	eval {
		my $dist_dir = dist_dir('ParsCit');
		$final_path = File::Spec->catfile($dist_dir, @components);
		1;
	} || return $path;

	return $final_path;
}

1;
