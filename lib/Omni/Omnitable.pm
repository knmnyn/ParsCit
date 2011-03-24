package Omni::Omnitable;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omnicell;

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
my $tmp_alignment	= undef;

# My observation is that <table> contains <gridTable> and <cell>
# <gridTable> contain the base grid's coordinates
# <cell> contain the cell's position based on <gridTable> coordinates
# and various types of objects: <picture>, <para>, may be even <dd> but
# I'm not quite sure about this
my @tmp_objs		= ();

# Array contain grid coordinates
my @tmp_grid_cols	= ();
my @tmp_grid_rows	= ();

###
# A table object in Omnipage xml: a table contains cells with various objects
#
# Do Hoang Nhat Huy, 11 Feb 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Objs: a table can have many cells
	my @objs		= ();

	# Grid coordinates
	my @grid_cols	= ();
	my @grid_rows	= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNITABLE' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_bottom'		=> undef,
					'_top'			=> undef,
					'_left'			=> undef,
					'_right'		=> undef,
					'_alignment'	=> undef,
					'_grid_cols'	=> \@grid_cols,
					'_grid_rows'	=> \@grid_rows,
					'_objs'			=> \@objs	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <table> ... </table>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'TABLE' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'TABLE' }	=> \&parse};

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
	$self->{ '_alignment' }	= $tmp_alignment;

	# Copy all cells 
	@{$self->{ '_objs' } }		= @tmp_objs;

	# Copy all grid columns
	@{$self->{ '_grid_cols' } }	= @tmp_grid_cols;
	# Copy all grid rows
	@{$self->{ '_grid_rows' } }	= @tmp_grid_rows;
	
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

	# At first, content is blank
	$tmp_content	= "";
	# because there's no object
	@tmp_objs		= ();
	# and no coordinate
	@tmp_grid_cols	= ();
	@tmp_grid_rows	= ();

	# Get <table> node attributes
	$tmp_bottom			= GetNodeAttr($node, $att_list->{ 'BOTTOM' });
	$tmp_top			= GetNodeAttr($node, $att_list->{ 'TOP' });
	$tmp_left			= GetNodeAttr($node, $att_list->{ 'LEFT' });
	$tmp_right			= GetNodeAttr($node, $att_list->{ 'RIGHT' });
	$tmp_alignment		= GetNodeAttr($node, $att_list->{ 'ALIGN' });

	# A table contains <cell> and <gridtable> tag
	my $cell_tag		= $tag_list->{ 'CELL' };
	my $grid_tag		= $tag_list->{ 'GRID' };
	my $grid_col_tag	= $tag_list->{ 'GRID-COL' };
	my $grid_row_tag	= $tag_list->{ 'GRID-ROW' };

	my $child = undef;
	# Get the first child which is tha <gridtable>
	$child = $node->first_child( $grid_tag );

	# Grid table found, a formatted table
	if (defined $child) 	
	{ 
		# Get the first grid coordinate
		$child = $child->first_child();

		# Extract the grid coodinates
		while (defined $child)
		{
			my $xpath = $child->path();

			# if this child is a <gridCol> tag
			if ($xpath =~ m/\/$grid_col_tag$/)
			{
				push @tmp_grid_cols, GetNodeText( $child );
			}
			# if this child is a <gridRow> tag
			elsif ($xpath =~ m/\/$grid_row_tag$/)
			{
				push @tmp_grid_rows, GetNodeText( $child );
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

	# All cells
	my @all_cells = $node->descendants( $cell_tag );
	foreach my $cell (@all_cells)
	{
		my $obj = new Omni::Omnicell();

		# Set raw content
		$obj->set_raw($cell->sprint());

		# Update cell list
		push @tmp_objs, $obj;

	}

	# Unformatted table
	if ((scalar(@tmp_grid_cols) == 0) || (scalar(@tmp_grid_rows) == 0))
	{
		# Just append cell content
		foreach my $cell (@tmp_objs) { $tmp_content = $tmp_content . $cell->get_content() . "\n"; }
	}
	# Formatted table
	else
	{
		# Table content
		my @content_matrix = ();
		
		# Matrix initialization
		for(my $i = 0; $i < scalar(@tmp_grid_rows); $i++)
		{
			# Empty row
			my @row = ();
			# Update the row
			for(my $j = 0; $j < scalar(@tmp_grid_cols); $j++) { push @row, ""; }
			# Save the row
			push @content_matrix, [ @row ];
		}

		# Update table content
		foreach my $cell (@tmp_objs)
		{
			my $row_index = $cell->get_grid_row_from();
			my $col_index = $cell->get_grid_col_from();

			# Check index and update
			if (($row_index < scalar(@content_matrix)) && ($col_index < scalar(@{ $content_matrix[ $row_index ] })))
			{
				my $cell_content = undef;
				# Get content
				$cell_content	 = $cell->get_content();
				# Trim
				$cell_content	 =~ s/^\s+|\s+$//g;

				$content_matrix[ $row_index ][ $col_index ] = $cell_content;
			}
		}

		# Save content
		foreach my $row (@content_matrix)
		{
			# This is used to handle the case in which a cell have multiple lines
			my @lines = ();
			# Foreach cell in the row, get its content
			foreach my $cell (@{ $row })
			{
				my @local_lines = split /\n/, $cell;
				for (my $i = 0; $i < scalar(@local_lines); $i++)
				{
					if ($i == scalar(@lines)) { push @lines, ""; }
					$lines[ $i ] = $lines[ $i ] . $local_lines[ $i ] . "\t";
				}
			}
			# Add a new row
			foreach my $line (@lines)
			{
				$tmp_content = $tmp_content . $line . "\n";
			}
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

sub get_alignment
{
	my ($self) = @_;
	return $self->{ '_alignment' };
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
