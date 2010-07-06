package ParsCit::Citation;
#
# Container object for citation data.  Stores all metadata fields
# associated with a citation and utility methods for data access
# and transformation.
#
# Isaac Councill, 7/19/07
#

use strict;
use CSXUtil::SafeText qw(cleanAll cleanXML);

sub new {
  my ($class) = @_;
  my @authors = ();
  my @contexts = ();
  ########## modified by Nick Friedrich
  ### added array @positions for storing position of the marker of a context
  #
  # HISTORY: Nick (v081201)
  #
  # As Joran wrote I added functionality to find the position of a
  # reference (context) in the (body)text. I added an array "positions"
  # and also an add-method und get-method to Citation.pm. To find the
  # positions I modified CitationContext::getCitationContext. When a
  # context is found, the position of the match (subtract the context
  # radius) is stored in an array. The method returns an array with the
  # positions in addition to the array with the
  # contexts.Controller::extractCitationsImpl is modified accordingly.
  #
  my @positions = ();
  my @citStrs = (); # Thang Nov 09 add in-text citation strings e.g. Brown et al., 1990 which might differ from the marker Brown, Pietra, deSouza, Lai, Mercer, 1990

  # Thang May 10 add positions (word unit, 0-based) for in-text citation strings
  my @startWordPositions = ();   my @endWordPositions = ();

  my $self = {
	      '_rawString' => undef,
	      '_markerType' => undef,
	      '_marker' => undef,
	      '_authors' => \@authors,
	      '_title' => undef,
	      '_year' => undef,
	      '_publisher' => undef,
	      '_location' => undef,
	      '_booktitle' => undef,
	      '_journal' => undef,
	      '_pages' => undef,
	      '_volume' => undef,
	      '_number' => undef,
	      '_contexts' => \@contexts,
	      '_tech' => undef,
	      '_institution' => undef,
	      '_editor' => undef,
	      '_note' => undef,
	      '_positions' => \@positions,
	      '_citStrs' => \@citStrs, # Thang Nov 09 add in-text citation strings
	      
	      # Thang May 10
	      '_startWordPositions' => \@startWordPositions, 
	      '_endWordPositions' => \@endWordPositions, 
	     };
  ##########
  bless $self, $class;
  return $self;
} # new


##
# Looks for various combinations of data that could be used to
# uniquely identify a citation.  If too much data is missing,
# returns 0; otherwise, returns 1.
##
sub isValid {
    my ($self) = @_;
    my @authors = $self->getAuthors();
    my $title = $self->getTitle();
    my $venue = $self->getJournal();
    my $date = $self->getDate();

########## modified by Artemy Kolchinsky (v090625)
### added extra checks to subroutine 'isValid' in lib/ParsCit/Citation.pm.  It helps to eliminate a lot of mis-parsed citations
    my $rawString = $self->getString();
    if (!defined $date) {    # date not found in citation
      return 0;
    }
    if (length($rawString) > 400) {  # citation string over 400 characters --- probably a mistake in parsing somewhere
#      print STDERR "#! Long citation string: \"$rawString\"\n";
      return 0;
    }
########## end modified by Artemy Kolchinsky (v090625)

    if (!defined $venue) {
	$venue = $self->getBooktitle();
    }
    if ($#authors>=0 && (defined $title || defined $date)) {
	return 1;
    }
    if (defined $venue && defined $date) {
	return 1;
    }
    if (defined $title) {
	return 1;
    }

    return 0;

} # isValid


##
# Utility for loading in a datum based on a tag from Tr2crfpp output.
##
sub loadDataItem {
    my ($self, $tag, $data) = @_;
    if ($tag eq "authors") {
	my @authors = @$data;
	foreach my $auth (@authors) {
	    $self->addAuthor($auth);
	}
    }
    if ($tag eq "contexts") {
	my @contexts = @$data;
	foreach my $context (@contexts) {
	    $self->addContext($context);
	}
    }
    if ($tag eq "title") {
	$self->setTitle($data);
    }
    if ($tag eq "date") {
	$self->setDate($data);
    }
    if ($tag eq "journal") {
	$self->setJournal($data);
    }
    if ($tag eq "booktitle") {
	$self->setBooktitle($data);
    }
    if ($tag eq "tech") {
	$self->setTech($data);
    }
    if ($tag eq "location") {
	$self->setLocation($data);
    }
    if ($tag eq "volume") {
	$self->setVolume($data);
    }
    if ($tag eq "note") {
	$self->setNote($data);
    }
    if ($tag eq "editor") {
	$self->setEditor($data);
    }
    if ($tag eq "publisher") {
	$self->setPublisher($data);
    }
    if ($tag eq "pages") {
	$self->setPages($data);
    }
    if ($tag eq "institution") {
	$self->setInstitution($data);
    }
    if ($tag eq "marker") {
	$self->setMarker($data);
    }

} # loadDataItem


##
# Returns a well-formed XML snippet containing all the data
# in a citation object.
##
sub toXML {
    my $self = shift;

    my $valid = $self->isValid();
    if ($valid>0) {
	$valid = "true";
    } else {
	$valid = "false";
    }

    my $xml = "<citation valid=\"$valid\">\n";
    my @authors = $self->getAuthors();
    map { $_ =~ s/_/ /g } @authors;

    if ($#authors >= 0) {
	$xml .= "<authors>\n";
	foreach my $auth (@authors) {
	    cleanAll(\$auth);
	    $xml .= "<author>$auth</author>\n";
	}
	$xml .= "</authors>\n";
    }

    my $title = $self->getTitle();
    if (defined $title) {
	cleanAll(\$title);
	$xml .= "<title>$title</title>\n";
    }

    my $date = $self->getDate();
    if (defined $date) {
	cleanAll(\$date);
	$xml .= "<date>$date</date>\n";
    }

    my $journal = $self->getJournal();
    if (defined $journal) {
	cleanAll(\$journal);
	$xml .= "<journal>$journal</journal>\n";
    }

    my $booktitle = $self->getBooktitle();
    if (defined $booktitle) {
	cleanAll(\$booktitle);
	$xml .= "<booktitle>$booktitle</booktitle>\n";
    }

    my $tech = $self->getTech();
    if (defined $tech) {
	cleanAll(\$tech);
	$xml .= "<tech>$tech</tech>\n";
    }

    my $volume = $self->getVolume();
    if (defined $volume) {
	cleanAll(\$volume);
	$xml .= "<volume>$volume</volume>\n";
    }

    my $pages = $self->getPages();
    if (defined $pages) {
	cleanAll(\$pages);
	$xml .= "<pages>$pages</pages>\n";
    }

    my $editor = $self->getEditor();
    if (defined $editor) {
	cleanAll(\$editor);
	$xml .= "<editor>$editor</editor>\n";
    }

    my $publisher = $self->getPublisher();
    if (defined $publisher) {
	cleanAll(\$publisher);
	$xml .= "<publisher>$publisher</publisher>\n";
    }

    my $institution = $self->getInstitution();
    if (defined $institution) {
	cleanAll(\$institution);
	$xml .= "<institution>$institution</institution>\n";
    }

    my $location = $self->getLocation();
    if (defined $location) {
	cleanAll(\$location);
	$xml .= "<location>$location</location>\n";
    }

    my $note = $self->getNote();
    if (defined $note) {
	cleanAll(\$note);
	$xml .= "<note>$note</note>\n";
    }
	
########## modified by Nick Friedrich (v081201)
### the xml-element "context" contains now an attribute "position"
    my @contexts = $self->getContexts();
    my @positions = $self->getPositions();
    my @citStrs = $self->getCitStrs(); # Thang Nov 09

    # Thang May 10
    my @startWordPositions = $self->getStartWordPositions(); 
    my @endWordPositions = $self->getEndWordPositions(); 

    if ($#contexts >= 0) {
	$xml .= "<contexts>\n";
	foreach my $context (@contexts) {
	    cleanAll(\$context);
	    my $pos = shift(@positions);
	    my $citStr = shift(@citStrs); # Thang Nov 09
	    cleanAll(\$citStr);

	    # Thang May 10
	    my $startWordPosition = shift(@startWordPositions); 
	    my $endWordPosition = shift(@endWordPositions);

	    $xml .= "<context";
	    $xml .= " position=\"".$pos."\"";
	    $xml .= " citStr=\"".$citStr."\""; # Thang Nov 09

	    # Thang May 10
	    $xml .= " startWordPosition=\"".$startWordPosition."\""; 
	    $xml .= " endWordPosition=\"".$endWordPosition."\"";

	    $xml .= ">$context</context>\n";
	}
	$xml .= "</contexts>\n";
    }
########## end modified by Nick Friedrich (v081201)

    my $marker = $self->getMarker();
    if (defined $marker) {
	cleanAll(\$marker);
	$xml .= "<marker>$marker</marker>\n";
    }

    my $rawString = $self->getString();
    if (defined $rawString) {
	cleanXML(\$rawString);
	$xml .= "<rawString>$rawString</rawString>\n";
    }
    $xml .= "</citation>\n";
    return $xml;

} # toXML


sub getPositions {
    my ($self) = @_;
    return @{$self->{'_positions'}};
}

sub addPosition {
    my ($self, $position) = @_;
    my @positions = @{$self->{'_positions'}};
    push @positions, $position;
    $self->{'_positions'} = \@positions;
}

# Thang Nov 09 add in-text citation strings
sub getCitStrs {
    my ($self) = @_;
    return @{$self->{'_citStrs'}};
}

sub addCitStr {
    my ($self, $citStr) = @_;
    my @citStrs = @{$self->{'_citStrs'}};
    push @citStrs, $citStr;
    $self->{'_citStrs'} = \@citStrs;
}
# End Thang Nov 09 add in-text citation strings

# Thang May 10 add positions (in word unit, 0-based) for in-text citation strings
sub getStartWordPositions {
    my ($self) = @_;
    return @{$self->{'_startWordPositions'}};
}
sub addStartWordPosition {
    my ($self, $startWordPosition) = @_;
    my @startWordPositions = @{$self->{'_startWordPositions'}};
    push @startWordPositions, $startWordPosition;
    $self->{'_startWordPositions'} = \@startWordPositions;
}

sub getEndWordPositions {
    my ($self) = @_;
    return @{$self->{'_endWordPositions'}};
}
sub addEndWordPosition {
    my ($self, $endWordPosition) = @_;
    my @endWordPositions = @{$self->{'_endWordPositions'}};
    push @endWordPositions, $endWordPosition;
    $self->{'_endWordPositions'} = \@endWordPositions;
}

# End Thang May 10 add positions (in word unit) for in-text citation strings

sub getString {
    my ($self) = @_;
    return $self->{'_rawString'};
}

sub setString {
    my ($self, $str) = @_;
    $self->{'_rawString'} = $str;
}

sub getMarkerType {
    my ($self) = @_;
    return $self->{'_markerType'};
}

sub setMarkerType {
    my ($self, $markerType) = @_;
    $self->{'_markerType'} = $markerType;
}

sub getMarker {
    my ($self) = @_;
    return $self->{'_marker'};
}

sub setMarker {
    my ($self, $marker) = @_;
    $self->{'_marker'} = $marker;
}

sub addAuthor {
    my ($self, $author) = @_;
    my @authors = @{$self->{'_authors'}};
    push @authors, $author;
    $self->{'_authors'} = \@authors;
}

sub getAuthors {
    my ($self) = @_;
    return @{$self->{'_authors'}};
}

sub addContext {
    my ($self, $context) = @_;
    my @contexts = @{$self->{'_contexts'}};
    push @contexts, $context;
    $self->{'_contexts'} = \@contexts;
}

sub getContexts {
    my ($self) = @_;
    return @{$self->{'_contexts'}};
}

sub getTitle {
    my ($self) = @_;
    return $self->{'_title'};
}

sub setTitle {
    my ($self, $title) = @_;
    $self->{'_title'} = $title;
}

sub getDate {
    my $self = shift;
    return $self->{'_year'};
}

sub setDate {
    my ($self, $year) = @_;
    $self->{'_year'} = $year;
}

sub getPublisher {
    my $self = shift;
    return $self->{'_publisher'};
}

sub setPublisher {
    my ($self, $publisher) = @_;
    $self->{'_publisher'} = $publisher;
}

sub getLocation {
    my $self = shift;
    return $self->{'_location'};
}

sub setLocation {
    my ($self, $location) = @_;
    $self->{'_location'} = $location;
}

sub getBooktitle {
    my $self = shift;
    return $self->{'_booktitle'};
}

sub setBooktitle {
    my ($self, $booktitle) = @_;
    $self->{'_booktitle'} = $booktitle;
}

sub getJournal {
    my $self = shift;
    return $self->{'_journal'};
}

sub setJournal {
    my ($self, $journal) = @_;
    $self->{'_journal'} = $journal;
}

sub getPages {
    my $self = shift;
    return $self->{'_pages'};
}

sub setPages {
    my ($self, $pages) = @_;
    $self->{'_pages'} = $pages;
}

sub getVolume {
    my $self = shift;
    return $self->{'_volume'};
}

sub setVolume {
    my ($self, $volume) = @_;
    $self->{'_volume'} = $volume;
}

sub getVolume {
    my $self = shift;
    return $self->{'_volume'};
}

sub setVolume {
    my ($self, $volume) = @_;
    $self->{'_volume'} = $volume;
}

sub getTech {
    my $self = shift;
    return $self->{'_tech'};
}

sub setTech {
    my ($self, $tech) = @_;
    $self->{'_tech'} = $tech;
}

sub getInstitution {
    my $self = shift;
    return $self->{'_institution'};
}

sub setInstitution {
    my ($self, $institution) = @_;
    $self->{'_institution'} = $institution;
}

sub getEditor {
    my $self = shift;
    return $self->{'_editor'};
}

sub setEditor {
    my ($self, $editor) = @_;
    $self->{'_editor'} = $editor;
}

sub getNote {
    my $self = shift;
    return $self->{'_note'};
}

sub setNote {
    my ($self, $note) = @_;
    $self->{'_note'} = $note;
}


##
# Build a marker based on the author list and publication year.
# This should be used when no marker was found during citation
# segmentation.
##
sub buildAuthYearMarker() {
    my $self = shift;
    my @authors = $self->getAuthors();
    my @lastNames = ();
    foreach my $auth (@authors) {
	my @toks = split " +", $auth;
	push @lastNames, $toks[$#toks];
    }
    my $year = $self->getDate();
    map { $_ =~ s/_/ /g } @lastNames;
    return join ", ", @lastNames, $year;

} # buildAuthYearMarker


1;
