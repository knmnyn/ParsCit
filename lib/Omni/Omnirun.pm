package Omni::Omnirun;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omniword;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;

# Temporary variables
my $tmp_content 	= undef;
my $tmp_font_face	= undef;
my $tmp_font_family	= undef;
my $tmp_font_pitch	= undef;
my $tmp_font_size	= undef;
my $tmp_spacing		= undef;
my $tmp_su_script	= undef;	# sub-script or super-script
my $tmp_underline	= undef;
my $tmp_bold		= undef;
my $tmp_italic		= undef;
my @tmp_words		= ();

###
# A run object in Omnipage xml: a run contains zero or many words
#
# Do Hoang Nhat Huy, 07 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Words: a run can have multiple words
	my @words	= ();

	# Class members
	my $self = {	'_raw'			=> undef,
					'_content'		=> undef,
					'_font_face'	=> undef,
					'_font_family'	=> undef,
					'_font_pitch'	=> undef,
					'_font_size'	=> undef,
					'_spacing'		=> undef,
					'_su_script'	=> undef,	# sub-script or super-script
					'_underline'	=> undef,
					'_bold'			=> undef,
					'_italic'		=> undef,
					'_words'		=> \@words	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <run> ... </run>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'RUN' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'RUN' }	=> \&parse};

	# XML::Twig 
	my $twig= new XML::Twig( twig_roots 	=> $twig_roots,
						 	 twig_handlers	=> $twig_handlers,
						 	 pretty_print 	=> 'indented' );

	# Start the XML parsing
	$twig->parse($raw);
	$twig->purge;

	# Copy information from temporary variables to class members
	$self->{ '_font_face' }		= $tmp_font_face;
	$self->{ '_font_family' }	= $tmp_font_family;
	$self->{ '_font_pitch' }	= $tmp_font_pitch;
	$self->{ '_font_size' } 	= $tmp_font_size;
	$self->{ '_spacing' }		= $tmp_spacing;
	$self->{ '_su_script' }		= $tmp_su_script;
	$self->{ '_underline' }		= $tmp_underline;
	$self->{ '_bold' }			= $tmp_bold;
	$self->{ '_italic' }		= $tmp_italic;
	
	# Copy all words
	@{ $self->{ '_words' } }	= @tmp_words;

	# Copy content
	$self->{ '_content' }		= $tmp_content;
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
	$tmp_font_face		= GetNodeAttr($node, $att_list->{ 'FONTFACE' });
	$tmp_font_family	= GetNodeAttr($node, $att_list->{ 'FONTFAMILY' });
	$tmp_font_pitch		= GetNodeAttr($node, $att_list->{ 'FONTPITCH' });
	$tmp_font_size		= GetNodeAttr($node, $att_list->{ 'FONTSIZE' });
	$tmp_spacing		= GetNodeAttr($node, $att_list->{ 'SPACING' });
	$tmp_su_script		= GetNodeAttr($node, $att_list->{ 'SUSCRIPT' });	# sub-script or super-script
	$tmp_underline		= GetNodeAttr($node, $att_list->{ 'UNDERLINE' });
	$tmp_bold			= GetNodeAttr($node, $att_list->{ 'BOLD' });
	$tmp_italic			= GetNodeAttr($node, $att_list->{ 'ITALIC' });

	# At first, content is blank
	$tmp_content 		= "";
	# because there's no word
	@tmp_words			= ();

	# Check if there's any child
	my $child = $node->first_child();

	# Has some child
	if ((defined $child) && ($child->path() =~ m/#PCDATA$/))
	{
		my $content = undef;
		$content	= GetNodeText($node);
		$content	=~ s/^\s+|\s+$//g;

		# Save the content
		$tmp_content = $tmp_content . $content;
	}
	else
	{
		# Get every word in the <run>
		my $wd = $node->first_child( $tag_list->{ 'WORD' }) ;
		while (defined $wd)
		{
			my $word = new Omni::Omniword();

			# Set raw content
			$word->set_raw($wd->sprint);

			# Update word list
			push @tmp_words, $word;

			# Check separator
			my $sep = $wd->next_sibling();

			# No space, tab, nothing 
			if (! defined $sep)
			{
				$tmp_content = $tmp_content . $word->get_content;
			}
			else
			{
				my $sep_content	= $sep->sprint;
	
				# Some type of separator
				my $space	= $tag_list->{ 'SPACE' };
				my $tab		= $tag_list->{ 'TAB' };
				my $newline	= $tag_list->{ 'NEWLINE' };

				# Space
				if ($sep_content =~ m/<($space)/)
				{
					$tmp_content = $tmp_content . $word->get_content . " ";	
				}
				# Tab
				elsif ($sep_content =~ m/<($tab)/)
				{
					$tmp_content = $tmp_content . $word->get_content . "\t";	
				}
				# Newline
				elsif ($sep_content =~ m/<($newline)/)
				{
					$tmp_content = $tmp_content . $word->get_content . "\n";
				}
				# Strange separator
				else
				{
					$tmp_content = $tmp_content . $word->get_content;					
				}
			}

			# Little brother
			if ($wd->is_last_child) 
			{ 
				last; 
			}
			else
			{
				$wd = $wd->next_sibling( $tag_list->{ 'WORD' } );
			}
		}
	}
}

sub add_word
{
	my ($self, $word) = @_;
	push @{ $self->{ '_words' } }, $word;
}

sub get_words_ref
{
	my ($self) = @_;
	return $self->{ '_words' };
}

sub get_content
{
	my ($self) = @_;
	return $self->{ '_content' };
}

sub get_font_face
{
	my ($self) = @_;
	return $self->{ '_font_face' };
}

sub get_font_family
{
	my ($self) = @_;
	return $self->{ '_font_family' };
}

sub get_font_pitch
{
	my ($self) = @_;
	return $self->{ '_font_pitch' };
}

sub get_font_size
{
	my ($self) = @_;
	return $self->{ '_font_size' };
}

sub get_spacing
{
	my ($self) = @_;
	return $self->{ '_spacing' };
}

sub get_suscript
{
	my ($self) = @_;
	return $self->{ '_su_script' };
}

sub get_underline
{
	my ($self) = @_;
	return $self->{ '_underline' };
}

sub get_bold
{
	my ($self) = @_;
	return $self->{ '_bold' };
}

sub get_italic
{
	my ($self) = @_;
	return $self->{ '_italic' };
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
