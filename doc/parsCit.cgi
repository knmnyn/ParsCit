#!/usr/bin/perl -w
# -*- cperl -*-
=head1 NAME

parsCit.cgi

=head1 SYNOPSYS

 RCS:$Id: parsCit.cgi,v 1.1 2004/12/23 18:03:11 min Exp min $

=head1 DESCRIPTION

=head1 HISTORY

 ORIGIN: created from templateApp.pl version 3.4 by Min-Yen Kan <kanmy@comp.nus.edu.sg>

 RCS:$Log: parsCit.cgi,v $

=cut
require 5.0;

use CGI;
use CGI::Carp;

use File::Temp;
use HTTP::Message;
use LWP::UserAgent;

use Getopt::Std;
use LWP::Simple qw(!head);

### USER customizable section
my $tmpfile .= $0; $tmpfile =~ s/[\.\/]//g;
$tmpfile .= $$ . time;
if ($tmpfile =~ /^([-\@\w.]+)$/) { $tmpfile = $1; }                 # untaint tmpfile variable
$tmpfile = "/tmp/" . $tmpfile;
$0 =~ /([^\/]+)$/; my $progname = $1;
my $outputVersion = "1.0";
my $installDir = "/home/wing.nus/services/parscit/tools";
#my $installDir = "/home/lmthang/public_html/parsCit";
my $libDir = "$installDir/lib/";
my $logFile = "$libDir/cgiLog.txt";
my $seed = $$;
my $debug = 0;
my $loadThreshold = 2;
my $internalKey = "wing"; # Thang: to bypass load check
### END user customizable section

$| = 1;								    # flush output

### Ctrl-C handler
sub quitHandler {
print STDERR "\n# $progname fatal\t\tReceived a 'SIGINT'\n# $progname - exiting cleanly\n";
exit;
}

### HELP Sub-procedure
sub Help {
print STDERR "usage: $progname -h\t\t\t\t[invokes help]\n";
print STDERR "       $progname -v\t\t\t\t[invokes version]\n";
print STDERR "       $progname [-q] filename(s)...\n";
print STDERR "Options:\n";
print STDERR "\t-q\tQuiet Mode (don't echo license)\n";
print STDERR "\n";
print STDERR "Will accept input on STDIN as a single file.\n";
print STDERR "\n";
}

### VERSION Sub-procedure
sub Version {
if (system ("perldoc $0")) {
die "Need \"perldoc\" in PATH to print version information";
}
exit;
}

sub License {
print STDERR "# Copyright 2008 \251 by Min-Yen Kan\n";
}

my $q   = new CGI;
# Maximum file size, 128MB
$CGI::POST_MAX = 1024 * 1024 * 10;
# We don't accept "anything"
my $safe_filename_characters = "a-zA-Z0-9_.-";

print "Content-Type: text/html\n\n";
printHeader();

# check load if possible to do demo
if ($q->param('key') ne $internalKey && loadTooHigh()) {
printLoadTooHigh();
exit;
}

###
### MAIN program
###

my $filename = "/tmp/$seed\.inputFile";

my $message = "";
my $demo = 0;

#my $parsHed = ($q->param('ParsHed') eq "on") ? 1 : 0;
#my $parsCit = ($q->param('ParsCit') eq "on") ? 1 : 0;
#my $parsHedModel = ($q->param('ParsHedModel') eq "1") ? "line-level" : "token-level"; # Added by Thang (v090625) for switching between old and new models
my $option = $q->param('ParsCitOptions');

if ($q->param('ping') ne "") {
## Ping web service up
my $cmd = "nice ./ParsCitClient.rb -a status";
print "Web service ping request initiated\n<BR>";
chdir ("$installDir/bin");
print "<pre>\n";
my @lines = `$cmd`;
print @lines;
print "</pre>\n";
if (${?} == 0 && grep(/extract_citations/,@lines)) {
print "Yay! Web service is up.\n<BR>";
} else {
print "Web service for extracting citations is down.  Try again later.\n<BR>";
}
print "[ <A HREF=\"index.html\">Back to ParsCit Home Page</A> ]\n";
printTrailer();
logMessage("# Web service ping");
exit;

## Try Demo 1
} elsif (($q->param('urlfile') ne "") and ($q->param('demo') == "1")) { # M1) get input from url
getstore ($q->param('urlfile'), $filename);
$inputMethod = "URL";
$message = "Demo 1: (whole file):\n  Input: $inputMethod\n";
$demo = 1;
} elsif (($q->param('datafile') ne "") and ($q->param('demo') == "1")) { 	# M2) get input from uploaded text file
# Copy a binary file to somewhere safe
open (OUTFILE,">$filename");
while ($bytesread = read($q->param('datafile'),$buffer,1024)) {
print OUTFILE $buffer;
}
close (OUTFILE);
$inputMethod = "upload";
$message = "Demo 1 (whole file):\n  Input: $inputMethod \n";
$demo = 1;
} elsif (($q->param('textfile') ne "") and ($q->param('demo') == "1")) { # M3) by text area
open (OUTFILE,">$filename");
print OUTFILE $q->param('textfile');
close (OUTFILE);

$inputMethod = "text field";
$message = "Demo 1: (whole file):\n  Input: $inputMethod\n";
$demo = 1;

} elsif (($q->param('urlfile') ne "") and ($q->param('demo') == "2")) { # M1) get input from url

# Please be patient
printLoader();

getstore ($q->param('urlfile'), $filename);
$inputMethod = "URL";
$message = "Demo 2: (whole file):\n  Input: $inputMethod\n";
$demo = 2;
} elsif (($q->param('datafile') ne "") and ($q->param('demo') == "2")) { 	# M2) get input from uploaded text file

# Please be patient
printLoader();

# Copy a binary file to somewhere safe
open (OUTFILE,">$filename");
while ($bytesread = read($q->param('datafile'),$buffer,1024)) {
print OUTFILE $buffer;
}
close (OUTFILE);
$inputMethod = "upload";
$message = "Demo 2 (whole file):\n  Input: $inputMethod \n";
$demo = 2;
} elsif (($q->param('textfile') ne "") and ($q->param('demo') == "2")) { # M3) by text area

# Please be patient
printLoader();

open (OUTFILE,">$filename");
print OUTFILE $q->param('textfile');
close (OUTFILE);

$inputMethod = "text field";
$message = "Demo 2: (whole file):\n  Input: $inputMethod\n";
$demo = 2;
} elsif (($q->param('pdffile') ne "") and ($q->param('demo') == "2")) { # M4) uploaded pdf
	# This file works but becomes too messy, this part is added by Do Hoang Nhat Huy

	# Please be patient
	printLoader();

	# Storage
	my $upload_dir  = "/home/wing.nus/tmp";
	my $htmp  = File::Temp->new(DIR => $upload_dir);
	# Get the temporary unique filename
	my $ppath = $htmp->filename;
	
	my $buf = undef;
	# Save the uploaded file
	open my $output_handle, ">", $ppath or die "$!"; binmode $output_handle;
	while (read($q->param( 'pdffile' ), $buf, 1024)) { print $output_handle $buf; }
	close $output_handle;	

	# Dont understand
	system("chmod +rw $ppath");

	if (Verify( $ppath )) {
		my $ua       = LWP::UserAgent->new();
		my $response = $ua->post( "http://wing.comp.nus.edu.sg/parsCit/upload.cgi",
								  'Accept'			=> "text/xml;q=0.9,*/*;q=0.8",
								  'Accept-Encoding'	=> "gzip, deflate",
								  'Accept-Charset'	=> "ISO-8859-1,utf-8;q=0.7,*;q=0.7",
								  'Content-Type'	=> "multipart/form-data",
								  'Content'			=> [ 'content' => [$ppath] ]);

		my $ocontent = $response->decoded_content('default_charset'=>'utf8');
	
		open OUTFILE, ">$filename";
		print OUTFILE $ocontent;
		close OUTFILE;

		if (Verify( $filename )) {
			$inputMethod = "upload";
			$message = "Demo 2 (whole file):\n  Input: $inputMethod \n";
			$demo = 2;
		} else {
			## Fail to ocr 
  			print "<script type='text/javascript'> document.getElementById('background').style.display = 'none' </script>";
			print "<P>Fail to ocr your pdf.  Please <A HREF=\"index.html\">return to the ParsCit home page</A> to try again.\n";
			printTrailer();
			exit;
		}
	} else {
		## Fail to upload
  		print "<script type='text/javascript'> document.getElementById('background').style.display = 'none' </script>";
		print "<P>Fail to save your pdf.  Please <A HREF=\"index.html\">return to the ParsCit home page</A> to try again.\n";
		printTrailer();
		exit;
	}

## Try Demo 3 
} elsif (($q->param('urllines') ne "") and ($q->param('demo') == "3")){ # M1) get input from url
getstore ($q->param('urllines'), $filename);
$inputMethod = "URL";
$message = "Demo 3: (line set):\n  Input: $inputMethod\n";
$demo = 3;
} elsif (($q->param('datalines') ne "")  and ($q->param('demo') == "3"))  { # M2) get urls from uploaded text file
# Copy a binary file to somewhere safe
open (OUTFILE,">$filename");
while ($bytesread = read($q->param('datalines'),$buffer,1024)) {
print OUTFILE $buffer;
}
close (OUTFILE);
$inputMethod = "upload";
$message = "Demo 3 (line set):\n  Input: $inputMethod \n";
$demo = 3;
} elsif (($q->param('textlines') ne "")  and ($q->param('demo') == "3")) { # M3) by text area

open (OUTFILE,">$filename");
print OUTFILE $q->param('textlines');
close (OUTFILE);
$inputMethod = "text field";
$message = "Demo 3: (line set):\n  Input: $inputMethod\n";
$demo = 3;
} else {
## Oops, no input?
print "<P>You must provide some input data.  Please <A HREF=\"index.html\">return to the ParsCit home page</A> to try again.\n";
printTrailer();
logMessage("# Demo: None selected\n  Input: <no data>\n  Output: <no data>\n");
exit;
}

my $inputBuf = "";
open (IF,$filename) || die;
while (<IF>) { $inputBuf .= $_; }
close $filename;

my $cmd = "";
my $outputBuf = "";
if ($demo == 1 ) {		# run demo 1
  # Thang v101101: call BiblioScript
  biblioScript($option, $q, $filename, "all");

  $cmd = "nice ./citeExtract.pl ";

  if ($option == 1){
    $cmd .= "-m extract_citations";
  }
  elsif ($option == 2){
    $cmd .= "-m extract_header";
  }
  elsif ($option ==3){
    $cmd .= "-m extract_meta";
  }
  elsif ($option == 4){
    $cmd .= "-m extract_section";
  }
  elsif ($option == 5){
    $cmd .= "-m extract_all";
  }

  $cmd .= " $filename";
  print "Executing <B>$cmd</B>.\n";
  print "Input Method: <B>$inputMethod</B>.";
  chdir ("$installDir/bin");
  print "<BR>[ <A HREF=\"javascript:toggleLayer('hidden1')\">Show XML output</A> ]";
  print "<DIV ID=\"hidden1\" CLASS=\"hidden\" STYLE=\"display:none;\"><PRE>";
  $outputBuf = `$cmd`;
  print CGI::escapeHTML($outputBuf);
  print "</PRE></DIV>";
} elsif ($demo == 2) {
  $cmd = "nice ./citeExtract.pl -i xml -a ";

  if ($option == 1){
    $cmd .= "-m extract_citations";
  }
  elsif ($option == 2){
    $cmd .= "-m extract_header";
  }
  elsif ($option ==3){
    $cmd .= "-m extract_meta";
  }
  elsif ($option == 4){
    $cmd .= "-m extract_section";
  }
  elsif ($option == 5){
    $cmd .= "-m extract_all";
  }

  chdir ("$installDir/bin");
  $cmd .= " $filename";
  $outputBuf = `$cmd`;

  # Thang v101101: call BiblioScript
  biblioScript($option, $q, $filename, "xml");

  # print "Executing <B>$cmd</B>.\n";
  print "Input Method: <B>$inputMethod</B>.";
  print "<BR>[ <A HREF=\"javascript:toggleLayer('hidden1')\">Show XML output</A> ]";
  print "<DIV ID=\"hidden1\" CLASS=\"hidden\" STYLE=\"display:none;\"><PRE>";
  print CGI::escapeHTML($outputBuf);
  print "</PRE></DIV>";

} elsif ($demo == 3) {
  # Thang v101101: call BiblioScript
  biblioScript(1, $q, $filename, "ref");

  $cmd = "./parseRefStrings.pl $filename";
  print "Executing <B>$cmd</B>.\n";
  print "Input Method: <B>$inputMethod</B>.";
  chdir ("$installDir/bin");
  print "<BR>[ <A HREF=\"javascript:toggleLayer('hidden1')\">Show XML output</A> ]";
  print "<DIV ID=\"hidden1\" CLASS=\"hidden\" STYLE=\"display:none;\"><PRE>";
  $outputBuf = `$cmd`;
  print CGI::escapeHTML($outputBuf);
  print "</PRE></DIV>";
} else {
  print "<P>Invalid demo type selected\n";
  print "[ <A HREF=\"index.html\">Back to ParsCit Home Page</A> ]\n";
  printTrailer();
  logMessage("# Demo: Incorrected selected\n");
  exit;
}

if ($option == 5) {
  print "<BR>[ <A HREF=\"javascript:toggleLayer('hidden2')\">Show SectLabel output</A> ]";
  print "<DIV ID=\"hidden2\" STYLE=\"display:none;\"><PRE>";
  print (processSections($outputBuf));
  print "</DIV>";
} elsif ($option == 4) {
  print "<BR>[ <A HREF=\"javascript:toggleLayer('hidden2')\">Show SectLabel output</A> ]";
  print "<DIV ID=\"hidden2\" STYLE=\"display:'';\"><PRE>";
  print (processSections($outputBuf));
  print "</DIV>";
}
if ($option == 5 || $option == 2) { 
  print "<BR>[ <A HREF=\"javascript:toggleLayer('hidden3')\">Show ParsHed output</A> ]";
  print "<DIV ID=\"hidden3\"  STYLE=\"display:'';\">";
  print (processHeader($outputBuf)); 	
  print "</DIV>";
}
if ($option == 5 || $option == 1 || $demo == 2 || $demo == 3) { 
  print "<BR>[ <A HREF=\"javascript:toggleLayer('hidden4')\">Show ParsCit output</A> ]";
  print "<DIV ID=\"hidden4\" STYLE=\"display:'';\">";
  print (processCitations($outputBuf, $filename)); 
  print "</DIV>";
}

if ($demo == 2) {
	print "<BR>[ <A HREF=\"javascript:toggleLayer('hidden5')\">Show Enlil output</A> ]";
	print "<DIV ID=\"hidden5\" STYLE=\"display:'';\">";
	print (processEnlil($outputBuf, $filename)); 
	print "</DIV>";
}

# remove temporary files
`rm -f /tmp/$seed.*`;

logMessage("  Input: $inputBuf\n  Output: $outputBuf\n\n");
print "<br/>[ <A HREF=\"index.html\">Back to ParsCit Home Page</A> ]\n";
printTrailer();

###
### END of main program
###

# Thang v101101: incorporate BiblioScript
sub biblioScript {
  my ($option, $q, $fileName, $inputFormat) = @_;

  my $tmpDir = "/tmp/".newTmpFile();
  if($option =~ /^(1|3|5)$/) {# citations requested
    # get export types (selected checkboxes)
    my @exportTypes = ();
    foreach my $type ("ads", "bib", "end", "isi", "ris", "wordbib"){
      #print "Check box $type$demo \"".$q->param("$type$demo")."\"</BR>";
      if($q->param("$type$demo") eq "on"){
        push(@exportTypes, $type);
      }
    }

    my $size = scalar(@exportTypes);
    if($size > 0){
      chdir ("$installDir/bin");

      # call to BiblioScript
      my $format = $exportTypes[0];
      $cmd = "./BiblioScript/biblio_script.sh -q -i $inputFormat -o $format $fileName $tmpDir";
      system($cmd);

      # reuse the MODS file generated in the first call
      for(my $i = 1; $i<$size; $i++){
        $format = $exportTypes[$i];
        $cmd = "./BiblioScript/biblio_script.sh -q -i mods -o $format $tmpDir/parscit_mods.xml $tmpDir";
        system($cmd);
      }

	  # Remove the loader
	  print "<script type='text/javascript'> document.getElementById('background').style.display = 'none' </script>";

      # get the output
      foreach $format(@exportTypes){
        open(BIBLIO, "<:utf8", "$tmpDir/parscit.$format");
        my @lines = <BIBLIO>;
        my $outputBuf .= join("", @lines);  
        close(BIBLIO);

        print "[ <A HREF=\"javascript:toggleLayer('$format')\">Show $format</A> ]";
        print "<DIV ID=\"$format\" CLASS=\"hidden\" STYLE=\"display:none;\"><PRE>";
        print CGI::escapeHTML($outputBuf);
        print "</PRE></DIV>";
      }
      print "</BR></BR>";
    }
  }

  system("rm -rf $tmpDir");
}

sub loadTooHigh {
	my $load = `uptime`;
	
	$load =~ /load average: ([\d.]+)/i;
	$load = $1;

	print "Load on server: $load<br/>";
	if ($load > $loadThreshold) { return 1; } else { return 0; }
}

sub printHeader {
  print <<END;
<HTML><HEAD><TITLE>ParsCit: An open-source CRF Reference String Parsing Package</TITLE>
<LINK REL="stylesheet" type="text/css" href="parsCit.css" />
END
  printDivFunction();
  printTooltipFunction();
  print "</HEAD><BODY>";
}

sub printTrailer {
  print "<HR><H5>Executed at " . localtime(time) . " for " . $q->remote_addr() . "\n";
  print "</BODY></HTML>";
}

sub printLoadTooHigh {
  print <<END;
<P>Sorry, the load on this machine is currently too high.  Public demos are only run when computing load is available.  <A HREF="index.html">Please try back again later</A>.  Thanks!
END
}

sub logMessage {
  my $message = shift @_;
  open (LOGFILE, ">>$logFile") || print "# $progname fatal\t\tCouldn't open logfile file \"$logFile\"";
  print LOGFILE "# Executed for REMOTE_ADDR " . $q->remote_addr() . " at " . localtime(time) . "\n";
  print LOGFILE $message;
  print LOGFILE "####### End " . $q->remote_addr() . " at " . localtime(time) . "\n";
  close (LOGFILE);
}

sub processHeader {
  my $isHeader = 0;
  my $input = shift @_;
  my $output = "<P>";
  my @lines = split (/\n/,$input);
  for (my $i = 0; $i <= $#lines; $i++) {
  	if ($lines[$i] =~ /<algorithm name="ParsHed".+>/) {$isHeader = 1;}
    if ($isHeader == 1 && $lines[$i] =~ /<\/algorithm>/) { last; }
    if ($isHeader == 1 && $lines[$i] =~ /^<(author|title|affiliation|address|email|abstract)[^>]+>(.+)/g) {
      if ($1 eq "author") { $output .= "<BR>"; }
      $output .= "$1: <span class=\"$1\">$2</span><BR>";
    }
  }
  $output;
}

sub processSections {
  my $isSection = 0;
  my $input = shift @_;
  my @lines = split (/\n/,$input);
  my $output = "<P>";
  my $label = "";
  my $content = "";
  for (my $i = 0; $i <= $#lines; $i++) {
    if ($lines[$i] =~ /<algorithm name="SectLabel".+>/) {$isSection = 1;}
    if ($isSection == 1 && $lines[$i] =~ /<\/algorithm>/) { last; }
    if ($isSection == 1) {
      if ($lines[$i] =~ /^<([a-zA-Z]+?) confidence/) {
        $label =  $1;
        if ($label eq "sectionHeader") {
          if($lines[$i] =~/genericHeader=\"(.+?)\"/) {
            $label = $label . " - Generic Header : " . $1;	
          }
        }
      } elsif ($label ne "" and $lines[$i] =~ /<\/([a-zA-Z]+)>/) {
        $output .= "<span class=\"$label\" onmouseover=\"tooltip(\'$label\')\" onmouseout=\"exit()\">$content</span>"; 
        $content = "";
      } else {
        $content .= $lines[$i] . "<br/>";
      }				
    }
  }
  $output .= "</P>";
  $output;
}



sub processEnlil {
  my $isSection = 0;
  my $input = shift @_;
  my @lines = split (/\n/,$input);
  my $output = "<P>";
  my $label = "";
  my $content = "";
  my $class = 1;
  for (my $i = 0; $i <= $#lines; $i++) {
    # Trim
	$lines[$i] =~ s/^\s+|\s+$//g;

    if ($lines[$i] =~ /<algorithm name="AAMatching".+>/) {$isSection = 1;}
    if ($isSection == 1 && $lines[$i] =~ /<\/authors>/) { last; }
    if ($isSection == 1) {
      if ($lines[$i] =~ /<fullname[^>]*?>([^<]+?)<\/fullname>/) {
        $content = $1;

		$class += 1;

        $output .= "<span class=\"author\" onmouseover=\"tooltip(\'author\')\" onmouseout=\"exit()\">$content</span><br/>"; 
        $content = "";

      } elsif ($lines[$i] =~ /<institutions[^>]*?>([^<]+?)<\/institution>/) {
		
      } elsif ($lines[$i] =~ /<institution[^>]*?>([^<]+?)<\/institution>/) {
        $content = $1;

        $output .= "&nbsp;&nbsp;&nbsp;&nbsp;<span class=\"affiliation\" onmouseover=\"tooltip(\'affiliation\')\" onmouseout=\"exit()\">$content</span><br/>"; 
        $content = "";
      }				
    }
  }
  $output .= "</P>";
  $output;
}



sub processCitations {
  my $input = shift @_;
  my $filename = shift @_;
  my $rawStringBuf = "";
  my $contextsBuf = "";
  my $contextIndex = 0;
  my $fieldsBuf = "";
  my $output = "";
  my @lines = split (/\n/,$input);
  my $index = 0;

  open (IIF, $filename) || die "# $progname fatal\t\tCan't open \"$filename\"!";
  for (my $i = 0; $i <= $#lines; $i++) {
    if ($lines[$i] =~ /^<\/citation>/) {
      $index++;
      if ($rawStringBuf eq "") {
	$rawStringBuf = <IIF>;
      }
      $output .= "<LI>$rawStringBuf<BR>\n";
      if ($contextsBuf ne "") { $output .= "<div class=\"contexts\">$contextsBuf</div>\n<BR>"; }
      $output .= "$fieldsBuf<P>&nbsp;</P></LI>";
      # reset
      $rawStringBuf = "";
      $contextsBuf = "";
      $contextIndex = 0;
      $fieldsBuf = "";
    } elsif ($lines[$i] =~ /^<rawString>(.+)<\/rawString>$/) {
      $rawStringBuf = $1;
    } elsif ($lines[$i] =~ /^<context position=\"(\d+)\"[^>]+>(.+)<\/context>$/) {
      $contextIndex++;
      $contextsBuf .= "<P>Context $contextIndex at byte $1: ...$2...</P>";
    } elsif ($lines[$i] =~ /^<(author|date|title|booktitle|note|volume|issue|number|pages|journal|location|marker)>(.+)/) {
      if ($1 eq "marker") { $fieldsBuf = "<span class=\"$1\">$2</span>: \n$fieldsBuf"; }
      else { $fieldsBuf .= "<span class=\"$1\" onmouseover=\"tooltip(\'$1\')\" onmouseout=\"exit()\">$2</span>\n"; }
    }
  };
  $output = "<OL>\n$output\n</OL>\n";
  $output = "<P>" . printTypes() . $output . printTypes() . "</P>";
  close (IIF);
  $output;
}

sub printTypes {
  my $buf = "Key: ";
  foreach my $type ("author","booktitle","date","editor","institution","journal","location","note","pages","publisher","tech","title","volume","issue","number","marker") {
    $buf .= "<SPAN CLASS=\"$type\">$type</SPAN> ";
  }
  $buf .= "<BR>\n";
  $buf;
}

sub printDivFunction {
  # from http://www.netlobo.com/div_hiding.html on Thu Dec 20 00:30:50 SGT 2007
print <<FUNCTION;
<script type="text/javascript">
function toggleLayer( whichLayer )
  {
  var elem, vis;
  if( document.getElementById ) // this is the way the standards work
    elem = document.getElementById( whichLayer );
  else if( document.all ) // this is the way old msie versions work
      elem = document.all[whichLayer];
  else if( document.layers ) // this is the way nn4 works
    elem = document.layers[whichLayer];
  vis = elem.style;
  // if the style.display value is blank we try to figure it out here
  if(vis.display==''&&elem.offsetWidth!=undefined&&elem.offsetHeight!=undefined)
    vis.display = (elem.offsetWidth!=0&&elem.offsetHeight!=0)?'block':'none';
  vis.display = (vis.display==''||vis.display=='block')?'none':'block';
}
</script>
FUNCTION
}

sub printTooltipFunction {
  # from http://lixlpixel.org/javascript-tooltips/ on Thu Dec 20 14:32:36 SGT 2007
print <<TOOLTIP;
<script type="text/javascript">
// position of the tooltip relative to the mouse in pixel //
var offsetx = 12;
var offsety =  8;

function newelement(newid)
{
    if(document.createElement)
    {
        var el = document.createElement('div');
        el.id = newid;
        with(el.style)
        {
            display = 'none';
            position = 'absolute';
        }
        el.innerHTML = '&nbsp;';
        document.body.appendChild(el);
    }
}
var ie5 = (document.getElementById && document.all);
var ns6 = (document.getElementById && !document.all);
var ua = navigator.userAgent.toLowerCase();
var isapple = (ua.indexOf('applewebkit') != -1 ? 1 : 0);
function getmouseposition(e)
{
    if(document.getElementById)
    {
        var iebody=(document.compatMode &&
        	document.compatMode != 'BackCompat') ?
        		document.documentElement : document.body;
        pagex = (isapple == 1 ? 0:(ie5)?iebody.scrollLeft:window.pageXOffset);
        pagey = (isapple == 1 ? 0:(ie5)?iebody.scrollTop:window.pageYOffset);
        mousex = (ie5)?event.x:(ns6)?clientX = e.clientX:false;
        mousey = (ie5)?event.y:(ns6)?clientY = e.clientY:false;

        var lixlpixel_tooltip = document.getElementById('tooltip');
        lixlpixel_tooltip.style.left = (mousex+pagex+offsetx) + 'px';
        lixlpixel_tooltip.style.top = (mousey+pagey+offsety) + 'px';
    }
}
function tooltip(tip)
{
    if(!document.getElementById('tooltip')) newelement('tooltip');
    var lixlpixel_tooltip = document.getElementById('tooltip');
    lixlpixel_tooltip.innerHTML = tip;
    lixlpixel_tooltip.style.display = 'block';
    lixlpixel_tooltip.style.background = 'white';
    lixlpixel_tooltip.style.border = '1px solid';
    document.onmousemove = getmouseposition;
}
function exit()
{
    document.getElementById('tooltip').style.display = 'none';
}
</script>
TOOLTIP
}

sub printLoader {
# Ugly
print <<LOADER
<div id="background"><center><img src="loader.gif"><br /> Please be patient &hellip;</center></div>
LOADER
}

# Thang v101101: method to generate tmp file name
sub newTmpFile {
  my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  chomp($tmpFile);
  return $tmpFile;
}

sub Verify
{
	my ($inFile) = @_;
	
	my $status = 1;
	if(!-e $inFile)
	{
		$status = 0;
	} 
	else
	{
		my $numLines = `wc -l < $inFile`;
		chomp($numLines);
		if($numLines == 0)
		{
			print STDERR "! File $inFile has no content\n";
			$status = 0;
		}
	}

	return $status;
}

