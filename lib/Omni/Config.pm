package Omni::Config;

# Global
# Names of the classes
$ALG_NAME		= "Omni";
# Version
$ALG_VERSION	= "110121";

# All Omnipage XML tags 
%omni_tag_list	=		(	'DOCUMENT'		=> 'document',
		 	  				'PAGE'			=> 'page',
							'COLUMN'		=> 'column',
		   					'DESC'			=> 'description',
			   				'SRC'			=> 'source',
							'LANGUAGE' 		=> 'language',
							'STYLE'			=> 'style',
							'STYLE-TABLE'	=> 'styleTable',
							'THEO-PAGE'		=> 'theoreticalPage',
							'BODY'			=> 'body',
							'SECTION'		=> 'section',
							'COL'			=> 'column',
							'PARA'			=> 'para',
							'LINE'			=> 'ln',
							'WORD'			=> 'wd',
							'SPACE'			=> 'space',
							'RUN'			=> 'run',
							'BULLET'		=> 'bullet',
							'TABLE'			=> 'table',
							'GRID'			=> 'gridTable',
							'GRID-COL'		=> 'gridCol',
							'GRID-ROW'		=> 'gridRow',
							'CELL'			=> 'cell',
							'BOTTOM-CELL'	=> 'bottomBorder',
							'TOP-CELL'		=> 'topBorder',
							'LEFT-CELL'		=> 'leftBorder',
							'RIGHT-CELL'	=> 'rightBorder',
							'PICTURE'		=> 'picture',
							'NEWLINE'		=> 'nl',
							'TAB'			=> 'tab',
							'DD'			=> 'dd'
						);
$tag_list = \%omni_tag_list;

# All Omnipage XML attributes 
%omni_att_list	=		(	'ALIGN'			=> 'alignment',
							'FONTFACE'		=> 'fontFace',
							'FONTFAMILY'	=> 'fontFamily',
							'FONTPITCH'		=> 'fontPitch',
							'FONTSIZE'		=> 'fontSize',
							'UNDERLINE'		=> 'underline',
							'SPACING'		=> 'spacing',
							'SCALE'			=> 'scale',
							'BOTTOM'		=> 'b',
							'TOP'			=> 't',
							'LEFT'			=> 'l',
							'RIGHT'			=> 'r',
							'LANGUAGE'		=> 'language',
							'SUSCRIPT'		=> 'subsuperscript',
							'BASELINE'		=> 'baseline',
							'BOLD'			=> 'bold',
							'ITALIC'		=> 'italic'
						);
$att_list = \%omni_att_list;

1;
