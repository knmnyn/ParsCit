package Wing::Cache;

# Configuration
use strict;

# Dependencies
use File::Copy;
use File::Path;
use Digest::SHA;

###
# Just a small tool to handle the cache of downloaded items
###
# Initialization
sub new
{
	# root	 : root directory of the cache
	# digest : hashing method, SHA1, or SHA2
	my ($class, $root) = @_;

	# Class members
	my $self = {	'_root'		=> $root,
					'_digest'	=> 'SHA1'	};

	bless $self, $class;
	return $self;
}

sub add 
{
    my ( $self, $id, $path ) = @_;
    
	# Take the first 2 bytes as directory
	my $local_subdir	= substr( $id, 0, 2 );
	my $subdir			= $self->{ _root } . "/" . $local_subdir;

	# Make the new path if needed
    if ( !( -e $subdir ) ) { mkpath($subdir) or die "Unable to create subdirectoris $subdir in the cache"; }

	# This is the name of the file which will be cached
    my $stored_file = $subdir . "/" . $id;
	# Move the file into its destination
	copy( $path, $stored_file ) or die "Unable to copy file into the cache as $stored_file";
    # Our work here is done    
	return $stored_file;
}

sub remove 
{
    my ( $self, $id ) = @_;
	# Now fuck off
    if ( !( defined($id) ) ) { return undef; }
	
	my $local_subdir	= substr( $id, 0, 2 );
	my $subdir			= $self->{ _root } . "/" . $local_subdir;
	my $stored_file		= $subdir . "/" . $id;
    
    if ( -e $stored_file ) 
	{
    	unlink($stored_file) or return undef;
    }
    else 
	{
        return;
    }
}

sub getpath 
{
    my ( $self, $id ) = @_;

	# Deride the path from the id or filename
    my $local_subdir	= substr( $id, 0, 2 );
	my $subdir			= $self->{ _root } . "/" . $local_subdir;
	my $stored_file 	= $subdir . "/" . $id;

    if ( -e $stored_file ) 
	{
		return $stored_file;
    } 
	else 
	{
		return undef;
    }
}

sub digest
{
    my ($data, $digestdef) = @_;
    
	my $sha = undef;
    if ( $digestdef eq "SHA1" ) 
	{
        $sha = Digest::SHA->new("sha1");
    }
    elsif ( $digestdef eq "SHA2" ) 
	{
        $sha = Digest::SHA->new("sha256");
    }
    else 
	{
		print STDERR "unknown digest method";
    }
    $sha->add($data);
    
	return my $digest = $sha->hexdigest;
}

1;
