package Omni::Omnipara;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omniword;
use Omni::Omnirun;
use Omni::Omniline;

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
my $tmp_language	= undef;
my $tmp_alignment	= undef;
my $tmp_spaceb		= undef;
my @tmp_lines		= ();

###
# A para object in Omnipage xml: a paragraph contains zero or many lines
#
# Do Hoang Nhat Huy, 09 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Lines: a paragraph can have multiple lines
	my @lines	= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNIPARA' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_bottom'		=> undef,
					'_top'			=> undef,
					'_left'			=> undef,
					'_right'		=> undef,
					'_language'		=> undef,
					'_alignment'	=> undef,
					'_spaceb'		=> undef,
					'_lines'		=> \@lines	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <para> ... </para>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'PARA' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'PARA' }	=> \&parse};

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
	$self->{ '_language' } 	= $tmp_language;
	$self->{ '_alignment' }	= $tmp_alignment;
	$self->{ '_spaceb' }	= $tmp_spaceb;

	# Copy all lines
	@{$self->{ '_lines' } }	= @tmp_lines;
	
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
	$tmp_content 		= "";
	# because there's no line
	@tmp_lines			= ();

	# Get <para> node attributes
	$tmp_bottom		= GetNodeAttr($node, $att_list->{ 'BOTTOM' });
	$tmp_top		= GetNodeAttr($node, $att_list->{ 'TOP' });
	$tmp_left		= GetNodeAttr($node, $att_list->{ 'LEFT' });
	$tmp_right		= GetNodeAttr($node, $att_list->{ 'RIGHT' });
	$tmp_language	= GetNodeAttr($node, $att_list->{ 'LANGUAGE' });
	$tmp_alignment	= GetNodeAttr($node, $att_list->{ 'ALIGN' });
	$tmp_spaceb		= GetNodeAttr($node, $att_list->{ 'SPACEB' });

	# Check if there's any bullet
	my $bullet 		= $node->first_child( $tag_list->{ 'BULLET' } );
	my $has_bullet	= (defined $bullet) ? 1 : 0;

	# Check if there's any line
	my @all_lines = $node->descendants( $tag_list->{ 'LINE' } );
	foreach my $ln (@all_lines)
	{
		my $line = new Omni::Omniline();

		# Set raw content
		$line->set_raw($ln->sprint());

		# Set bullet if needed
		if ($has_bullet == 1) { $line->set_bullet('true'); }

		# Update line list
		push @tmp_lines, $line;

		# Update content
		$tmp_content = $tmp_content . $line->get_content() . "\n";
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
	return $self->{ '_lines' };
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

sub get_language
{
	my ($self) = @_;
	return $self->{ '_language' };
}

sub get_alignment
{
	my ($self) = @_;
	return $self->{ '_alignment' };
}

sub get_space_before
{
	my ($self) = @_;
	return $self->{ '_spaceb' };
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
