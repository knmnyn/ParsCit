package Omni::Omnidoc;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omnipage;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;
my $obj_list = $Omni::Config::obj_list;

# Temporary variables
my $tmp_content 	= undef;
my @tmp_pages		= ();

###
# A whole document object in Omnipage xml: a document contains many pages 
#
# Do Hoang Nhat Huy, 09 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Lines: a paragraph can have multiple lines
	my @pages	= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNIDOC' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_pages'		=> \@pages	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <para> ... </para>
	$self->{ '_raw' }	= $raw;

	# At first, content is blank
	$tmp_content 		= "";
	# because there's no document
	@tmp_pages			= ();

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'DOCUMENT' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'DOCUMENT' }	=> \&parse};

	# XML::Twig 
	my $twig = new XML::Twig(	twig_roots 		=> $twig_roots,
						 	 	twig_handlers	=> $twig_handlers,
						 	 	pretty_print 	=> 'indented'	);

	# Start the XML parsing
	$twig->parse($raw);
	$twig->purge;

	# Copy information from temporary variables to class members

	# Copy all pages
	@{$self->{ '_pages' } }	= @tmp_pages;
	
	# Copy content
	$self->{ '_content' }	= $tmp_content;
}

sub get_raw
{
	my ($self) = @_;
	return $self->{ '_raw' };
}

sub parse
{
	my ($twig, $node) = @_;

	# Get <document> node attributes

	# Check if there's any para
	my @all_pages = $node->descendants( $tag_list->{ 'PAGE' } );
	foreach my $pg (@all_pages)
	{
		my $page = new Omni::Omnipage();

		# Set raw content
		$page->set_raw($pg->sprint());

		# Update page list
		push @tmp_pages, $page;

		# Update content
		$tmp_content = $tmp_content . $page->get_content() . "\n";
	}
}

sub get_name
{
	my ($self) = @_;
	return $self->{ '_self' };
}

sub get_objs_ref
{
	my ($self) = @_;
	return $self->{ '_pages' };
}

sub get_content
{
	my ($self) = @_;
	return $self->{ '_content' };
}

# Support functions
sub GetNodeAttr 
{
	my ($node, $attr) = @_;
	return ($node->att($attr) ? $node->att($attr) : "");
}

sub SetNodeAttr 
{
	my ($node, $attr, $value) = @_;
	$node->set_att($attr, $value);
}

sub GetNodeText
{
	my ($node) = @_;
	return $node->text;
}

sub SetNodeText
{
	my ($node, $value) = @_;
	$node->set_text($value);
}

1;
