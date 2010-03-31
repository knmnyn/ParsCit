package SectLabel::Tr2crfpp;
#
# Created from templateAppl.pl version 3.4 by Min-Yen Kan <kanmy@comp.nus.edu.sg>.
# Modified by Isaac Councill on 7/20/07: wrapped the code as a package for use by
# an external controller.
#
# Copyright 2005 \251 by Min-Yen Kan (not sure what this means for IGC edits, but
# what the hell -IGC)
#

use strict 'vars';
use utf8;
use FindBin;
use SectLabel::Config;
use Encode ();

### USER customizable section

my $crf_test = $SectLabel::Config::crf_test;
$crf_test = "$FindBin::Bin/../$crf_test";
### END user customizable section

my %dict = ();
my %funcWord = ();

my %keywords = (); 
my %bigrams = ();
my %trigrams = ();
my %fourthgrams = ();

# list of tags trained in parsHed
# those with value 0 do not have frequent keyword features
my $allTags = $SectLabel::Config::tags;

my %config = (
	      '1token' => 0,
	      '2token' => 0,
	      '3token' => 0,
	      '4token' => 0,

	      # token-level features
	      'parscit' => 0, # use all Parscit original features
	      'parscit_char' => 0, # parscit char features

	      'tokenCapital' => 0,
	      'tokenNumber' => 0,
	      'tokenName' => 0,
	      'tokenPunct' => 0,
	      'tokenKeyword' => 0,
	      
	      '1gram' => 0,
	      '2gram' => 0,
	      '3gram' => 0,
	      '4gram' => 0,

	      'lineNum' => 0,
	      'linePunct' => 0,
	      'linePos' => 0,
	      'lineLength' => 0,
	      'lineCapital' => 0,

	      # pos
	      'xmlLoc' => 0,
	      'xmlAlign' => 0,
	      'xmlIndent' => 0,
	      
	      # format
	      'xmlFontSize' => 0,
	      'xmlBold' => 0,
	      'xmlItalic' => 0,
	      
	      # object
	      'xmlDd' => 0,
	      'xmlCell' => 0,
	      'xmlBullet' => 0,

	      'xmlPara' => 0,
	      'xmlStructure' => 0,

	      # unused
	      'xmlFontFace' => 0,
	      'xmlFontFaceChange' => 0,
	      'xmlFontSizeChange' => 0,
	      'xmlSpace' => 0,
	      
	      # linking features
	      'link-xmlAlign' => 0,
	      'link-xmlIndent' => 0,

	      'link-xmlFontSize' => 0,
	      'link-xmlBold' => 0,
	      'link-xmlItalic' => 0,
	      
	      'link-xmlDd' => 0,
	      'link-xmlCell' => 0,
	      'link-xmlBullet' => 0,

	      'link-xmlPara' => 0,
	      'link-xmlStructure' => 0,
	     );

my %tagMap = (
	      "LineLevel" => "UL",
	      "xml" => "UX",
	      "1token" => "U1",
	      "2token" => "U2",
	      "3token" => "U3",
	      "4token" => "U4",
	      "1gram" => "U5",
	      "2gram" => "U6",
	      "3gram" => "U7",
	      "4gram" => "U8",
	      
	      "Capital" => "U9",
	      "Number" => "UA0",
	      "Punct" => "UA1",
	      "Func" => "UA2",
	      "Binary" => "UA3",
	     );

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

sub initialize {
  my ($dictFile, $funcFile, $configFile) = @_;

#  print STDERR "Dict file = $dictFile\n";
#  print STDERR "Func file = $funcFile\n";
  readDict($dictFile);
  loadListHash($funcFile, \%funcWord);
  if(defined $configFile && $configFile ne ""){
    loadConfigFile($configFile, \%config);
  } else {
    die "!defined $configFile || $configFile eq \"\"\n";
  }

#  if($kFile ne "") { readKeywordDict($kFile, \%keywords); }
#  if($biFile ne "") { readKeywordDict($biFile, \%bigrams); }
#  if($triFile ne "") { readKeywordDict($triFile, \%trigrams); }
#  if($fourthFile ne "") { readKeywordDict($fourthFile, \%fourthgrams); }
}

## Entry point called by sectLabel/tr2crfpp.pl
sub tr2crfpp {
  my ($inFile, $outFile, $dictFile, $funcFile, $configFile, $isGenerateTemplate) = @_; #$kFile, $biFile, $triFile, $fourthFile
  if(!defined $isGenerateTemplate){
    die "Die: Tr2crfpp::tr2crfpp - undefined isGenerateTemplate\n";
  }

  initialize($dictFile, $funcFile, $configFile);

  # File IOs
  open (IF, "<:utf8", $inFile) || die "# crash\t\tCan't open \"$inFile\"";
  my @lines = <IF>;
  processData(\@lines, $outFile, $isGenerateTemplate);

  close (IF);
}

## Entry point called by SectLabel::Controller
sub extractTestFeatures {
  my ($textLines, $filename, $dictFile, $funcFile, $configFile, $isDebug) = @_;
  my $tmpfile = buildTmpFile($filename);

  initialize($dictFile, $funcFile, $configFile);

  my $isGenerateTemplate = 0;
  processData($textLines, $tmpfile, $isGenerateTemplate, $isDebug);

  return $tmpfile;
}

sub processData {
  my ($lines, $outFile, $isGenerateTemplate, $isDebug) = @_;

  open (OF, ">:utf8", $outFile) || die "# crash\t\tCan't open \"$outFile\"";

  my %countMap = ();
  getDocLineCounts($lines, \%countMap);
  my $numDocs = scalar(keys %countMap);

  my $index = -1;
  my $isAbstract = 0;
  my $isIntro = 0;
  my $docId = 0;
  my $numLines = $countMap{$docId};
  my $tag = "noTag";

  if($isDebug){
    print STDERR "numLines = $numLines\n";
  }

  my $xmlFeature = "";
  foreach my $line (@{$lines}) {
    chomp($line);
    $index++;
    
#    if ($line =~ /^\#/) { next; } # skip comments
    if ($line =~ /^\s*$/) { # blank lines, new documents
      print OF "\n";

      # reset
      $index = -1;
      $isAbstract = 0;
      $isIntro = 0;
      $docId++;
      $numLines = $countMap{$docId};
      next; 
    } else {
      if ($line =~ /^(.+?) \|\|\| (.+)$/) {
	$tag = $1;
	$line = $2;
	if(!defined $allTags->{$tag}){
#	  print STDERR "#! Warning: tag \"$tag\" not defined - skip \"$line\"\n";
	  next;
	}
      }

      if ($line =~ /^(.+) \|XML\| (.+?)$/) {
	$line = $1;
	$xmlFeature = $2;
      }

      if($line =~ /abstract/i){
	$isAbstract = 1;
      } elsif($line =~ /introduction/i){
	$isIntro = 1;
      } else {
	if($isAbstract == 1){
	  $isAbstract = 2;
	}
	if($isIntro == 1){
	  $isIntro = 2;
	}
      }

      my @feats = ();
      my @templates = crfFeature($line, $index, $numLines, $isAbstract, $isIntro, $xmlFeature, $tag, \@feats);

      # generate CRF features
      if($isGenerateTemplate){
	$isGenerateTemplate = 0; #done generate template file
	print STDOUT join("", @templates);
      }

#      if($index == -1) {
#	last;
#      }
      print OF join (" ", @feats);
      print OF "\n";
    }
  }

  close (OF);
}

sub getDocLineCounts {
  my ($lines, $countMap) = @_;

  my $count = 0;
  my $docId = 0;
  my $flag = 0;
  foreach my $line (@{$lines}) {
    chomp($line);
    $count++;
    
    if ($line =~ /^\s*$/) { # blank lines, new documents
      $flag = 1; # more than 1 document
      $countMap->{$docId} = $count;
      
      $count = 0;
      $docId++;
    }
  }

  if($flag == 0){
    $countMap->{$docId} = $count;
  }
}
##
# Main method to extract features
## 
sub crfFeature {
  my ($line, $index, $numLines, $isAbstract, $isIntro, $xmlFeature, $tag, $feats) = @_;
  my $token = "";

  my @templates = ();
  my %featureCounts = (); # to perform feature linking

  my @tmpTokens = split(/\s+/, $line);
  #filter out empty token
  my @tokens = ();
  foreach my $token (@tmpTokens){ 
    $token =~ s/^\s+//g; # strip off leading spaces
    $token =~ s/\s+$//g; # strip off trailing spaces

    if($token ne ""){
      push(@tokens, $token);
    }
  }

  # full form: does not count in crf template file, simply for outputing purpose to get the whole line data
  my $lineFull = join("|||", @tokens);
  push(@{$feats}, "$lineFull");

  ##############################
  #### Line-level features ####
  ##############################
  generateLineFeature($line, \@tokens, $index, $numLines, $isAbstract, $isIntro, $feats, "# Line-level features\n", $tagMap{"LineLevel"}, \@templates, \%featureCounts);

  ### XML features ###
  generateXmlFeature($xmlFeature, $feats, "# Xml features\n", $tagMap{"xml"}, \@templates, \%featureCounts);

#  generateNumberFeature(\@tokens, $feats, "#number. features\n", $tagMap{"Number"}, \@templates, \%featureCounts);
  
  # keyword features
  for(my $i=1; $i<=4; $i++){
    if($config{"${i}gram"}){
      my @topTokens = ();
      getNgrams($line, $i, \@topTokens);
      generateKeywordFeature(\@topTokens, $feats, \%keywords, "# ${i}gram features\n", $tagMap{"${i}gram"}, \@templates, \%featureCounts);
    }
  }

  ##############################
  #### Token-level features ####
  ##############################
  # apply most of Parscit features
  for(my $i=1; $i<=4; $i++){
    if($config{"${i}token"}){
      generateTokenFeature(\@tokens, ($i-1), \%keywords, $feats, "#${i}token general features\n", $tagMap{"${i}token"}, \@templates, \%featureCounts);
    }
  }

  #########################
  #### Feature linking ####
  #########################
  my $i;
  if($config{"back1"}){
    featureLink(\@templates, "UA", "#constraint on first token features at -1 relative position \n", $featureCounts{$tagMap{"1token"}}->{"start"}, $featureCounts{$tagMap{"1token"}}->{"end"}, "-1");
  }
  push(@templates, "\n");

  if($config{"forw1"}){
    featureLink(\@templates, "UB", "#constraint on first token features at +1 relative position \n", $featureCounts{$tagMap{"1token"}}->{"start"}, $featureCounts{$tagMap{"1token"}}->{"end"}, "1");
  }
  push(@templates, "\n");

  # output tag
  push(@{$feats}, $tag);

  push(@templates, "# Output\nB0\n");
  return @templates;
}

sub generateXmlFeature {
  my ($xmlFeature, $feats, $msg, $label, $templates, $featureCounts) = @_;

  my @features = split(/\s+/, $xmlFeature);
  my $count = 0;
  my $type;
  foreach my $feature (@features) {
    if($feature =~ /^(xml[a-zA-Z]+)\_.+$/){
      $type = $1;
      if($config{$type}){
	push(@{$feats}, $feature);
	$count++;
      }
    } else {
      die "Die: xml feature doesn't match \"$feature\"\n";
    }
  }
  
  updateTemplate(scalar(@{$feats}), $count, $msg, $label, $templates, $featureCounts);
}

sub updateTemplate {
  my ($curSize, $numFeatures, $msg, $label, $templates, $featureCounts) = @_;

  # crfpp template
  push(@{$templates}, $msg);
  my $prevSize = $curSize - $numFeatures;
  $featureCounts->{$label}->{"start"} = $prevSize;
  $featureCounts->{$label}->{"end"} = $curSize;
  
  my $i = 0;
  for(my $j=$prevSize; $j < $curSize; $j++){
    push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  }
  push(@{$templates}, "\n");
}


# 'linePos' => 1,
# 'lineLength' => 1,
# 'lineCapital' => 1,
  

sub generateLineFeature {
  my ($line, $tokens, $index, $numLines, $isAbstract, $isIntro, $feats, $msg, $label, $templates, $featureCounts) = @_;

  # crfpp template
  push(@{$templates}, $msg);
  my $prevSize = scalar(@{$feats});
  $featureCounts->{$label}->{"start"} = $prevSize;

  # editor
  my $hasPossibleEditor =
    ($line =~ /[^A-Za-z](ed\.|editor|editors|eds\.)/) ? "possibleEditors" : "noEditors"; # Parscit feature
  push(@{$feats}, $hasPossibleEditor);
  
  if($config{"lineNum"}){
    my $word = $tokens->[0];
    my $num = "";
    if(scalar(@{$tokens}) > 1){
      $num = ($word =~ /^[1-9]\.[1-9]\.?$/) ? "posSubsec" :
	($word =~ /^[1-9]\.[1-9]\.[1-9]\.?$/) ? "posSubsubsec" :
	  ($word =~ /^\w\.[1-9]\.[1-9]\.?$/) ? "posCategory" :
	    "";
    }
    
    if($num eq ""){
      $num = ($word =~ /^[1-9][A-Za-z]\w*$/) ? "numFootnote" :
	($word =~ /^[1-9]\s*(http|www)/) ? "numWebfootnote" :
	  "lineNumOthers";
    }
    
    push(@{$feats}, $num);
  }
  
  if($config{"linePunct"}){
    my $punct = "";
    $punct = ($line =~ /@\w+\./) ? "possibleEmail" : 
      ($line =~ /(www|http)/) ? "possibleWeb" : 
	($line =~ /\(\d\d?\)\s*$/) ? "endNumbering" : 
	  "linePunctOthers";
  
    push(@{$feats}, $punct);
  }
  
  if($config{"lineCapital"}){
    my $cap = getCapFeature($tokens);
    push(@{$feats}, $cap);
  }
  
  if($config{"linePos"}){
    my $position = "POS-".int($index*8.0/$numLines);
    push(@{$feats}, $position);
  }
  
  if($config{"lineLength"}){  
    # num tokens, words
    my @tokens = split(/\s+/, $line);
    
    my $numWords = 0;
    foreach my $token (@tokens){
      if($token =~ /^\p{P}*[a-zA-Z]+\p{P}*$/){
	$numWords++;
      }
    }
    my $wordLength = 
      ($numWords >= 5) ? "5+Words" :
	"${numWords}Words";
    push(@{$feats}, $wordLength);
  }

  # for crfpp template
  my $curSize = scalar(@{$feats});
  $featureCounts->{$label}->{"end"} = $curSize;
  
  my $i = 0;
  for(my $j=$prevSize; $j < $curSize; $j++){
    push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  }
  push(@{$templates}, "\n");
}

sub generateTokenFeature {
  my ($tokens, $index, $keywords, $feats, $msg, $label, $templates, $featureCounts) = @_;

  my $numTokens = scalar(@{$tokens});
  my $token = "EMPTY";
  if($numTokens > $index){
    $token = $tokens->[$index];
  }

  # crfpp template
  push(@{$templates}, $msg);
  my $prevSize = scalar(@{$feats});
  $featureCounts->{$label}->{"start"} = $prevSize;

  # prep
  my $word = $token;
  my $wordLC = lc($token);
  my $wordNP = $token;			      # no punctuation
  $wordNP =~ s/[^\w]//g;
  if ($wordNP =~ /^\s*$/) { $wordNP = "EMPTY"; }
  my $wordLCNP = lc($wordNP);    # lowercased word, no punctuation
  if ($wordLCNP =~ /^\s*$/) { $wordLCNP = "EMPTY"; }
  
  ## lexical features
  push(@{$feats}, "TOKEN-$word"); # lexical word
  push(@{$feats}, "$wordLC");  # lowercased word
  push(@{$feats}, "$wordLCNP");  # lowercased word, no punct
  
  if($config{"parscit"}){ # Parscit char feature
    if($config{"parscit_char"}){ # Parscit char feature
      my @chars = split(//,$word);
      my $lastChar = $chars[-1];
      if ($lastChar =~ /[\p{IsLower}]/) { $lastChar = 'a'; }
      elsif ($lastChar =~ /[\p{IsUpper}]/) { $lastChar = 'A'; }
      elsif ($lastChar =~ /[0-9]/) { $lastChar = '0'; }
      push(@{$feats}, $lastChar);		       # 1 = last char

      # Thang added 02-Mar-10 this to avoid uninitialized warnning messages when using -w
      for(my $i=scalar(@chars); $i<4;$i++){
	push(@chars, '|');
      }

      push(@{$feats}, $chars[0]);		      # 2 = first char
      push(@{$feats}, join("",@chars[0..1]));  # 3 = first 2 chars
      push(@{$feats}, join("",@chars[0..2]));  # 4 = first 3 chars
      push(@{$feats}, join("",@chars[0..3]));  # 5 = first 4 chars
      
      push(@{$feats}, $chars[-1]);		       # 6 = last char
      push(@{$feats}, join("",@chars[-2..-1])); # 7 = last 2 chars
      push(@{$feats}, join("",@chars[-3..-1])); # 8 = last 3 chars
      push(@{$feats}, join("",@chars[-4..-1])); # 9 = last 4 chars
    }
  }

  ## capitalization features
  if($config{"tokenCapital"}){
    my $ortho = ($wordNP =~ /^[\p{IsUpper}]$/) ? "singleCap" :
      ($wordNP =~ /^[\p{IsUpper}][\p{IsLower}]+/) ? "InitCap" :
	($wordNP =~ /^[\p{IsUpper}]+$/) ? "AllCap" : "others";
    push(@{$feats}, $ortho);
  }

  ## number features
  if($config{"tokenNumber"}){
    my $num ;
    
    if($config{"parscit"}){
      $num = ($wordNP =~ /^(19|20)[0-9][0-9]$/) ? "year" :
	($word =~ /[0-9]\-[0-9]/) ? "possiblePage" :
	  ($word =~ /[0-9]\([0-9]+\)/) ? "possibleVol" :
	    ($wordNP =~ /^[0-9]$/) ? "1dig" :
	      ($wordNP =~ /^[0-9][0-9]$/) ? "2dig" :
		($wordNP =~ /^[0-9][0-9][0-9]$/) ? "3dig" :
		  ($wordNP =~ /^[0-9]+$/) ? "4+dig" :
		    ($wordNP =~ /^[0-9]+(th|st|nd|rd)$/) ? "ordinal" :
		      ($wordNP =~ /[0-9]/) ? "hasDig" : "nonNum";
    } else {
      $num = 
	($word =~ /^[1-9]+\.$/) ? "endDot" :
	  ($word =~ /^[1-9]+:$/) ? "endCol" :
	    
	    # Parscit features
	    ($wordNP =~ /^(19|20)[0-9][0-9]$/) ? "year" :
	      ($word =~ /[0-9]\-[0-9]/) ? "possiblePage" :
		($word =~ /[0-9]\([0-9]+\)/) ? "possibleVol" :
		  ($wordNP =~ /^[0-9]$/) ? "1dig" :
		    ($wordNP =~ /^[0-9][0-9]$/) ? "2dig" :
		      ($wordNP =~ /^[0-9][0-9][0-9]$/) ? "3dig" :
			($wordNP =~ /^[0-9]+$/) ? "4+dig" :
			  ($wordNP =~ /^[0-9]+(th|st|nd|rd)$/) ? "ordinal" :
			    ($wordNP =~ /[0-9]/) ? "hasDig" : "nonNum";
    } # end if parscit
    push(@{$feats}, $num);
  }

  ## gazetteer (names) features
  if($config{"tokenName"}){
    my $dictStatus = (defined $dict{$wordLCNP}) ? $dict{$wordLCNP} : 0;
    #      my $isInDict = ($dictStatus != 0) ? "isInDict" : "no";
    my $isInDict = $dictStatus;
    
    my ($publisherName,$placeName,$monthName,$lastName,$femaleName,$maleName);
    
    if ($dictStatus >= 32) { $dictStatus -= 32; $publisherName = "publisherName" } else { $publisherName = "no"; }
    if ($dictStatus >= 16) { $dictStatus -= 16; $placeName = "placeName" } else { $placeName = "no"; }
    if ($dictStatus >= 8) { $dictStatus -= 8; $monthName = "monthName" } else { $monthName = "no"; }
    if ($dictStatus >= 4) { $dictStatus -= 4; $lastName = "lastName" } else { $lastName = "no"; }
    if ($dictStatus >= 2) { $dictStatus -= 2; $femaleName = "femaleName" } else { $femaleName = "no"; }
    if ($dictStatus >= 1) { $dictStatus -= 1; $maleName = "maleName" } else { $maleName = "no"; }
    
    push(@{$feats}, $isInDict);		    # 13 = name status
    push(@{$feats}, $maleName);		      # 14 = male name
    push(@{$feats}, $femaleName);		    # 15 = female name
    push(@{$feats}, $lastName);		      # 16 = last name
    push(@{$feats}, $monthName);		     # 17 = month name
    push(@{$feats}, $placeName);		     # 18 = place name
    push(@{$feats}, $publisherName);	 # 19 = publisher name
  }
  
  # punctuation features
  if($config{"tokenPunct"}){
    my $punct;

    if($config{"parscit"}){
      $punct = ($word =~ /^[\"\'\`]/) ? "leadQuote" :
	($word =~ /[\"\'\`][^s]?$/) ? "endQuote" :
	  ($word =~ /\-.*\-/) ? "multiHyphen" :
	    ($word =~ /[\-\,\:\;]$/) ? "contPunct" :
	      ($word =~ /[\!\?\.\"\']$/) ? "stopPunct" :
	        ($word =~ /^[\(\[\{\<].+[\)\]\}\>].?$/) ? "braces" :
		  ($word =~ /^[0-9]{2-5}\([0-9]{2-5}\).?$/) ? "possibleVol" : "others";
    } else {
      $punct = 
	($word =~ /^[a-z]\d$/) ? "possibleVar" : # x1, x2

	  # Parscit
#	  ($word =~ /^[\"\'\`]/) ? "leadQuote" :
#	    ($word =~ /[\"\'\`][^s]?$/) ? "endQuote" :
#	      ($word =~ /\-.*\-/) ? "multiHyphen" :
		($word =~ /[\-\,\:\;]$/) ? "contPunct" :
		  ($word =~ /[\!\?\.\"\']$/) ? "stopPunct" :
		    ($word =~ /^[\(\[\{\<].+[\)\]\}\>].?$/) ? "braces" :
		      ($word =~ /^[0-9]{2-5}\([0-9]{2-5}\).?$/) ? "possibleVol" : "punctOthers";

#		  ($word =~ /^[\*\^\x{0608}\x{0708}\x{07A0}][A-Za-z]\w*$/  && $index == 0) ? "punctFootnote" :
#		  ($word =~ /^[\p{P}\p{Math_Symbol}]*\p{Math_Symbol}\p{P}\p{Math_Symbol}]*/) ? "mathSym" :
    } # end if parscit

    push(@{$feats}, $punct);
  } # end fi punct feature

  if($config{"tokenKeyword"}){
    my $keywordFea = "noKeyword";
    my $token = $word;
    $token =~ s/^\p{P}+//g; #strip out leading punctuations
    $token =~ s/\p{P}+$//g; #strip out trailing punctuations
    $token =~ s/\d/0/g; #canocalize number into "0"
    
    foreach(keys %{$allTags}){
      if($allTags->{$_} == 0) { next; };
      
      if($keywords->{$_}->{$token}){
	$keywordFea = "keyword-$_";
	last;
      }
    }

    push(@{$feats}, $keywordFea);
  }

  # for crfpp template
  my $curSize = scalar(@{$feats});
  $featureCounts->{$label}->{"end"} = $curSize;
  my $i = 0;
  for(my $j=$prevSize; $j < $curSize; $j++){
    push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  }
  push(@{$templates}, "\n");
}

sub getCapFeature {
  my ($tokens) = @_;

  my $cap = "OthersCaps";
  my $n = 0;
  my $count = 0; # non-word
  my $count1 = 0;
  my $line = "";

  # check capitalization
  my $isSkip = 0;
  for(my $i = 0; $i < scalar(@{$tokens}); $i++){
    my $token = $tokens->[$i];
    if($token =~ /^\p{P}*$/){
      next;
    }
    my @chars = split(//, $token);    
    if(scalar(@chars) < 4) { # exclude non-word or an important words such as a, an, the, on, in ...
      if(!($i == 0 && $token =~ /\d/)){ # dont' consider skip if it is the first token as numbers
	$isSkip = 1; 
      }
      next;
    } 

    if($token =~ /^[A-Z][A-Za-z]*$/){ # capitalized
      $count++;
      $line .= "$token ";
    }
    
    $n++;
  }

  if($count >0){ # consider only if at lest 1 capitalized word
    if($count == $n){
      $cap = ($isSkip) ? "Most" : "All";
      if($line =~ /[a-z]/){
	$cap .= "InitCaps";
      } else {
	$cap .= "CharCaps";
      }
      if($tokens->[0] =~ /\d/) {# first token contains number
	$cap = "Number$cap";
      } elsif($count == 1){ # two few capitalized letter to conclude any pattern
	$cap = "OthersCaps";
      }
    }
  }
  return $cap;
}

sub featureLink {
  my ($templates, $label, $msg, $start, $end, $relPos) = @_;
  my $i;

  # to constraint on last token features at $relPos relative position
  $i = 0;
  push(@{$templates}, $msg);
  for(my $j=$start; $j < $end; $j++){
    push(@{$templates}, "$label".$i++.":%x[$relPos,$j]\n");
  }
  push(@{$templates}, "\n");
}

sub generateKeywordFeature {
  my ($tokens, $feats, $keywords, $msg, $label, $templates, $featureCounts) = @_;

  # crfpp template
  push(@{$templates}, $msg);
  my $prevSize = scalar(@{$feats});
  $featureCounts->{$label}->{"start"} = $prevSize;

  foreach(keys %{$allTags}){
    if($allTags->{$_} == 0) { next; };

    my $i=0;
    for(; $i<scalar(@{$tokens}); $i++){
      if($keywords->{$_}->{$tokens->[$i]}){
	push(@{$feats}, "$_-".$tokens->[$i]);
	last;
      }
    }

    if($i==scalar(@{$tokens})){
      push(@{$feats}, "none");
    }
  }

  # for crfpp template
  my $curSize = scalar(@{$feats});
  $featureCounts->{$label}->{"end"} = $curSize;
  
  my $i = 0;
  for(my $j=$prevSize; $j < $curSize; $j++){
    push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  }
  push(@{$templates}, "\n");
}

##
# Get nGrams
##
sub getNgrams {
  my ($line, $numNGram, $nGrams) = @_;

#  $line = lc($line);

  my @tmpTokens = split(/\s+/, $line);

  #filter out empty token
  my @tokens = ();
  foreach my $token (@tmpTokens){ 
    if($token ne ""){
      $token =~ s/^\s+//g; # strip off leading spaces
      $token =~ s/\s+$//g; # strip off trailing spaces
      $token =~ s/^\p{P}+//g; #strip out leading punctuations
      $token =~ s/\p{P}+$//g; #strip out trailing punctuations
      $token =~ s/\d/0/g; #canocalize number into "0"

      if($token =~ /(\w.*)@(.*\..*)/){ #email pattern, try to normalize
	#	 $token =~ /(http:\/\/|www\.)/){
	$token = $1;
	my $remain = $2;
	$token =~ s/\w+/x/g;
	$token =~ s/\d+/0/g;
	$token .= "@".$remain;
      } 

      if($token ne ""){
	push(@tokens, $token);
      }
    }
  }

  my $count = 0;  
  for(my $i=0; $i<=$#tokens; $i++){
    if(($#tokens-$i + 1) < $numNGram) { last; }; # not enough ngrams
    my $nGram = "";
    for(my $j=$i; $j <= ($i+$numNGram-1); $j++){
      my $token = $tokens[$j];

      if($j < ($i+$numNGram-1)){
	$nGram .= "$token-";
      } else {
	$nGram .= "$token";
      }
    }

    if($nGram =~ /^\s*$/){ next; } #skip those with white spaces
    if($nGram =~ /^\d*$/){ next; } #skip those with only digits
    if($funcWord{$nGram}){ next; } #skip function words, matter for nGram = 1
    push(@{$nGrams}, $nGram);

    $count++;
    if($count == 4){
      last;
    }
  } # end while true
}

sub generateNumberFeature {
  my ($tokens, $feats, $msg, $label, $templates, $featureCounts) = @_;

  # crfpp template
  push(@{$templates}, $msg);
  my $prevSize = scalar(@{$feats});
  $featureCounts->{$label}->{"start"} = $prevSize;

  my $line = join("", @{$tokens});
  $line =~ s/\s+//g;
  my @chars = split(//, $line);

  my $count = 0;
  my $n = scalar(@chars);
  foreach(@chars){
    if(/\d/){
      $count++;
    }
  }

  my $num = "otherNum";
  if($n > 1){
    my $ratio = $count/$n;
    if($ratio >= 0.7){
      $num = "HighNum";
    } elsif($ratio >= 0.4){
     $num = "MeidumNum";
    }
  }

  push(@{$feats}, $num);
  
  # for crfpp template
  my $curSize = scalar(@{$feats});
  $featureCounts->{$label}->{"end"} = $curSize;
  
  my $i = 0;
  for(my $j=$prevSize; $j < $curSize; $j++){
    push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  }
  push(@{$templates}, "\n");
}

sub generateFuncFeature {
  my ($tokens, $feats, $msg, $label, $templates, $featureCounts) = @_;

  # crfpp template
  push(@{$templates}, $msg);
  my $prevSize = scalar(@{$feats});
  $featureCounts->{$label}->{"start"} = $prevSize;

  my $n = scalar(@{$tokens});
  my $count = 0;
  foreach my $token (@{$tokens}){
    $token =~ s/^\p{P}+//; #strip leading punct
    $token =~ s/\p{P}+$//; #strip traiing punct
    $token = lc($token);
    if($funcWord{$token}){
      $count++;
    }
  }

  if($count == 0){
    push(@{$feats}, "NoFunc");
  } elsif($count <= 5){
    push(@{$feats}, "FewFunc");
  } else {
    push(@{$feats}, "AlotFunc");
  }

  # for crfpp template
  my $curSize = scalar(@{$feats});
  $featureCounts->{$label}->{"end"} = $curSize;
  
  my $i = 0;
  for(my $j=$prevSize; $j < $curSize; $j++){
    push(@{$templates}, "$label".$i++.":%x[0,$j]\n");
  }
  push(@{$templates}, "\n");
}

sub buildTmpFile {
    my ($filename) = @_;
    my $tmpfile = $filename;
    $tmpfile =~ s/[\.\/]//g;
    $tmpfile .= $$ . time;
    # untaint tmpfile variable
    if ($tmpfile =~ /^([-\@\w.]+)$/) {
	$tmpfile = $1;
    }
    
    # return $tmpfile;
    return "/tmp/$tmpfile"; # Altered by Min (Thu Feb 28 13:08:59 SGT 2008)

}  # buildTmpFile


sub fatal {
    my $msg = shift;
    print STDERR "Fatal Exception: $msg\n";
}


sub decode {
  my ($inFile, $modelFile, $outFile) = @_;
  
  my $labeledFile = buildTmpFile($inFile);
  execute("$crf_test -v1 -m $modelFile $inFile > $labeledFile"); #  -v1: output confidence information

  open (PIPE, "<:utf8", $labeledFile) || die "# crash\t\tCan't open \"$labeledFile\"";

  open (OUT, ">:utf8", $outFile) || die "# crash\t\tCan't open \"$outFile\"";

  while(<PIPE>){
    chomp;
    print OUT "$_\n";
  }
  close PIPE;
  close OUT;
  
  return 1;
}  # decode

sub readKeywordDict {
  my ($inFile, $keywords) = @_;

  open (IF, "<:utf8", $inFile) || die "fatal\t\tCannot open \"$inFile\"!";
#  print STDERR "Load keywords from file $inFile\n";
  #process input file
  while(<IF>){
    chomp;
    
    if(/^(.+?): (.+)$/){
      my $tag = $1;
      my @tokens = split(/\s+/, $2);
      $keywords->{$tag} = ();
      foreach(@tokens){
	$keywords->{$tag}->{$_} = 1;
      }
    }
  }

  close (IF);
}

sub loadConfigFile {
  my ($inFile, $configs) = @_;

  open (IF, "<:utf8", $inFile) || die "fatal\t\tCannot open \"$inFile\"!";

#  print STDERR "\n# Loading config files $inFile\n";
  while(<IF>){
    chomp;
    
    if(/^(.+)=(.+)$/){
#      print STDERR "$_\t";
      my $name = $1;
      my $value = $2;
      $configs->{$name} = $value;
    }
  }
#  print STDERR "\n";

  close (IF);
}

sub readDict {
  my ($dictFileLoc) = @_;

  my $mode = 0;
  open (DATA, "<:utf8", $dictFileLoc) || die "Could not open dict file $dictFileLoc: $!";
  while (<DATA>) {
    if (/^\#\# Male/) { $mode = 1; }			  # male names
    elsif (/^\#\# Female/) { $mode = 2; }		# female names
    elsif (/^\#\# Last/) { $mode = 4; }			  # last names
    elsif (/^\#\# Chinese/) { $mode = 4; }		  # last names
    elsif (/^\#\# Months/) { $mode = 8; }		 # month names
    elsif (/^\#\# Place/) { $mode = 16; }		 # place names
    elsif (/^\#\# Publisher/) { $mode = 32; }	     # publisher names
    elsif (/^\#/) { next; }
    else {
      chop;
      my $key = $_;
      my $val = 0;
      if (/\t/) {				     # has probability
	($key,$val) = split (/\t/,$_);
      }

      # already tagged (some entries may appear in same part of lexicon more than once
      if(!$dict{$key}){
	$dict{$key} = $mode;
      } else {
	if ($dict{$key} >= $mode) { next; }
	else { $dict{$key} += $mode; }		      # not yet tagged
      }
    }
  }
  close (DATA);

}  # readDict

sub loadListHash {
  my ($inFile, $hash) = @_;

  open(IF, "<:utf8", $inFile) || die "#Can't open file \"$inFile\"";

  while(<IF>){
    chomp;

    $hash->{$_} = 1;
  }

  close IF;
}

sub untaint {
  my ($s) = @_;
  if ($s =~ /^([\w \-\@\(\),\.\/<>]+)$/) {
    $s = $1;               # $data now untainted
  } else {
    die "Bad data in $s";  # log this somewhere
  }
  return $s;
}

sub execute {
  my ($cmd) = @_;
#  print STDERR "Executing: $cmd\n";
  $cmd = untaint($cmd);
  system($cmd);
}

1;
