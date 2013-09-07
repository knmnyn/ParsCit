package Omni::Omniword;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omnirun;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;
my $obj_list = $Omni::Config::obj_list;

# Temporary variables
my $tmp_content 	= undef;
my $tmp_bottom		= undef;
my $tmp_top			= undef;
my $tmp_left		= undef;
my $tmp_right		= undef;

###
# A word object in Omnipage xml: basic blocks of the xml
#
# Do Hoang Nhat Huy, 07 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNIWORD' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_ptab'			=> undef,	# previous character is a tab, not a space
					'_bottom'		=> undef,
					'_top'			=> undef,
					'_left'			=> undef,
					'_right'		=> undef	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <wd> ... </wd>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'WORD' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'WORD' }	=> \&parse};

	# XML::Twig 
	my $twig = new XML::Twig(	twig_roots 		=> $twig_roots,
						 	 	twig_handlers	=> $twig_handlers,
						 	 	pretty_print 	=> 'indented'	);

	# Start the XML parsing
	$twig->parse($raw);
	$twig->purge;

	# Copy information from temporary variables to class members
	$self->{ '_bottom' }	= $tmp_bottom;
	$self->{ '_top' }		= $tmp_top;
	$self->{ '_left' }		= $tmp_left;
	$self->{ '_right' } 	= $tmp_right;
	
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

	# Get <run> node attributes
	$tmp_bottom		= GetNodeAttr($node, $att_list->{ 'BOTTOM' });
	$tmp_top		= GetNodeAttr($node, $att_list->{ 'TOP' });
	$tmp_left		= GetNodeAttr($node, $att_list->{ 'LEFT' });
	$tmp_right		= GetNodeAttr($node, $att_list->{ 'RIGHT' });
	
	# Get the word's content
	$tmp_content 	= GetNodeText($node);
	$tmp_content	=~ s/^\s+|\s+$//g;
}

sub get_name
{
	my ($self) = @_;
	return $self->{ '_self' };
}

sub set_previous_tab
{
	my ($self, $ptab) = @_;
	$self->{ '_ptab' } = $ptab;
}

sub is_previous_tab
{
	my ($self) = @_;
	return $self->{ '_ptab' };
}

sub get_content
{
	my ($self) = @_;
	return $self->{ '_content' };
}

sub get_bottom_pos
{
	my ($self) = @_;
	return $self->{ '_bottom' };
}

sub get_top_pos
{
	my ($self) = @_;
	return $self->{ '_top' };
}

sub get_left_pos
{
	my ($self) = @_;
	return $self->{ '_left' };
}

sub get_right_pos
{
	my ($self) = @_;
	return $self->{ '_right' };
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
