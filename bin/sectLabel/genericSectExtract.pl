#!perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use File::Spec;
use String::Strip;
use File::Temp;
use IPC::Run3;
use ParsCit;

my $crf_test = ParsCit->crf_test_path;
my $data = ParsCit->_resource_path('resources/sectLabel');
my $test_dir = File::Temp->newdir;

sub main {
	my $name  = "@{[ time ]}-$$";

	my $test_file = File::Spec->catfile($test_dir, "${name}.test" );
	open( my $extract_fh, '>', $test_file );
	run3 [
		'ruby',
		File::Spec->catfile($FindBin::Bin, qw(extractFeature.rb)),
		$ARGV[0],
	], \undef, $extract_fh;
	close $extract_fh;

	my $out_file =  File::Spec->catfile($test_dir, "${name}.out" );
	open( my $out_fh, '>', $out_file );
	run3 [
		$crf_test,
		qw(-m), File::Spec->catfile($data, qw(genericSect.model)),
		$test_file,
	], \undef, $out_fh;
	close $out_fh;

	my $output_fh;
	if( $ARGV[1] ) {
		open( $output_fh, '>', $ARGV[1] );
	} else {
		$output_fh = \*STDOUT;
	}

	open( my $out_read_fh, '<', $out_file);
	while( chomp(my $str = <$out_read_fh>) ) {
		StripLTSpace($str);
		next unless $str;

		my @words = split ' ', $str;
		my $output = $words[-1];
		$output =~ s/-/ /g;

		$output = 'related work' if $output eq 'related works';

		print $output_fh "$output\n";
	}
}

main;
