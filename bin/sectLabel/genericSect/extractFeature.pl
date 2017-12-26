#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use strict;
use warnings;

use String::Strip;

# get relative pos in ingeter, values range from 0-10
sub getPos {
	my ($val) = 0;
	return 0 if $val == 0;

	my $i = 1;
	while( $i <= 10 ) {
		if( $val <= $i/10.0 ) {
			return $i;
		}
		$i++;
	}

	return -1;
}

# process generic headers: "related work" becomes "related_work"
sub getHeader {
	my ($str) = @_;
	StripLTSpace($str);
	$str =~ s/ /_/g;
	lc $str;
}

sub main {
	open my $f, '<:encoding(UTF-8)', $ARGV[0];

	my @hea_array = ();
	my @ahea_array = ();

	while( my $l = <$f> ) {
		chomp $l;
		StripLTSpace($l);

		if( $l ne '' ) {
			my @tmp_array = split /\Q|||\E/, $l;
			StripLTSpace($_) for @tmp_array;
			if( @tmp_array == 1 ) {
				push @hea_array, $tmp_array[0];
				push @ahea_array, '?';
			} else {
				push @hea_array, $tmp_array[1];
				push @ahea_array, $tmp_array[0];
			}
		} else {
			my $index = 0;
			while( $index < @hea_array ) {
				my $pos = @hea_array == 1
					? 0
					: getPos( $index * 1.0/( @hea_array - 1 ) );
				my $currHeader = getHeader( $hea_array[$index] );
				my $assignedHeader = getHeader( $ahea_array[$index] );

				my @tmp = split ' ', $hea_array[$index];
				my $len = 0+@tmp;
				$len = 3 if $len > 3;

				my $firstWord = $tmp[0];
				my $secondWord = 'null';
				if( $len >= 2 ) {
					$secondWord = $tmp[1];
				}
				print "index=${index} pos=${pos}/10 firstWord=${firstWord} secondWord=${secondWord}  currHeader=${currHeader} ${assignedHeader}\n";
				$index++;
			}
			print "\n";
			@hea_array = ();
			@ahea_array = ();
		}
	}
	close $f;

	if( @hea_array > 0 ) {
		my $index = 0;
		while( $index < @hea_array ) {
			my $pos = @hea_array == 1
				? 0
				: getPos( $index * 1.0/( @hea_array - 1 ) );
			my $currHeader = getHeader( $hea_array[$index] );
			my $assignedHeader = getHeader( $ahea_array[$index] );

			my @tmp = split ' ', $hea_array[$index];
			my $len = 0+@tmp;
			$len = 3 if $len > 3;

			my $firstWord = $tmp[0]; StripLTSpace($firstWord);
			my $secondWord = 'null';
			if( $firstWord =~ /[0-9]+.?/ && $len > 1 ) {
				$firstWord = $tmp[1]; StripLTSpace($firstWord);
				if( $len > 2 ) {
					$secondWord = $tmp[2];
				}
			} else {
				if($len > 1) {
					$secondWord = $tmp[1];
				}
			}
			print "index=${index} pos=${pos}/10 firstWord=${firstWord} secondWord=${secondWord}  currHeader=${currHeader} ${assignedHeader}\n";
			$index++;
		}
		print "\n";
	}
}

main;
