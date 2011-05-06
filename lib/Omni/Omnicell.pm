package Omni::Omnicell;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omnipara;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;
my $obj_list = $Omni::Config::obj_list;

# Temporary variables
my $tmp_content 		= undef;
my $tmp_alignment		= undef;
my $tmp_grid_col_from	= undef;
my $tmp_grid_col_to		= undef;
my $tmp_grid_row_from	= undef;
my $tmp_grid_row_to		= undef;
my $tmp_vertical_align	= undef;

# My observation is that <table> contains <gridTable> and <cell>
# <gridTable> contain the base grid's coordinates
# <cell> contain the cell's position based on <gridTable> coordinates
# and various types of objects: <picture>, <para>, may be even <dd> but
# I'm not quite sure about this
my @tmp_objs	= ();

###
# A cell object in Omnipage xml: a cell is an essential member of <table> object 
#
# Do Hoang Nhat Huy, 14 Feb 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Objs: a paragraph can have many cells
	my @objs	= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNICELL' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_alignment'	=> undef,
					'_row_from'		=> undef,
					'_row_to'		=> undef,
					'_col_from'		=> undef,
					'_col_to'		=> undef,
					'_v_alignment'	=> undef,
					'_objs'			=> \@objs	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <cell> ... </cell>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'CELL' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'CELL' }	=> \&parse};

	# XML::Twig 
	my $twig = new XML::Twig(	twig_roots 		=> $twig_roots,
						 	 	twig_handlers	=> $twig_handlers,
						 	 	pretty_print 	=> 'indented'	);

	# Start the XML parsing
	$twig->parse($raw);
	$twig->purge;

	# Copy information from temporary variables to class members
	$self->{ '_alignment' }		= $tmp_alignment;
	$self->{ '_row_from' }		= $tmp_grid_row_from;
	$self->{ '_row_to' }		= $tmp_grid_row_to;
	$self->{ '_col_from' }		= $tmp_grid_col_from;
	$self->{ '_col_to' }		= $tmp_grid_col_to;
	$self->{ '_v_alignment' }	= $tmp_vertical_align;

	# Copy all objects 
	@{$self->{ '_objs' } }	= @tmp_objs;
	
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

	# At first, content is blank
	$tmp_content 	= "";
	# because there's no line
	@tmp_objs		= ();

	# Get <cell> node attributes
	$tmp_alignment		= GetNodeAttr($node, $att_list->{ 'ALIGN' });

	$tmp_grid_row_from	= GetNodeAttr($node, $att_list->{ 'GROWFROM' });
	$tmp_grid_row_to	= GetNodeAttr($node, $att_list->{ 'GROWTO' });
	$tmp_grid_col_from	= GetNodeAttr($node, $att_list->{ 'GCOLFROM' });
	$tmp_grid_col_to	= GetNodeAttr($node, $att_list->{ 'GCOLTO' });
	
	# TODO: don't understand, attribute with value = 0 will be returned as undef by twig
	$tmp_grid_row_from	= ($tmp_grid_row_from ne "")	? $tmp_grid_row_from	: 0;
	$tmp_grid_row_to	= ($tmp_grid_row_to ne "")		? $tmp_grid_row_to		: 0;
	$tmp_grid_col_from	= ($tmp_grid_col_from ne "")	? $tmp_grid_col_from 	: 0;
	$tmp_grid_col_to	= ($tmp_grid_col_to ne "")		? $tmp_grid_col_to 		: 0;

	$tmp_vertical_align	= GetNodeAttr($node, $att_list->{ 'VALIGN' });

	# Check if there's any object: <para> and <picture object: <para> and <picture>
	my $img_tag		= $tag_list->{ 'PICTURE' };
	my $para_tag	= $tag_list->{ 'PARA' };

	my $child = undef;
	# Get the first child in the body text
	$child = $node->first_child();

	while (defined $child)
	{
		my $xpath = $child->path();

		# if this child is a <para> tag
		if ($xpath =~ m/\/$para_tag$/)
		{
			my $para = new Omni::Omnipara();

			# Set raw content
			$para->set_raw($child->sprint());

			# Update paragraph list
			push @tmp_objs, $para;

			# Update content
			$tmp_content = $tmp_content . $para->get_content() . "\n";
		}
		# if this child is a <picture> tag
		elsif ($xpath =~ m/\/$img_tag$/)		
		{
			#my $img = new Omni::Omniimg();

			# Set raw content
			#$img->set_raw($child->sprint());

			# Update paragraph list
			#push @tmp_objs, $img;

			# Update content
			#$tmp_content = $tmp_content . $img->get_content() . "\n";
		}

		# Little brother
		if ($child->is_last_child) 
		{ 
			last; 
		}
		else
		{
			$child = $child->next_sibling();
		}
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
	return $self->{ '_objs' };
}

sub get_content
{
	my ($self) = @_;
	return $self->{ '_content' };
}

sub get_alignment
{
	my ($self) = @_;
	return $self->{ '_alignment' };
}

sub get_grid_row_from
{
	my ($self) = @_;
	return $self->{ '_row_from' };
}

sub get_grid_row_to
{
	my ($self) = @_;
	return $self->{ '_row_to' };
}

sub get_grid_col_from
{
	my ($self) = @_;
	return $self->{ '_col_from' };
}

sub get_grid_col_to
{
	my ($self) = @_;
	return $self->{ '_col_to' };
}

sub get_vertical_alignment
{
	my ($self) = @_;
	return $self->{ '_v_alignment' };
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
