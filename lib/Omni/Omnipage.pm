package Omni::Omnipage;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omnidd;
use Omni::Omnicol;
use Omni::Omniframe;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;
my $obj_list = $Omni::Config::obj_list;

# Temporary variables
my $tmp_content 	= undef;
my @tmp_objs		= ();

###
# A page object in Omnipage xml: a page contains zero or many collums
#
# Do Hoang Nhat Huy, 09 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Page: a page can have many columns, many tables, or many images
	my @objs	= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNIPAGE' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_objs'			=> \@objs	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <page> ... </page>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'PAGE' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'PAGE' }	=> \&parse};

	# XML::Twig 
	my $twig = new XML::Twig(	twig_roots 		=> $twig_roots,
						 	 	twig_handlers	=> $twig_handlers,
						 	 	pretty_print 	=> 'indented'	);

	# Start the XML parsing
	$twig->parse($raw);
	$twig->purge;

	# Copy information from temporary variables to class members

	# Copy all columns 
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
	$tmp_content	= "";
	# because there's no columnm, table or image
	@tmp_objs		= ();

	# Get <page> node attributes
	# At version 16, Omnipage page does not have any interesting atribute

	my $child = undef;
	# Get the body text
	$child = $node->first_child( $tag_list->{ 'BODY' } );
	# Page with no body, return
	if (! defined $child) { return; }

	# Get the first child in the body text
	$child = $child->first_child();

	# The child of <page> is usually <section> but it's not always the case
	my $section_tag	= $tag_list->{ 'SECTION' };

	# <dd>, <col> are usually not the children but the
	# desendents of <page> but I'm not sure about this
	my $dd_tag		= $tag_list->{ 'DD' };
	my $column_tag	= $tag_list->{ 'COL' };
	my $frame_tag	= $tag_list->{ 'FRAME' };

	# Check if there's any column or dd, what the heck is dd 
	while (defined $child)
	{
		my $xpath = $child->path();

		# if this child is <section>, then <column> and <dd> tag are grandchild of <page>
		if ($xpath =~ m/\/$section_tag$/)
		{
			# Get the first grand child
			my $grand_child = $child->first_child();

			# Subloop
			while (defined $grand_child)
			{
				my $grand_xpath = $grand_child->path();

				# if this child is <column>
				if ($grand_xpath =~ m/\/$column_tag$/)
				{
					my $column = new Omni::Omnicol();
	
					# Set raw content
					$column->set_raw($grand_child->sprint());

					# Update column list
					push @tmp_objs, $column;

					# Update content
					$tmp_content = $tmp_content . $column->get_content() . "\n";
				}
				# if this child is <dd>
				elsif ($grand_xpath =~ m/\/$dd_tag$/)
				{
					my $dd = new Omni::Omnidd();

					# Set raw content
					$dd->set_raw($child->sprint());

					# Update column list
					push @tmp_objs, $dd;

					# Update content
					$tmp_content = $tmp_content . $dd->get_content() . "\n";
				}
				# if this child is <frame>
				elsif ($xpath =~ m/\/$frame_tag$/)
				{
					my $frame = new Omni::Omniframe();

					# Set raw content
					$frame->set_raw($child->sprint());

					# Update column list
					push @tmp_objs, $frame;

					# Update content
					$tmp_content = $tmp_content . $frame->get_content() . "\n";
				}

				# Little brother
				if ($grand_child->is_last_child) 
				{ 
					last; 
				}
				else
				{
					$grand_child = $grand_child->next_sibling();
				}
			}
		}
		# if this child is <column>
		elsif ($xpath =~ m/\/$column_tag$/)
		{
			my $column = new Omni::Omnicol();

			# Set raw content
			$column->set_raw($child->sprint());

			# Update column list
			push @tmp_objs, $column;

			# Update content
			$tmp_content = $tmp_content . $column->get_content() . "\n";
		}
		# if this child is <dd>
		elsif ($xpath =~ m/\/$dd_tag$/)
		{
			my $dd = new Omni::Omnidd();

			# Set raw content
			$dd->set_raw($child->sprint());

			# Update column list
			push @tmp_objs, $dd;

			# Update content
			$tmp_content = $tmp_content . $dd->get_content() . "\n";
		}
		# if this child is <frame>
		elsif ($xpath =~ m/\/$frame_tag$/)
		{
			my $frame = new Omni::Omniframe();

			# Set raw content
			$frame->set_raw($child->sprint());

			# Update column list
			push @tmp_objs, $frame;

			# Update content
			$tmp_content = $tmp_content . $frame->get_content() . "\n";
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
