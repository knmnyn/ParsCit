package Omni::Omnicol;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omniword;
use Omni::Omnirun;
use Omni::Omniline;
use Omni::Omnipara;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;

# Temporary variables
my $tmp_content 	= undef;
my $tmp_bottom		= undef;
my $tmp_top			= undef;
my $tmp_left		= undef;
my $tmp_right		= undef;
my @tmp_paras		= ();

###
# A column object in Omnipage xml: a column contains zero or many paragraphs
#
# Do Hoang Nhat Huy, 11 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Column: a page can have many paragraphs
	my @paras	= ();

	# Class members
	my $self = {	'_raw'			=> undef,
					'_content'		=> undef,
					'_bottom'		=> undef,
					'_top'			=> undef,
					'_left'			=> undef,
					'_right'		=> undef,
					'_paras'		=> \@paras	};

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
	my $twig_roots		= { $tag_list->{ 'COLUMN' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'COLUMN' }	=> \&parse};

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

	# Copy all paragraphs 
	@{$self->{ '_paras' } }	= @tmp_paras;
	
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
	# because there's no paragraph
	@tmp_paras		= ();

	# Get <column> node attributes
	$tmp_bottom		= GetNodeAttr($node, $att_list->{ 'BOTTOM' });
	$tmp_top		= GetNodeAttr($node, $att_list->{ 'TOP' });
	$tmp_left		= GetNodeAttr($node, $att_list->{ 'LEFT' });
	$tmp_right		= GetNodeAttr($node, $att_list->{ 'RIGHT' });

	# Check if there's any paragraph 
	my @all_paras = $node->descendants( $tag_list->{ 'PARA' } );
	foreach my $pr (@all_paras)
	{
		my $para = new Omni::Omnipara();

		# Set raw content
		$para->set_raw($pr->sprint());

		# Update paragraph list
		push @tmp_paras, $para;

		# Update content
		$tmp_content = $tmp_content . $para->get_content() . "\n";
	}
}

sub get_paras_ref
{
	my ($self) = @_;
	return $self->{ '_paras' };
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
