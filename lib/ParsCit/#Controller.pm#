package ParsCit::Controller;
#
# This package is used to pull together various citation
# processing modules in the ParsCit distribution, serving
# as a script for handling the entire citation processing
# control flow.  The extractCitations subroutine should be
# the only needed API element if XML output is desired;
# however, the extractCitationsImpl subroutine can be used
# to get direct access to the list of citation objects.
#
# Isaac Councill, 07/23/07
#
require 'dumpvar.pl';
use strict;
use ParsCit::PreProcess;
use ParsCit::PostProcess;
use ParsCit::Tr2crfpp;
use ParsCit::CitationContext;
use ParsCit::Config;
use CSXUtil::SafeText qw(cleanXML);


##
# Main API method for generating an XML document including all
# citation data.  Returns a reference XML document and a
# reference to the article body text.
##
sub extractCitations {
    my ($textFile) = @_;

    my ($status, $msg, $rCitations, $rBodyText)
	= extractCitationsImpl($textFile);
    if ($status > 0) {
	return buildXMLResponse($rCitations);
    } else {
	my $error = "Error: $msg";
	return \$error;
    }

} # extractCitationsx


sub extractCitationsAlreadySegmented {
    my ($textFile) = @_;

    my ($status, $msg) = (1, "");

    if (!open(IN, "<:utf8", $textFile)) {
	return (-1, "Could not open file $textFile: $!");
    }

    my @rawCitations = ();
    my $currentCitation;
    while(<IN>) {
	chomp();
	if (m/^\s*$/ && defined $currentCitation) {
	    my $cite = new ParsCit::Citation();
	    $cite->setString($currentCitation);
	    push @rawCitations, $cite;
	    $currentCitation = undef;
	    next;
	}
	if (!defined $currentCitation) {
	    $currentCitation = $_;
	} else {
	    $currentCitation .= " ".$_;
	}
    }
    close IN;
    if (defined $currentCitation) {
	my $cite = new ParsCit::Citation();
	push @rawCitations, $cite;
    }

    my @citations;
    my @validCitations = ();
    my $normalizedCiteText;
    foreach my $citation (@rawCitations) {
	# Tr2cfpp needs an enclosing tag for initial class seed.
	my $citeString = $citation->getString();
	if (defined $citeString && $citeString !~ m/^\s*$/) {
	    $normalizedCiteText .=
		"<title> ".$citation->getString(). " </title>\n";
	    push @citations, $citation;
	}
    }

    if ($#citations < 0) {
	# Stop - nothing left to do.
	return ($status, $msg, \@validCitations);
    }

    my $tmpFile = ParsCit::Tr2crfpp::prepData(\$normalizedCiteText, $textFile);
    my $outFile = $tmpFile."_dec";

    if (ParsCit::Tr2crfpp::decode($tmpFile, $outFile)) {
	my ($rRawXML, $rCiteInfo, $tstatus, $tmsg) =
	    ParsCit::PostProcess::readAndNormalize($outFile);
	if ($tstatus <= 0) {
	    return ($tstatus, $msg, undef, undef);
	}
	my @citeInfo = @{$rCiteInfo};
	if ($#citations == $#citeInfo) {
	    for (my $i=0; $i<=$#citations; $i++) {
		my $citation = $citations[$i];
		my %citeInfo = %{$citeInfo[$i]};
		foreach my $key (keys %citeInfo) {
		    $citation->loadDataItem($key, $citeInfo{$key});
		}
#		unless ($citation->isValid()>0) {
#		    next;
#		}
		my $marker = $citation->getMarker();
		if (!defined $marker) {
		    $marker = $citation->buildAuthYearMarker();
		    $citation->setMarker($marker);
		}
		push @validCitations, $citation;
	    }
	} else {
	    $status = -1;
	    $msg = "Mismatch between expected citations and cite info";
	}
    }

    unlink($tmpFile);
    unlink($outFile);

    return buildXMLResponse(\@validCitations);

}

##
# Main script for actually walking through the steps of
# citation processing.  Returns a status code (0 for failure),
# an error message (may be blank if no error), a reference to
# an array of citation objects and a reference to the body
# text of the article being processed.
##
sub extractCitationsImpl {
    my ($textFile, $bWriteSplit) = @_;

    if (!defined $bWriteSplit) {
	$bWriteSplit = $ParsCit::Config::bWriteSplit;
    }

    my ($status, $msg) = (1, "");

    if (!open (IN, "<:utf8", "$textFile")) {
	return (-1, "Could not open text file $textFile: $!");
    }

    my $text;
    {
	local $/ = undef;
	$text = <IN>;
    }
    close IN;

    my ($rCiteText, $rNormBodyText, $rBodyText) =
	ParsCit::PreProcess::findCitationText(\$text);
    my ($citeFile, $bodyFile) = ("", "");
    if ($bWriteSplit > 0) {
	($citeFile, $bodyFile) =
	    writeSplit($textFile, $rCiteText, $rBodyText);
    }

    my $rRawCitations = ParsCit::PreProcess::segmentCitations($rCiteText);
    my @citations = ();
    my @validCitations = ();

    my $normalizedCiteText;
    foreach my $citation (@{$rRawCitations}) {
	# Tr2cfpp needs an enclosing tag for initial class seed.
	my $citeString = $citation->getString();
	if (defined $citeString && $citeString !~ m/^\s*$/) {
	    $normalizedCiteText .=
		"<title> ".$citation->getString(). " </title>\n";
	    push @citations, $citation;
	}
    }

    if ($#citations < 0) {
	# Stop - nothing left to do.
	return ($status, $msg, \@validCitations, $rNormBodyText);
    }

    my $tmpFile = ParsCit::Tr2crfpp::prepData(\$normalizedCiteText, $textFile);
    my $outFile = $tmpFile."_dec";

    if (ParsCit::Tr2crfpp::decode($tmpFile, $outFile)) {
	my ($rRawXML, $rCiteInfo, $tstatus, $tmsg) =
	    ParsCit::PostProcess::readAndNormalize($outFile);
	if ($tstatus <= 0) {
	    return ($tstatus, $msg, undef, undef);
	}
	my @citeInfo = @{$rCiteInfo};
	if ($#citations == $#citeInfo) {
	    for (my $i=0; $i<=$#citations; $i++) {
		my $citation = $citations[$i];
		my %citeInfo = %{$citeInfo[$i]};
		foreach my $key (keys %citeInfo) {
		    $citation->loadDataItem($key, $citeInfo{$key});
		}
#		unless ($citation->isValid()>0) {
#		    next;
#		}
		my $marker = $citation->getMarker();
		if (!defined $marker) {
		    $marker = $citation->buildAuthYearMarker();
		    $citation->setMarker($marker);
		}
########## modified by Nick Friedrich
### getCitationContext returns contexts and the position of the contexts
		my ($rContexts, $rPositions) =
		    ParsCit::CitationContext::getCitationContext($rNormBodyText,
								 $marker);
		foreach my $context (@{$rContexts}) {
		    $citation->addContext($context);
			my $position = shift @{$rPositions};
			$citation->addPosition($position);
##########
		}
		push @validCitations, $citation;
	    }
	} else {
	    $status = -1;
	    $msg = "Mismatch between expected citations and cite info";
	}
    }

    unlink($tmpFile);
    unlink($outFile);

    return ($status, $msg, \@validCitations,
	    $rBodyText, $citeFile, $bodyFile);

} # extractCitationsImpl


sub buildXMLResponse {
    my ($rCitations) = @_;
    my $l_algName = $ParsCit::Config::algorithmName;
    my $l_algVersion = $ParsCit::Config::algorithmVersion;
    cleanXML(\$l_algName);
    cleanXML(\$l_algVersion);

    my $xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" .
      "<algorithm name=\"$l_algName\" " .
	"version=\"$l_algVersion\">\n";
    $xml .= "<citationList>\n";

    foreach my $citation (@$rCitations) {
	$xml .= $citation->toXML();
    }

    $xml .= "</citationList>\n";
    $xml .= "</algorithm>\n";

    return \$xml;

} # buildXMLResponse


sub writeSplit {
    my ($textFile, $rCiteText, $rBodyText) = @_;

    my $citeFile = changeExtension($textFile, "cite");
    my $bodyFile = changeExtension($textFile, "body");

    if (open(OUT, ">$citeFile")) {
	binmode OUT, ":utf8";
	print OUT $$rCiteText;
	close OUT;
    } else {
	print STDERR "Could not open .cite file for writing: $!\n";
    }

    if (open(OUT, ">$bodyFile")) {
	binmode OUT, ":utf8";
	print OUT $$rBodyText;
	close OUT;
    } else {
	print STDERR "Could not open .body file for writing: $!\n";
    }

    return ($citeFile, $bodyFile);

} # writeSplit


sub changeExtension {
    my ($fn, $ext) = @_;
    unless ($fn =~ s/^(.*)\..*$/$1\.$ext/) {
	$fn .= ".$ext";
    }
    return $fn;

} # changeExtension


1;
