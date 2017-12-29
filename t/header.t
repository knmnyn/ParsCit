#!/usr/bin/env perl

use Test::Most tests => 1;

use Capture::Tiny qw(capture_stdout);
use XML::Twig;

use lib 't/lib';

subtest "Sample text 1" => sub {
	my $data = [
		{
			xpath => '//title',
			text => 'A Calculus of Program Transformations and Its Applications',
		},
		{
			xpath => '//author',
			text => 'Rahma Ben Ayed',
		},
		{
			xpath => '//affiliation',
			text => 'School of Engineering University of Tunis II',
		},
	];

	plan tests => 0+@$data;

	my ($stdout, $exit) = capture_stdout {
		system($^X, qw(bin/citeExtract.pl -m extract_header demodata/sample1.txt));
	};

	my $twig = XML::Twig->new();
	$twig->parse( $stdout );
	my $retrieve_text = sub {
		my ($xpath) = @_;
		[ $twig->root->findnodes($xpath) ]->[0]->xml_text
	};

	for my $test_data (@$data) {
		is(
			$retrieve_text->($test_data->{xpath}),
			$test_data->{text},
			"Testing $test_data->{xpath} is «$test_data->{text}»",
		);
	}

};

done_testing;
