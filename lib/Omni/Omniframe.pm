package Omni::Omniframe;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omnipara;
use Omni::Omnitable;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;
my $obj_list = $Omni::Config::obj_list;

###
# A frame object in Omnipage xml: a frame contains paragraphs 
# (this is my observation and can be invalid under close scrunity 
# of new "evidence")
#
# Do Hoang Nhat Huy, 23 Feb 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Objs: paragraphs 
	my @objs		= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNIFRAME' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_bottom'		=> undef,
					'_top'			=> undef,
					'_left'			=> undef,
					'_right'		=> undef,
					'_objs'			=> \@objs	};

	bless $self, $class;
	return $self;
}

sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <column> ... </column>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'FRAME' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'FRAME' }	=> sub { parse(@_, \$self); } };

	# XML::Twig 
	my $twig = new XML::Twig(	twig_roots 		=> $twig_roots,
						 	 	twig_handlers	=> $twig_handlers,
						 	 	pretty_print 	=> 'indented'	);

	# Start the XML parsing
	$twig->parse($raw, \$self);
	$twig->purge;
}

sub get_raw
{
	my ($self) = @_;
	return $self->{ '_raw' };
}

sub parse
{
	my ($twig, $node, $self) = @_;

	# At first, content is blank
	my $tmp_content	= "";
	# because there's no object
	my @tmp_objs		= ();

	# Get <column> node attributes
	my $tmp_bottom		= GetNodeAttr($node, $att_list->{ 'BOTTOM' });
	my $tmp_top			= GetNodeAttr($node, $att_list->{ 'TOP' });
	my $tmp_left		= GetNodeAttr($node, $att_list->{ 'LEFT' });
	my $tmp_right		= GetNodeAttr($node, $att_list->{ 'RIGHT' });

	# Check if there's any paragraph, dd, table, or picture 
	# The large number of possible children is due to the
	# ambiguous structure of the Omnipage XML
	my $para_tag	= $tag_list->{ 'PARA' };
	my $table_tag	= $tag_list->{ 'TABLE' };

	# Get the first child in the body text
	my $child = $node->first_child();

	while (defined $child)
	{
		my $xpath = $child->path();

		# if this child is <para>
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
		elsif ($xpath =~ m/\/$table_tag$/)
		{
			my $table = new Omni::Omnitable();
		
			# Set raw content
			$table->set_raw($child->sprint());

			# Update paragraph list
			push @tmp_objs, $table;

			# Update content
			$tmp_content = $tmp_content . $table->get_content() . "\n";
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

	# Copy information from temporary variables to class members
	$$self->{ '_bottom' }	= $tmp_bottom;
	$$self->{ '_top' }		= $tmp_top;
	$$self->{ '_left' }		= $tmp_left;
	$$self->{ '_right' } 	= $tmp_right;

	# Copy all objects 
	@{$$self->{ '_objs' } }	= @tmp_objs;
	
	# Copy content
	$$self->{ '_content' }	= $tmp_content;
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
