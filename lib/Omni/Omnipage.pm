package Omni::Omnipage;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omniword;
use Omni::Omnirun;
use Omni::Omniline;
use Omni::Omnipara;
use Omni::Omnicol;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;

# Temporary variables
my $tmp_content 	= undef;
my @tmp_cols		= ();

###
# A page object in Omnipage xml: a page contains zero or many collums
#
# Do Hoang Nhat Huy, 09 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Page: a page can have many columns
	my @cols	= ();

	# Class members
	my $self = {	'_raw'			=> undef,
					'_content'		=> undef,
					'_cols'			=> \@cols	};

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
	@{$self->{ '_cols' } }	= @tmp_cols;
	
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
	# because there's no column or dd, what the heck is dd
	@tmp_cols		= ();

	# Get <page> node attributes

	my $child = undef;
	# Get the body text
	$child = $node->first_child( $tag_list->{ 'BODY' } );
	# Page with no body, return
	if (! defined $child) { return; }

	# Get the first child in the body text
	$child = $child->first_child();

	# Some type of child
	my $section_tag	= $tag_list->{ 'SECTION' };
	my $column_tag	= $tag_list->{ 'COL' };
	my $dd_tag		= $tag_list->{ 'DD' };

	# Check if there's any column or dd, what the heck is dd 
	while (defined $child)
	{
		my $xpath = $child->path();

		# if this child is <section>
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
					push @tmp_cols, $column;

					# Update content
					$tmp_content = $tmp_content . $column->get_content() . "\n";
				}
				# if this child is <dd>
				elsif ($grand_xpath =~ m/\/$dd_tag$/)
				{
					# Create the fake <column>
					my $output = XML::Writer::String->new();
					my $writer = new XML::Writer(OUTPUT => $output, UNSAFE => 'true');

					$writer->startTag(	"column", 
										$att_list->{ 'BOTTOM' } 	=> GetNodeAttr($grand_child, $att_list->{ 'BOTTOM' }),
										$att_list->{ 'TOP' }		=> GetNodeAttr($grand_child, $att_list->{ 'TOP' }),
										$att_list->{ 'LEFT' } 		=> GetNodeAttr($grand_child, $att_list->{ 'LEFT' }),
										$att_list->{ 'RIGHT' } 		=> GetNodeAttr($grand_child, $att_list->{ 'RIGHT' })	);

					$writer->raw( $grand_child->xml_string() );
					$writer->endTag("column");
					$writer->end();

					# Save the fake <column>
					my $column = new Omni::Omnicol();

					# Set raw content
					$column->set_raw( $output->value() );

					# Update column list
					push @tmp_cols, $column;

					# Update content
					$tmp_content = $tmp_content . $column->get_content() . "\n";
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
			push @tmp_cols, $column;

			# Update content
			$tmp_content = $tmp_content . $column->get_content() . "\n";
		}
		# if this child is <dd>
		elsif ($xpath =~ m/\/$dd_tag$/)
		{
			# Create the fake <column>
			my $output = XML::Writer::String->new();
			my $writer = new XML::Writer(OUTPUT => $output, UNSAFE => 'true');

			$writer->startTag(	"column", 
								$att_list->{ 'BOTTOM' } 	=> GetNodeAttr($child, $att_list->{ 'BOTTOM' }),
								$att_list->{ 'TOP' }		=> GetNodeAttr($child, $att_list->{ 'TOP' }),
								$att_list->{ 'LEFT' } 		=> GetNodeAttr($child, $att_list->{ 'LEFT' }),
								$att_list->{ 'RIGHT' } 		=> GetNodeAttr($child, $att_list->{ 'RIGHT' })	);

			$writer->raw( $child->xml_string() );
			$writer->endTag("column");
			$writer->end();

			# Save the fake <column>
			my $column = new Omni::Omnicol();

			# Set raw content
			$column->set_raw( $output->value() );

			# Update column list
			push @tmp_cols, $column;

			# Update content
			$tmp_content = $tmp_content . $column->get_content() . "\n";
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

	my @all_cols = $node->descendants( $tag_list->{ 'COLUMN' } );
	foreach my $cl (@all_cols)
	{
		
	}
}

sub get_cols_ref
{
	my ($self) = @_;
	return $self->{ '_cols' };
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
