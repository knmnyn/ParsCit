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

	# Content of all rows in the table
	my @rcontent	= ();
	# All line in the table
	my @lines		= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNITABLE' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_rcontent'		=> \@rcontent,
					'_lines'		=> \@lines,
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
	my $twig_handlers 	= { $tag_list->{ 'TABLE' }	=> sub { parse(@_, \$self); } };

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
	my $tmp_content		= "";
	my @tmp_rcontent	= ();
	my @tmp_lines		= ();
	# because there's no object
	my @tmp_objs		= ();
	# and no coordinate
	my @tmp_grid_cols	= ();
	my @tmp_grid_rows	= ();

	# Get <table> node attributes
	my $tmp_bottom		= GetNodeAttr($node, $att_list->{ 'BOTTOM' });
	my $tmp_top			= GetNodeAttr($node, $att_list->{ 'TOP' });
	my $tmp_left		= GetNodeAttr($node, $att_list->{ 'LEFT' });
	my $tmp_right		= GetNodeAttr($node, $att_list->{ 'RIGHT' });
	my $tmp_alignment	= GetNodeAttr($node, $att_list->{ 'ALIGN' });

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

		# Get every line objects in the table, this's a nightmare
		foreach my $cell (@tmp_objs) {
			foreach my $para (@{ $cell->get_objs_ref }) {
				foreach my $line (@{ $para->get_objs_ref }) {
					push @tmp_lines, $line;	
				}
			}
		}
	}
	# Formatted table
	else
	{
		# Table content
		my @content_matrix = ();
		# Lines
		my @lines_matrix  = ();
		
		# Matrix initialization
		for(my $i = 0; $i < scalar(@tmp_grid_rows); $i++)
		{
			# Empty row
			my @row_content = ();
			my @row_line	= ();

			# Update the row
			for(my $j = 0; $j < scalar(@tmp_grid_cols); $j++) { 
				push @row_content, ""; 

				my @tmp = ();
				# Just a blank temporary array
				push @row_line, [ @tmp ];
			}

			# Save the row as content
			push @content_matrix, [ @row_content ];

			# Save the row
			push @lines_matrix, [ @row_line ];
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
				# Remove blank line
				$cell_content	 =~ s/\n\s*\n/\n/g;
				# Save the content
				$content_matrix[ $row_index ][ $col_index ] = $cell_content;

				# Get every line objects in the cell, this's a nightmare
				foreach my $para (@{ $cell->get_objs_ref }) {
					foreach my $line (@{ $para->get_objs_ref }) {
						push @{ $lines_matrix[ $row_index ][ $col_index ] }, $line;	
					}
				}
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

			my $row_content = "";
			# Add a new row to the table content and the row content
			foreach my $line (@lines)
			{
				$row_content = $row_content . $line . "\n";
				$tmp_content = $tmp_content . $line . "\n";
			}
			
			# Save row content
			push @tmp_rcontent, $row_content;
		}

		# Save lines
		foreach my $row (@lines_matrix) {
			my @runs = ();	
			# Concat similar line in cells of the same row
			foreach my $cell (@{ $row }) {
				my @tmp = @{ $cell };

				for (my $i = 0; $i < scalar @tmp; $i++) {
					if ($i == scalar @runs) { push @runs, ""; }
					
					foreach my $run (@{ $tmp[ $i ]->get_objs_ref }) {
						$runs[ $i ] = $runs[ $i ] . $run->get_raw();
					}
				}			
			}

			foreach my $fake_line (@runs) {
				my $output = XML::Writer::String->new();
				my $writer = new XML::Writer(OUTPUT => $output, UNSAFE => 'true');
				# Form the fake <ln>
				$writer->startTag("ln");

				$writer->raw( $fake_line );
				
				# We have the fake <ln>
				$writer->endTag("ln");
				$writer->end();
				
				my $line = new Omni::Omniline();

				# Set raw content
				$line->set_raw($output->value());

				# Update line list
				push @tmp_lines, $line;
			}
		}
	}

	# Copy information from temporary variables to class members
	$$self->{ '_bottom' }			= $tmp_bottom;
	$$self->{ '_top' }				= $tmp_top;
	$$self->{ '_left' }				= $tmp_left;
	$$self->{ '_right' } 			= $tmp_right;
	$$self->{ '_alignment' }		= $tmp_alignment;

	# Copy all cells 
	@{$$self->{ '_objs' } }			= @tmp_objs;

	# Copy all grid columns
	@{$$self->{ '_grid_cols' } }	= @tmp_grid_cols;
	# Copy all grid rows
	@{$$self->{ '_grid_rows' } }	= @tmp_grid_rows;
	
	# Copy content
	$$self->{ '_content' }			= $tmp_content;
	# Copy row content
	@{ $$self->{ '_rcontent' } }	= @tmp_rcontent;
	# Copy all lines in the table
	@{ $$self->{ '_lines' } }		= @tmp_lines;
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

sub get_row_content
{
	my ($self) = @_;
	return $self->{ '_rcontent' };	
}

sub get_lines
{
	my ($self) = @_;
	return $self->{ '_lines' };	
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
