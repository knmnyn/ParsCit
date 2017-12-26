package ParsCitMaker;
use Moose;

with 'Dist::Zilla::Role::FileMunger';

use List::Util qw( first );

sub munge_files {
	my ($self) = @_;
	my $file = first { $_->name eq 'Makefile.PL' } @{ $self->zilla->files };
	my $content = $file->content;

	$content .= <<'EOF';
# BEGIN code inserted by ParsCitMaker
{
	package MY;
	no warnings 'redefine';
	use File::ShareDir::Install;
	sub postamble {
		join "\n", $abmm->mm_postamble, File::ShareDir::Install::postamble(@_);
	}
}
# END code inserted by ParsCitMaker
EOF

	$file->content( $content );
};

__PACKAGE__->meta->make_immutable;
