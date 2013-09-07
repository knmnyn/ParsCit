package Omni::Omniline;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omniword;
use Omni::Omnirun;

# Extern libraries
use XML::Twig;
use XML::Parser;
use XML::Writer;
use XML::Writer::String;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;
my $obj_list = $Omni::Config::obj_list;

# Temporary variables
my $tmp_content 	= undef;
my $tmp_baseline	= undef;
my $tmp_bottom		= undef;
my $tmp_top			= undef;
my $tmp_left		= undef;
my $tmp_right		= undef;
my $tmp_tab			= 0;
my @tmp_objs		= ();

###
# A line object in Omnipage xml: a line can contain one or many runs
#
# Do Hoang Nhat Huy, 09 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# A line can have multiple runs or words
	my @objs	= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNILINE' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_baseline'		=> undef,					
					'_bottom'		=> undef,
					'_top'			=> undef,
					'_left'			=> undef,
					'_right'		=> undef,
					'_bullet'		=> undef,
					'_tab'			=> undef,
					'_objs'			=> \@objs	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;
	
	# Save the raw xml <ln> ... </ln>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'LINE' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'LINE' }	=> \&parse};

	# XML::Twig 
	my $twig = new XML::Twig(	twig_roots 		=> $twig_roots,
						 	 	twig_handlers	=> $twig_handlers,
						 	 	pretty_print 	=> 'indented'	);

	# Start the XML parsing
	$twig->parse($raw);
	$twig->purge;

	# Copy information from temporary variables to class members
	$self->{ '_baseline' }	= $tmp_baseline;
	$self->{ '_bottom' }	= $tmp_bottom;
	$self->{ '_top' }		= $tmp_top;
	$self->{ '_left' }		= $tmp_left;
	$self->{ '_right' } 	= $tmp_right;
	$self->{ '_tab' }		= $tmp_tab;
	
	# Copy all objects
	@{ $self->{ '_objs' } }	= @tmp_objs;

	# Copy content
	$self->{ '_content' } 	= $tmp_content;
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
	# because there's no run
	@tmp_objs		= ();

	# Get <line> node attributes
	$tmp_bottom		= GetNodeAttr($node, $att_list->{ 'BOTTOM' });
	$tmp_top		= GetNodeAttr($node, $att_list->{ 'TOP' });
	$tmp_left		= GetNodeAttr($node, $att_list->{ 'LEFT' });
	$tmp_right		= GetNodeAttr($node, $att_list->{ 'RIGHT' });
	$tmp_baseline	= GetNodeAttr($node, $att_list->{ 'BASELINE' });
	
	# Get <line> node possible attributes
	my $tmp_font_face	= GetNodeAttr($node, $att_list->{ 'FONTFACE' });
	my $tmp_font_family	= GetNodeAttr($node, $att_list->{ 'FONTFAMILY' });
	my $tmp_font_pitch	= GetNodeAttr($node, $att_list->{ 'FONTPITCH' });
	my $tmp_font_size	= GetNodeAttr($node, $att_list->{ 'FONTSIZE' });
	my $tmp_spacing		= GetNodeAttr($node, $att_list->{ 'SPACING' });
	my $tmp_su_script	= GetNodeAttr($node, $att_list->{ 'SUSCRIPT' });	# sub-script or super-script
	my $tmp_underline	= GetNodeAttr($node, $att_list->{ 'UNDERLINE' });
	my $tmp_bold		= GetNodeAttr($node, $att_list->{ 'BOLD' });
	my $tmp_italic		= GetNodeAttr($node, $att_list->{ 'ITALIC' });

	# This flag will be turned on if the current element is a tab
	# otherwise it will be off by default
	my $tab_flag = 0;

	# Fake run index
	my $index = 1;

	# Check if there's any run
	my @all_runs = $node->descendants( $tag_list->{ 'RUN' });
	# There is not
	if (scalar(@all_runs) == 0)
	{
		my $output = XML::Writer::String->new();
		my $writer = new XML::Writer(OUTPUT => $output, UNSAFE => 'true');

		# Form the fake <run>
		$writer->startTag(	"run", 
							$att_list->{ 'FONTFACE' } 	=> $tmp_font_face,
							$att_list->{ 'FONTFAMILY' }	=> $tmp_font_family,
							$att_list->{ 'FONTPITCH' } 	=> $tmp_font_pitch,
							$att_list->{ 'FONTSIZE' } 	=> $tmp_font_size,
							$att_list->{ 'SPACING' } 	=> $tmp_spacing,
							$att_list->{ 'SUSCRIPT' } 	=> $tmp_su_script,
							$att_list->{ 'UNDERLINE' } 	=> $tmp_underline,
							$att_list->{ 'BOLD' }		=> $tmp_bold,
							$att_list->{ 'ITALIC' }		=> $tmp_italic	);

		# Get the inner line content
		$writer->raw( $node->xml_string() );
		$writer->endTag("run");
		$writer->end();

		# Fake run
		my $run = new Omni::Omnirun();

		# If the tab flag is on
		$run->set_previous_tab($tab_flag);
		
		# Set raw content
		$run->set_raw($output->value());

		# Update run list
		push @tmp_objs, $run;

		# Update content
		$tmp_content = $tmp_content . $run->get_content();

		# Tab flag - off
		$tab_flag = 0;
	}
	else
	{
		# Get the first child in the line
		my $child = $node->first_child();

		# Some type of child
		my $space_tag	= $tag_list->{ 'SPACE' };
		my $tab_tag		= $tag_list->{ 'TAB' };
		my $newline_tag	= $tag_list->{ 'NEWLINE' };
		my $word_tag	= $tag_list->{ 'WORD' };
		my $run_tag		= $tag_list->{ 'RUN' };

		# A damn line can contain both <run> and <wd>
		while (defined $child)
		{
			my $xpath = $child->path();

			# if this child is <run>
			if ($xpath =~ m/\/$run_tag$/)
			{
				my $run = new Omni::Omnirun();

				# If the tab flag is on
				$run->set_previous_tab($tab_flag);

				# Set raw content
				$run->set_raw($child->sprint());
				
				# Update object list
				push @tmp_objs, $run;

				# Update content
				$tmp_content = $tmp_content . $run->get_content();

				# Tab flag - off
				$tab_flag = 0;

				# Check last tab
				if (1 == $run->is_last_tab()) {
					# Update the total number of tab
					$tmp_tab = $tmp_tab + 1;

					# Tab flag - on
					$tab_flag = 1;
				}
			}
			# if this child is <wd>
			elsif ($xpath =~ m/\/$word_tag$/)
			{
				# One word can contain many <run>
				my $grand_child = $child->first_child( $tag_list->{ 'RUN' } );

				# The first <run> is a special child
				if (defined $grand_child)
				{
					while (defined $grand_child)
					{
						# NOTE: The following code is controvery. Consider the case when a word
						# contain two runs, which means that this word has two parts in two different
						# format.
						#
						# If I want to keep all these format info, I need to consider that this word
						# is actually two words with no space between them
						#
						# But for compatible with Thang's code, there must be only one word here and
						# subsequently only one run. So I only keep the first run

						# NOTE: The first <run> in <wd> will has the word position information
						my $output = XML::Writer::String->new();
						my $writer = new XML::Writer(OUTPUT => $output, UNSAFE => 'true');					
				
						# Form the fake <run>
						$writer->startTag(	"run", 
											$att_list->{ 'FONTFACE' } 	=> GetNodeAttr($grand_child, $att_list->{ 'FONTFACE' }),
											$att_list->{ 'FONTFAMILY' }	=> GetNodeAttr($grand_child, $att_list->{ 'FONTFAMILY' }),
											$att_list->{ 'FONTPITCH' } 	=> GetNodeAttr($grand_child, $att_list->{ 'FONTPITCH' }),
											$att_list->{ 'FONTSIZE' } 	=> GetNodeAttr($grand_child, $att_list->{ 'FONTSIZE' }),
											$att_list->{ 'SPACING' } 	=> GetNodeAttr($grand_child, $att_list->{ 'SPACING' }),
											$att_list->{ 'SUSCRIPT' } 	=> GetNodeAttr($grand_child, $att_list->{ 'SUSCRIPT' }),
											$att_list->{ 'UNDERLINE' } 	=> GetNodeAttr($grand_child, $att_list->{ 'UNDERLINE' }),
											$att_list->{ 'BOLD' }		=> GetNodeAttr($grand_child, $att_list->{ 'BOLD' }),
											$att_list->{ 'ITALIC' }		=> GetNodeAttr($grand_child, $att_list->{ 'ITALIC' })	);
						# Form the fake <wd>
						$writer->startTag(	"wd", 
											$att_list->{ 'BOTTOM' } 	=> GetNodeAttr($child, $att_list->{ 'BOTTOM' }),
											$att_list->{ 'TOP' }		=> GetNodeAttr($child, $att_list->{ 'TOP' }),
											$att_list->{ 'LEFT' } 		=> GetNodeAttr($child, $att_list->{ 'LEFT' }),
											$att_list->{ 'RIGHT' } 		=> GetNodeAttr($child, $att_list->{ 'RIGHT' })	);
		
						$writer->raw( $grand_child->xml_string() );
						$writer->endTag("wd");
						$writer->endTag("run");
						$writer->end();

						# Fake run 
						my $run = new Omni::Omnirun();

						# Indicate that it is a faked run
						$run->set_fake($index);
						
						# If the tab flag is on
						$run->set_previous_tab($tab_flag);

						# Set raw content
						$run->set_raw($output->value());

						# Update run list
						push @tmp_objs, $run;

						# Update content
						$tmp_content = $tmp_content . $run->get_content();

						# Tab flag - off
						$tab_flag = 0;

						# Check last tab
						if (1 == $run->is_last_tab()) {
							# Update the total number of tab
							$tmp_tab = $tmp_tab + 1;

							# Tab flag - on
							$tab_flag = 1;
						}

						# Little brother
						if ($grand_child->is_last_child) 
						{ 
							last; 
						}
						else
						{
							$grand_child = $grand_child->next_sibling( $tag_list->{ 'RUN' } );
						}
					}	
				}
				# Special case: <wd> contains no <run> but stores the format itself
				else
				{
					my $output = XML::Writer::String->new();
					my $writer = new XML::Writer(OUTPUT => $output, UNSAFE => 'true');

					# Form the fake <run>
					$writer->startTag(	"run", 
										$att_list->{ 'FONTFACE' } 	=> GetNodeAttr($child, $att_list->{ 'FONTFACE' }),
										$att_list->{ 'FONTFAMILY' }	=> GetNodeAttr($child, $att_list->{ 'FONTFAMILY' }),
										$att_list->{ 'FONTPITCH' } 	=> GetNodeAttr($child, $att_list->{ 'FONTPITCH' }),
										$att_list->{ 'FONTSIZE' } 	=> GetNodeAttr($child, $att_list->{ 'FONTSIZE' }),
										$att_list->{ 'SPACING' } 	=> GetNodeAttr($child, $att_list->{ 'SPACING' }),
										$att_list->{ 'SUSCRIPT' } 	=> GetNodeAttr($child, $att_list->{ 'SUSCRIPT' }),
										$att_list->{ 'UNDERLINE' } 	=> GetNodeAttr($child, $att_list->{ 'UNDERLINE' }),
										$att_list->{ 'BOLD' }		=> GetNodeAttr($child, $att_list->{ 'BOLD' }),
										$att_list->{ 'ITALIC' }		=> GetNodeAttr($child, $att_list->{ 'ITALIC' })	);
					# Form the fake <wd>
					$writer->startTag(	"wd",
										$att_list->{ 'BOTTOM' } 	=> GetNodeAttr($child, $att_list->{ 'BOTTOM' }),
										$att_list->{ 'TOP' }		=> GetNodeAttr($child, $att_list->{ 'TOP' }),
										$att_list->{ 'LEFT' } 		=> GetNodeAttr($child, $att_list->{ 'LEFT' }),
										$att_list->{ 'RIGHT' } 		=> GetNodeAttr($child, $att_list->{ 'RIGHT' })	);
					# Get the inner <wd> content
					$writer->raw( $child->xml_string() );
					$writer->endTag("wd");
					$writer->endTag("run");
					$writer->end();

					# Fake run
					my $run = new Omni::Omnirun();

					# Indicate that it is a faked run
					$run->set_fake($index);

					# If the tab flag is on
					$run->set_previous_tab($tab_flag);
		
					# Set raw content
					$run->set_raw($output->value());
					
					# Update run list
					push @tmp_objs, $run;

					# Update content
					$tmp_content = $tmp_content . $run->get_content();

					# Tab flag - off
					$tab_flag = 0;

					# Check last tab
					if (1 == $run->is_last_tab()) {
						# Update the total number of tab
						$tmp_tab = $tmp_tab + 1;
	
						# Tab flag - on
						$tab_flag = 1;
					}
				}

				# Update fake index
				$index++;
			}
			elsif  ($xpath =~ m/\/$space_tag$/)
			{
				# Update content
				$tmp_content = $tmp_content . " ";
			}
			elsif  ($xpath =~ m/\/$tab_tag$/)
			{
				# Update content
				$tmp_content = $tmp_content . "\t";
				
				# Update the total number of tab
				$tmp_tab = $tmp_tab + 1;

				# Tab flag - on
				$tab_flag = 1;
			}
			elsif  ($xpath =~ m/\/$newline_tag$/)
			{
				# Update content
				$tmp_content = $tmp_content . "\n";

				# Tab flag - off
				$tab_flag = 0;
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
}

sub get_bullet
{
	my ($self) = @_;
	return $self->{ '_bullet' };
}

sub set_bullet
{
	my ($self, $bullet) = @_;
	$self->{ '_bullet' } = $bullet;		
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

sub get_baseline
{
	my ($self) = @_;
	return $self->{ '_baseline' };
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
