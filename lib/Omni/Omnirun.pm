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
my $obj_list = $Omni::Config::obj_list;

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
my $tmp_tab_flag	= undef;
my $tmp_tab			= 0;
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
	my $self = {	'_self'			=> $obj_list->{ 'OMNIRUN' },
					'_raw'			=> undef,
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
					'_fake'			=> 0,
					'_tab'			=> undef,	# the number of tab inside a run
					'_ptab'			=> undef,	# previous character is a tab, not a space
					'_ltab'			=> undef,	# last character is a tab, not a space
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

	# Previous tab
	$tmp_tab_flag = (! defined $self->{ '_ptab' }) ? 0 : $self->{ '_ptab' };

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
	$self->{ '_tab' }			= $tmp_tab;
	$self->{ '_ltab' }			= $tmp_tab_flag;
	
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

	# This flag will be turned on if the current element is a tab
	# otherwise it will be off by default
	my $tab_flag = $tmp_tab_flag;

	# Check if there's any child
	my $child = $node->first_child();

	# Has some child
	# #PCDATA$ is the returned path from XML::Twig if $child is data content
	if ((defined $child) && ($child->path() =~ m/#PCDATA$/))
	{
		my $content = undef;
		$content	= GetNodeText($node);
		$content	=~ s/^\s+|\s+$//g;

		# Save the content
		$tmp_content = $tmp_content . $content;

		# Tab flag - off
		$tab_flag = 0;
	}
	else
	{
		# Some type of separator
		my $space_tag	= $tag_list->{ 'SPACE' };
		my $tab_tag		= $tag_list->{ 'TAB' };
		my $newline_tag	= $tag_list->{ 'NEWLINE' };
		my $word_tag	= $tag_list->{ 'WORD' };

		# Get every word in the <run> together with <space> and <tab> ...
		my $obj = $node->first_child();
		while (defined $obj)
		{
			my $xpath = $obj->path();

			# if this child is <wd>
			if ($xpath =~ m/\/$word_tag$/)
			{
				my $word = new Omni::Omniword();
				
				# If the tab flag is on
				$word->set_previous_tab($tab_flag);

				# Set raw content
				$word->set_raw($obj->sprint);

				# Update word list
				push @tmp_words, $word;

				# Update content
				$tmp_content = $tmp_content . $word->get_content;

				# Tab flag - off
				$tab_flag = 0;
			}
			# if this child is <space>
			elsif ($xpath =~ m/\/$space_tag$/)
			{
				$tmp_content = $tmp_content . " ";	
			}
			# if this child is <tab>
			elsif ($xpath =~ m/\/$tab_tag$/)
			{
				$tmp_content = $tmp_content . "\t";	

				# Update the total number of tab
				$tmp_tab = $tmp_tab + 1;

				# Tab flag - on
				$tab_flag = 1;
			}

			# Little brother
			if ($obj->is_last_child) 
			{ 
				last; 
			}
			else
			{
				$obj = $obj->next_sibling();
			}
		}
	}

	# Save the tab flag
	$tmp_tab_flag = $tab_flag;
}

sub set_fake {
	my ($self, $fake) = @_;
	$self->{ '_fake' } = $fake;
}

sub is_fake {
	my ($self) = @_;
	return $self->{ '_fake' };
}

sub add_word
{
	my ($self, $word) = @_;
	push @{ $self->{ '_words' } }, $word;
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

sub is_last_tab
{
	my ($self) = @_;
	return $self->{ '_ltab' };
}

sub get_tab
{
	my ($self) = @_;
	return $self->{ '_tab' };
}

sub set_tab
{
	my ($self, $tab) = @_;
	$self->{ '_tab' } = $tab;
}

sub get_objs_ref
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
