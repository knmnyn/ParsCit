package Trainer::ConfigTrainer;

# file and dir names
$tex_pattern			= "pattern.tex";						# pattern for plain bib
$tex_pattern_tmp		= "patternTmp";
$bibtex_tmp				= "bibtexTmp";							# bib text data
$bibtex_part_tmp		= "bibtexPartTmp";
$bibtex_test_tmp		= "bibtexTestTmp";
$tagged_references_tmp	= "trTmp";								# tagged references
$tr_test_tmp			= "taggedRefTestTmp";
$pr_test_tmp			= "plainRefTestTmp";
$crfpp_tmp				= "crfppTmp";							# crfpp data
$crfpp_prs_test_tmp		= "crfppParseRefSTestTmp";
$crfpp_tr2c_test_tmp	= "crfppTR2CrfppTestTmp";
$tr2crfpp				= "tr2crfpp.pl";						# executable
$parse_ref_strings		= "parseRefStrings.pl";
$crfpp_learn			= "crf_learn";
$crfpp_test				= "crf_test";
$tex_dir				= "resources/tex";						# relative to parscit root
$crfpp_template			= "crfpp/traindata/parsCit.template";	# relative to parscit root


# bib styles to use
@used_bibstyles = ( "plain", "acm", "apalike" );

1;
