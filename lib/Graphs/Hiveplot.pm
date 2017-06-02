#!/usr/bin/perl
package Graphs::Hiveplot;

#
# simple_hive.pl
#
#   draw vector-based hive plots to compare interaction pairs found
#   when projecting them over three sets of transcripts.
#
# USAGE:
#   simple_hive.pl [ options ] \
#                  3ways_interactions_table.tbl \
#                > interactions_hive.[ps/pdf]
#
# ####################################################################
#
#            Copyright (C) 2016 - Josep F ABRIL
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ####################################################################
#
# $Id$
#
use strict;
use warnings;
use Exporter qw(import);
use Carp;
use PDF::API2;
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(create_plots);
our %EXPORT_TAGS = ( DEFAULT => [qw(create_plots)]);

#
#
use constant mm => 25.4 / 72;
use constant in => 1 / 72;
use constant pt => 1;
use constant PI => 3.14159265358979;
#
sub create_plots {
    my %PROTS = ();
    my $VERSION = '1.0beta';
    my $PROG    = "graphcompare";




    #
    ### POSTSCRIPT CODE
    #
    (my $PS_header =<<'EOPSH') =~ s/^\s{4}//omg;
    %!PS
    %%Title: ##TITLE##
    %%Creator: ##CREATOR##
    %%Version: ##VERSION##
    %%CreationDate: ##DATE##
    %%For: ##USER##
    %%Pages: 1
    %%Orientation: Portrait
    %%BoundingBox: 0 0 ##SIZE## ##SIZE##
    %%EndComments
    %
    %%BeginProlog
    %
    %%BeginProcSet: Functs 1.0 0
    %
    % Shortcuts
    %
    /B  { bind def } bind def
    /D  { def } B
    /X  { exch } B
    /xdf { exch def } B
    /C  { scale } B
    /G  { rotate } B
    /T  { translate } B
    /S  { gsave } B
    /R  { grestore } B
    /m  { moveto } B
    /rm { rmoveto } B
    /l  { lineto } B
    /rl { rlineto } B
    /K  { stroke } B
    /F  { fill } B
    /cmyk { setcmykcolor } B % requires four arguments: Cyan Magenta Yellow Black : ranges [0,1]
    /srgb { setrgbcolor } B  % requires three arguments: Red Blue Green : ranges [0,1]
    /slw { setlinewidth } B
    /sfont { findfont exch scalefont setfont } B
    /chrh { S newpath 0 0 m false charpath flattenpath pathbbox exch pop 3 -1 roll pop R } B
    /strh {
      2 dict begin
      /lly 0.0 D /ury 0.0 D
      { ( ) dup
        0 4 -1 roll
        put chrh
        dup ury gt { /ury xdf } { pop } ifelse
        dup lly lt { /lly xdf } { pop } ifelse
      } forall
      ury
      end
    } B
    %
    /cm { 28.35 mul } B
    /in { 72    mul } B
    %
    /bbox { 4 copy 3 1 roll exch 6 2 roll 8 -2 roll m l l l closepath } B
    %
    % Fixed Page Sizes
    %
    /pga4     { 595 842 } D
    /pgusrdef { ##SIZE## ##SIZE## } D
    %
    % Fixed Color Names (CMYK)
    %
    /black     { 0.00 0.00 0.00 1.00 } D
    /white     { 0.00 0.00 0.00 0.00 } D
    /magenta   { 0.00 0.60 0.00 0.00 } D
    /violet    { 0.22 0.55 0.00 0.00 } D
    /blue      { 0.75 0.75 0.00 0.00 } D
    /skyblue   { 0.60 0.38 0.00 0.00 } D
    /cyan      { 0.60 0.00 0.00 0.00 } D
    /green     { 0.60 0.00 0.60 0.00 } D
    /limegreen { 0.30 0.00 0.80 0.00 } D
    /yellow    { 0.00 0.00 1.00 0.00 } D
    /orange    { 0.00 0.30 0.80 0.00 } D
    /red       { 0.00 0.60 0.60 0.00 } D
    %
    % Fixed Line Types
    %
    /solidline   { [    ]  0 setdash } D
    /dotted      { [  1 ]  0 setdash } D
    /longdotted  { [  1 ]  5 setdash } D
    /shortdashed { [ 10 ] 10 setdash } D
    /longdashed  { [ 20 ] 10 setdash } D
    %
    % Hive functs
    %
    /Aphi ##PHI## D % axis split angle half size
    /Aa  {   0 dup Aphi sub X Aphi add } D % alpha - bottom arm
    /Ab  { 120 dup Aphi sub X Aphi add } D % beta  - right  arm
    /Ag  { 240 dup Aphi sub X Aphi add } D % gamma - left   arm
    /Aab { Aa X pop Ab pop } D % alpha - beta
    /Abg { Ab X pop Ag pop } D % beta  - gamma
    /Aga { Ag X pop Aa pop } D % gamma - alpha
    %
    /nfactor { axislen npoints div } D
    /scalept { nfactor mul } D
    /orifix  { baselen nfactor div } D
    /cfactor { orifix add } D
    %
    /mkline { S 0 0 m maxlen 0 l fgcol cmyk 0.025 slw K R } B
    /lblfntsize 12 D
    /mkaxislbl {
      S
      Aphi G maxlen lbloffset add lblfntsize 2 div sub 0 T
      fgcol cmyk
      lblfntsize /Helvetica-Bold sfont
      dup dup stringwidth pop 2 div neg X strh X m 90 G
      show
      R
    } B
    /mkaxes {
      S
      0 0 baselen 0 360 arc S fgcol cmyk F R
      S Aa   pop G mkline LBLa mkaxislbl R
      S Aa X pop G mkline R
      S Ab   pop G mkline LBLb mkaxislbl R
      S Ab X pop G mkline R
      S Ag   pop G mkline LBLg mkaxislbl R
      S Ag X pop G mkline R
      R
    } B
    %
    /AA { cfactor S 0 0 3 -1 roll Aa  arc blue   cmyk K R } B
    /BB { cfactor S 0 0 3 -1 roll Ab  arc blue   cmyk K R } B
    /CC { cfactor S 0 0 3 -1 roll Ag  arc blue   cmyk K R } B
    /AB { cfactor S 0 0 3 -1 roll Aab arc green  cmyk K R } B
    /BC { cfactor S 0 0 3 -1 roll Abg arc violet cmyk K R } B
    /CA { cfactor S 0 0 3 -1 roll Aga arc cyan  cmyk K R } B
    /AC { cfactor dup dup
          S 0 0 3 -1 roll Aab arc red cmyk K R
          S 0 0 3 -1 roll Abg arc red cmyk K R
          S 0 0 3 -1 roll Aga arc red cmyk K R } B
    %
    %%EndProcSet: Functs 1.0 0
    %
    %%EndProlog
    %
    %%BeginSetup
    %
    % initgraphics
    % true setpacking
    true setstrokeadjust
    %
    black cmyk % default black
    0.01  slw  % default line width
    0 setlinejoin
    0 setlinecap
    %
    0 G 1 1 C 0 0 T
    %
    /PLTsize ##SIZE## D
    /X0 PLTsize 2 div cvi D % [ 0, ##SIZE## ] bbox // [ 0, 845 ] A4
    /Y0 X0                D % [ 0, ##SIZE## ] bbox // [ 0, 595 ] A4
EOPSH

    (my $PS_pginit =<<'EOPSP') =~ s/^\s{4}//omg;
    %
    % Custom Vars
    %
    /fgcol { black } D
    /bgcol { white } D
    %
    /baselen   PLTsize 0.010 mul cvi D % start position for axes
    /axislen   PLTsize 0.450 mul cvi D % maximum axes length
    /npoints   ##NPOINTS## D % number of single points
    /maxlen    baselen axislen add D
    /lbloffset ##LBLoffset## D % PLTsize 0.005 mul cvi D
    %
    /LBLa (##LABEL_A##) D
    /LBLb (##LABEL_B##) D
    /LBLg (##LABEL_C##) D
    %
    % mark % Only for error-tracking purposes
    %
    %%EndSetup
    %
    %%Page: 1 1
    %
    %%BeginPageSetup
    %
    % Saving current page settings
    /pgsave save def
    pgusrdef 0 0 bbox S bgcol cmyk F R S fgcol cmyk shortdashed K R clip newpath
    %
    %%EndPageSetup
    %
    X0 Y0 T -90 G % centering axes on bounding box center
    %
    mkaxes
    %
    nfactor dup C % set the proper scale to draw all arcs
    1 slw         % setting linewidth to size of an axis unit
    %
EOPSP

    (my $PS_trailer =<<'EOPST') =~ s/^\s{4}//omg;
    %
    grestoreall
    pgsave restore
    %
    showpage
    %
    % PageEND: 1 1
    %
    %%Trailer
    %
    %%Pages: 1
    %%Orientation: Portrait
    %%BoundingBox: 0 0 ##SIZE## ##SIZE##
    %
    %%EOF
EOPST

    #
    ### VARS
    #

    my @date = sub {
        $_[5] + 1900, $_[4] + 1, $_[3], $_[2], $_[1], $_[0]
    }->(localtime);
    my %VARS = (
        'GLOBAL' => {
    	'SIZE'    => 500,
    	'MINSIZE' => 500,
        'VERSION' => $VERSION,
        'CREATOR' => $PROG,
    	'PHI'     => 7.5,  # main axes split angle (angles in degrees not radians!)
    	'DELTA'   => 0.05, # Bèzier curves control points separation factor
    	'OFACTOR' => 0.010,
    	'TITLE'   => '3-WAY_INTERACTIONS_HIVE',
    	'DATE'    => sprintf("%04d/%02d/%02d %02d:%02d:%02d", @date),
    	'PDFDATE' => sprintf("%04d%02d%02d%02d%02d%02d+01'00'", @date),
    	'USER'    => defined($ENV{USER}) ? $ENV{USER} : 'nobody'
        },
        'PAGE' => {
    	'LABEL_A' => '*A*',
    	'LABEL_B' => '*B*',
    	'LABEL_C' => '*C*',
    	'NPOINTS' => 0
        },
        'DATA' => { # we can define custom ordering for A/B/C factors
    	'COL_A' => 2,
    	'COL_B' => 3,
    	'COL_C' => 4
        },
        'POSTSCRIPT' => {
    	'HEADER'  => $PS_header,
    	'PGINIT'  => $PS_pginit,
    	'TRAILER' => $PS_trailer
        }
    );


    # ARGUMENTS
    my $arguments = shift;

    croak "Give me a node-list file!\n" unless defined $arguments->{"tblfile"};
    croak "Give me the labels!\n"       unless defined $arguments->{"labels"};
    croak "Give me an outfile!\n"       unless defined $arguments->{"outfile"};
    my $tblfile   = $arguments->{"tblfile"};
    my $setsorder = $arguments->{"labels"};
    my $outfile   = $arguments->{"outfile"};
    my $PS_flg    = defined $arguments->{"psflg"} ? $arguments->{"psflg"}  : 0;
    my $size      = defined $arguments->{"size"}  ? $arguments->{"size"}   : $VARS{'GLOBAL'}{'SIZE'};
    my $phi       = exists $arguments->{"phi"}    ? $arguments->{"phi"}    : $VARS{'GLOBAL'}{'PHI'};
    my $delta     = exists $arguments->{"delta"}  ? $arguments->{"delta"}  : $VARS{'GLOBAL'}{'DELTA'};
    my $origin    = exists $arguments->{"origin"} ? $arguments->{"origin"} : $VARS{'GLOBAL'}{'OFACTOR'};

    #
    ### MAIN
    #
    $PS_flg = 1 - $PS_flg;

    my $minsize = $VARS{'GLOBAL'}{'MINSIZE'};
    &check_value(\$phi,    'phi',    '(0, 30]',      ($phi    >    0   && $phi    <= 30  ));
    &check_value(\$size,   'size',   ">=$minsize",   ($size   >= $minsize                ));
    &check_value(\$delta,  'delta',  '[-0.5, +0.5]', ($delta  >=  -0.5 && $delta  <=  0.5));
    &check_value(\$origin, 'origin', '[0, 0.1]',     ($origin >=   0   && $origin <=  0.1));

    $VARS{'GLOBAL'}{'SIZE'}    = $size   if defined($size);
    $VARS{'GLOBAL'}{'PHI'}     = $phi    if defined($phi);
    $VARS{'GLOBAL'}{'DELTA'}   = $delta  if defined($delta);
    $VARS{'GLOBAL'}{'OFACTOR'} = $origin if defined($origin);

    defined($setsorder) && do {
        ($VARS{'PAGE'}{'LABEL_A'}, $VARS{'DATA'}{'COL_A'}) = ($setsorder->[0], $setsorder->[1]);
        ($VARS{'PAGE'}{'LABEL_B'}, $VARS{'DATA'}{'COL_B'}) = ($setsorder->[2], $setsorder->[3]);
        ($VARS{'PAGE'}{'LABEL_C'}, $VARS{'DATA'}{'COL_C'}) = ($setsorder->[4], $setsorder->[5]);
    };

    # REMIND: angles in degrees not radians!!!
    $VARS{'PAGE'}{'ANGLES'} = { 'A' => 0, 'B' => 120, 'C' => 240 };
    my $ang = $VARS{'PAGE'}{'ANGLES'};
    $VARS{'PAGE'}{'AXIS'} = {
        'AA' => [ $ang->{'A'} - $phi, $ang->{'A'} + $phi ],
        'BB' => [ $ang->{'B'} - $phi, $ang->{'B'} + $phi ],
        'CC' => [ $ang->{'C'} - $phi, $ang->{'C'} + $phi ],
        'AB' => [ $ang->{'A'} + $phi, $ang->{'B'} - $phi ],
        'BC' => [ $ang->{'B'} + $phi, $ang->{'C'} - $phi ],
        'CA' => [ $ang->{'C'} + $phi, $ang->{'A'} - $phi ]
    };
    $VARS{'PAGE'}{'COLORS'} = { # 'named' / '#RGB' / '%CMYK'
        'AA' => 'blue',
        'BB' => 'blue',
        'CC' => 'blue',
        'AB' => 'green',
        'BC' => 'orange',
        'CA' => 'cyan',
        'AC' => 'red',
        'PBG' => 'white',
        'PFG' => 'black'
    };
    my $PLOTsize = $VARS{'GLOBAL'}{'SIZE'};
    $VARS{'PAGE'}{'PLOT'} = {
        'X0'        => $PLOTsize / 2,
        'Y0'        => $PLOTsize / 2,
        'BASElen'   => int($PLOTsize * $VARS{'GLOBAL'}{'OFACTOR'}), # start position for axes (inner circle)
        'AXISlen'   => int($PLOTsize * (0.460 - $VARS{'GLOBAL'}{'OFACTOR'})), # maximum axes length
        'LBLoffset' => int($PLOTsize * 0.02) # 1 - (0.46 * 2) full_hive_space / 2 side_margin / 2 label_anchor_midpoint -> 0.02
    };
    # set max axis length
    $VARS{'PAGE'}{'PLOT'}{'MAXLEN'} = $VARS{'PAGE'}{'PLOT'}{'BASElen'} + $VARS{'PAGE'}{'PLOT'}{'AXISlen'};

    my $nmfile = $tblfile ne '-' ? $tblfile : 'STANDARD INPUT';

    if ($PS_flg) {
        &make_postscript_concentric_hive($tblfile, \%VARS, $outfile);
    } else {
        &load_prots_hash($tblfile, \%PROTS, \%VARS);
        &make_pdf_bezier_hive(\%PROTS, \%VARS, $outfile);
    };

}

#
### SUBS
#
sub getIFH() {
    my $file = shift;
    my ($fstr,$ferr,$sflg);
    local *D;
    defined($file) || do {
        croak ('WARN', "FILE NAME NOT DEFINED !!!\n");
        exit('NOFILE');
    };
    ($file ne '-') || do {
        return (*STDIN, 2);
    };
    if ($file =~ /\|\s*$/o) {
        $fstr = $file;
        $ferr = 'NOREADPIPE';
        $sflg = 1;
    } elsif (! -e $file) {
        croak ('WARN', "INPUT File does not exist: \"$file\"\n");
        exit('NOFILE');
    } elsif ($file =~ /\.gz\s*$/io) {
        $fstr = "gunzip -c $file |";
        $ferr = 'NOREADPIPE';
        $sflg = 1;
    } elsif ($file =~ /\.zip\s*$/io) {
        $fstr = "unzip -c $file |";
        $ferr = 'NOREADPIPE';
        $sflg = 1;
    } elsif ($file =~ /\.bz2\s*$/io) {
        $fstr = "bunzip2 -c $file |";
        $ferr = 'NOREADPIPE';
        $sflg = 1;
    } elsif ($file =~ /\.z\s*$/io) {
        $fstr = "uncompress -c $file |";
        $ferr = 'NOREADPIPE';
        $sflg = 1;
    } else {
        $fstr = "< $file";
        $ferr = 'NOREADFILE';
        $sflg = 0;
    };
    open(D, $fstr) || do {
        croak ('WARN', "Cannot open input stream \"$fstr\"\n");
        exit($ferr);
    };
    return (*D, $sflg);
} # getIFH

sub check_value() {
    my ($var, $lbl, $int, $flg) = @_;
    ($$var + 0 == $$var) || die("### ERROR ### --$lbl should be a number, $$var seems not...\n");
    $flg || do {
	$$var  = undef;
    };
} # check_value

sub make_postscript_concentric_hive() {
    my ($file, $vars, $IFH, $sin_flg,
	$PS_header, $PS_pginit, $PS_data, $PS_trailer, $outfile);
    ($file, $vars, $outfile) = @_;

    ($IFH, $sin_flg) = &getIFH($file);

    open my $ofh, ">", $outfile
        or croak "Can't write to $outfile : $!\n";

    $PS_data = '';
    my @COLS = map { $_--; $_ } ($vars->{'DATA'}{'COL_A'}, $vars->{'DATA'}{'COL_B'}, $vars->{'DATA'}{'COL_C'});
    # print STDERR "@COLS\n";
    my $N = 1;
    my $header = <$IFH>;
    my ($n,$c) = (0, q{.});
    while (<$IFH>) {

    	my (@F,$Aflg,$Bflg,$Cflg,$set,$sep);

    	next if /^\s*$/o;
    	next if /^\#/o;

    	chomp;
    	@F = split /\t/, $_;

    	($Aflg,$Bflg,$Cflg) = ($F[ $COLS[0] ], $F[ $COLS[1] ], $F[ $COLS[2] ]);

          SWITCH: {
    	  $Aflg && do {
    	      $Bflg && $Cflg && ($set = 'AC', last SWITCH);
    	      $Bflg && ($set = 'AB', last SWITCH);
    	      $Cflg && ($set = 'CA', last SWITCH);
    	      $set = 'AA'; last SWITCH;
    	  };
    	  $Bflg && do {
    	      $Cflg && ($set = 'BC', last SWITCH);
    	      $set = 'BB'; last SWITCH;
    	  };
    	  $Cflg && do {
    	      $set = 'CC'; last SWITCH;
    	  };
    	  $set = undef;
    	};

    	$sep = $N % 10 == 0 ? "\n" : " ";
    	$PS_data .= sprintf("%d %s", $N, $set.$sep) if defined($set);

    	$N++;

        } continue {
    }; # while

    close($IFH) unless $sin_flg  == 2;


    $vars->{'PAGE'}->{'NPOINTS'} = --$N;

    ($PS_header  = $vars->{'POSTSCRIPT'}{'HEADER'} ) =~ s/\#\#([^\#]+)\#\#/$vars->{'GLOBAL'}{$1}/ig;
    ($PS_pginit  = $vars->{'POSTSCRIPT'}{'PGINIT'} ) =~ s/\#\#([^\#]+)\#\#/(exists($vars->{'PAGE'}{$1})
                                                                            ? $vars->{'PAGE'}{$1}
                                                                            : $vars->{'PAGE'}{'PLOT'}{$1})/ieg;
    ($PS_trailer = $vars->{'POSTSCRIPT'}{'TRAILER'}) =~ s/\#\#([^\#]+)\#\#/$vars->{'GLOBAL'}{$1}/ig;

    print {$ofh} $PS_header,$PS_pginit,$PS_data,$PS_trailer;

} # make_postscript_concentric_hive

sub make_pdf_bezier_hive() {
    my ($prots, $vars, $outfile) = @_;

    # use PDF::Create;

    # my $pdf = PDF::Create->new(
    #     'filename'     => $outfile, # if no filename is provided then STDOUT
    #     'Author'       => $vars->{'GLOBAL'}{'USER'},
    #     'Creator'      => $vars->{'GLOBAL'}{'CREATOR'},
    #     'Title'        => $vars->{'GLOBAL'}{'TITLE'},
    #     'CreationDate' => [ localtime ]
    # );

    # # Add a custom sized page
    # my $root = $pdf->new_page( 'MediaBox' => [ 0, 0, $vars->{'GLOBAL'}{'SIZE'}, $vars->{'GLOBAL'}{'SIZE'} ]);
    # # Add a page which inherits its attributes from $root
    # my $page = $root->new_page;
    # # Prepare a font
    # my $font = $pdf->font('BaseFont' => 'Helvetica');

    open my $ofh, ">", $outfile
        or croak "Can't write to $outfile : $!\n";

    my $pdf = PDF::API2->new(-file => $ofh);
    $pdf->info(
        'Author'       => $vars->{'GLOBAL'}{'USER'},
        'CreationDate' => "D:".$vars->{'GLOBAL'}{'PDFDATE'},
        'ModDate'      => "D:YYYYMMDDhhmmssOHH'mm'",
        'Creator'      => $vars->{'GLOBAL'}{'CREATOR'},
        'Producer'     => "PDF::API2",
        'Title'        => $vars->{'GLOBAL'}{'TITLE'},
        'Subject'      => "",
        'Keywords'     => ""
    );

    $pdf->mediabox();

    my $font_helv  = $pdf->corefont('Helvetica');
    my $font_helvb = $pdf->corefont('Helvetica-Bold');
    $vars->{'PAGE'}{'PLOT'}{'FONT-HELV'}     = $font_helv;
    $vars->{'PAGE'}{'PLOT'}{'FONT-HELVBOLD'} = $font_helvb;
    my ($deltaU,$deltaD) = ( 1 + $vars->{'GLOBAL'}{'DELTA'},
			     1 - $vars->{'GLOBAL'}{'DELTA'});

    my $page = $pdf->page();
    $page->mediabox($vars->{'GLOBAL'}{'SIZE'}/pt, $vars->{'GLOBAL'}{'SIZE'}/pt);
    $page->cropbox ($vars->{'GLOBAL'}{'SIZE'}/pt, $vars->{'GLOBAL'}{'SIZE'}/pt);

    my $EGalpha9 = $pdf->egstate();
    my $EGalpha0 = $pdf->egstate();
    $EGalpha9->transparency(0.9);
    $EGalpha0->transparency(0);

    my $gfx = $page->gfx(); # new graphics object

    $gfx->save();
    $gfx->translate($vars->{'PAGE'}{'PLOT'}{'X0'}, $vars->{'PAGE'}{'PLOT'}{'Y0'}); # center origin
    $gfx->rotate(-90); # rotate to place A at bottom, B on the right and C on the left

    $gfx->egstate($EGalpha0); # no alpha for axis
    &plot_axis($gfx,$vars);
    $gfx->restore();

    #
    my $gfy = $page->gfx(); # new graphics object

    $gfy->save();
    $gfy->translate($vars->{'PAGE'}{'PLOT'}{'X0'}, $vars->{'PAGE'}{'PLOT'}{'Y0'}); # center origin
    $gfy->rotate(-90); # rotate to place A at bottom, B on the right and C on the left

    my $scale  = $vars->{'PAGE'}{'PLOT'}{'AXISlen'} / $prots->{'COUNT'};
    # we need to scale up the initial axis position
    my $orifix = $vars->{'PAGE'}{'PLOT'}{'BASElen'} / $scale;

    $gfy->scale($scale,$scale); # set protein coords scale factor
    $gfy->egstate($EGalpha9); # alpha for net connections

    foreach my $set (keys %{ $prots->{'PAIRS'} }) {

	next if $set eq 'ALL';

	$gfy->save();
	$gfy->linewidth(1);
	$gfy->linedash(); # without any arguments, a solid line will be drawn
	$gfy->fillcolor($vars->{'PAGE'}{'COLORS'}{$set});
	$gfy->strokecolor($vars->{'PAGE'}{'COLORS'}{$set});

	foreach my $ptA (keys %{ $prots->{'PAIRS'}{$set} }) {

	    my $ptBs = $prots->{'PAIRS'}{$set}{$ptA};

	    foreach my $ptB (@$ptBs) {
		my ($lenA,$lenB,$phio,$phie);

		($lenA,$lenB) = ($prots->{'ORDER'}{$ptA} + $orifix,
				 $prots->{'ORDER'}{$ptB} + $orifix);

		$set ne 'AC' && do {
		    ($phio,$phie) = @{ $vars->{'PAGE'}{'AXIS'}{$set} };
		    &plot_bezier($gfy,$lenA,$phio,$lenB,$phie,$deltaU,$deltaD);
		    next;
		};

		foreach my $all (qw( AB BC CA )) {
		    ($phio,$phie) = @{ $vars->{'PAGE'}{'AXIS'}{$all} };
		    &plot_bezier($gfy,$lenA,$phio,$lenB,$phie,$deltaU,$deltaD);
		};

	    }; # $ptB

	}; # $ptA

	$gfy->restore();

    }; # $set
    $gfy->restore();

    $pdf->save();

} # make_pdf_bezier_hive

sub plot_axis() {
    my ($gfx,$vars,$l,$L,$phi);
    ($gfx,$vars) = @_;

    $gfx->save();

    $gfx->linewidth(0.025);
    $gfx->linedash(); # without any arguments, a solid line will be drawn

    $gfx->fillcolor($vars->{'PAGE'}{'COLORS'}{'PFG'});
    $gfx->strokecolor($vars->{'PAGE'}{'COLORS'}{'PFG'});

    ($l,$L) = ($vars->{'PAGE'}{'PLOT'}{'BASElen'},
	       $vars->{'PAGE'}{'PLOT'}{'MAXLEN'});

    foreach my $s (keys %{ $vars->{'PAGE'}{'AXIS'} }) {
	$phi = $vars->{'PAGE'}{'AXIS'}{$s}[0];
	$gfx->save();
	$gfx->rotate($phi);
	$gfx->move(0,0);
	$gfx->hline($L);
	$gfx->stroke();
	$gfx->restore();
    };

    $gfx->save();
    $gfx->circle(0, 0, $l);
    $gfx->fill();
    $gfx->restore();

    my @ang = (-30, 90, 210);
    my $ll = $l * 0.6;
    $gfx->save(); # arrows fancy watermark
    $gfx->fillcolor($vars->{'PAGE'}{'COLORS'}{'PBG'});
    $gfx->strokecolor($vars->{'PAGE'}{'COLORS'}{'PBG'});
    $gfx->linejoin(0);
    foreach my $theta (@ang) {
	my $theta2 = $theta + 90;
	$gfx->linewidth($l * 0.15); # 1.5
	$gfx->arc(0, 0, $ll, $ll, $theta, $theta2, 1);
	$gfx->stroke();
	$gfx->linewidth($l * 0.05); # 0.5
	$gfx->move($ll * mycos($theta2 + 7.5),        $ll * mysin($theta2 + 7.5));
	$gfx->line($ll * 0.75 * mycos($theta2 - 15),  $ll * 0.75 * mysin($theta2 - 15));
	$gfx->line($ll * 1.25 * mycos($theta2 - 10),  $ll * 1.25 * mysin($theta2 - 10));
	$gfx->line($ll * mycos($theta2 + 7.5),        $ll * mysin($theta2 + 7.5));
	$gfx->close;
	$gfx->fillstroke();
    };
    $gfx->restore();
    $gfx->save(); # we duplicated the loop, as then we require to call less state commands on the PDF...
    $gfx->fillcolor($vars->{'PAGE'}{'COLORS'}{'PFG'});
    $gfx->strokecolor($vars->{'PAGE'}{'COLORS'}{'PFG'});
    foreach my $theta (@ang) {
	my $theta2 = $theta + 97.5;
	$gfx->linewidth($l * 0.05); # 0.5
	$gfx->move($ll * 0.85 * mycos($theta - 15), $ll * 0.85 * mysin($theta - 15));
	$gfx->line($ll * mycos($theta + 7.5),     $ll * mysin($theta + 7.5));
	$gfx->line($ll * 1.35 * mycos($theta - 15), $ll * 1.35 * mysin($theta - 15));
	$gfx->close;
	$gfx->fillstroke();
	# $gfx->stroke();
    };
    $gfx->restore();

    my $fntsize = 12;
    $gfx->font($vars->{'PAGE'}{'PLOT'}{'FONT-HELVBOLD'}, $fntsize);

    $L += $vars->{'PAGE'}{'PLOT'}{'LBLoffset'} + $fntsize / 2;
    foreach my $s (keys %{ $vars->{'PAGE'}{'ANGLES'} }) {
	my $lbl = $vars->{'PAGE'}{"LABEL_$s"};
	$phi = $vars->{'PAGE'}{'ANGLES'}{$s};
	$gfx->save();
	$gfx->rotate($phi);
	$gfx->translate($L,0);
	$gfx->rotate(90);
	$gfx->move(0,0);
	$gfx->text_center($lbl);
        $gfx->restore();
    };

    $gfx->restore();

} # plot_axis

sub plot_bezier() {
    my ($gfx,$lenO,$phiO,$lenE,$phiE,$deltaU,$deltaD) = @_;
    $phiE = 360 + $phiE if $phiE < 0;
    my $phiM = (($phiE - $phiO) / 2) + $phiO;
    # $gfx->save();

    $gfx->move(
    	$lenO * mycos($phiO), $lenO * mysin($phiO)  # px0 py0
    	);
    $gfx->curve(
    	$lenO * $deltaU * mycos($phiM), $lenO * $deltaU * mysin($phiM), # cx0 cy0
    	$lenE * $deltaD * mycos($phiM), $lenE * $deltaD * mysin($phiM), # cx1 cy1
    	$lenE * mycos($phiE), $lenE * mysin($phiE)  # px0 py1
    	);
    $gfx->stroke();
    # $gfx->restore();

} # plot_bezier

sub mycos() { return cos(($_[0] / 180) * PI); } # mycos (angles in degrees)
sub mysin() { return sin(($_[0] / 180) * PI); } # mysin (angles in degrees)

sub roundfloat() {
    my $x = shift;
    my $s = $x < 0 ? -0.5 : 0.5;
    return int(($x * 10000.0) + $s) / 10000.0;
} # roundfloat

sub load_prots_hash() {
    my ($file, $prots, $vars, $IFH, $sin_flg);
    ($file, $prots, $vars) = @_;


    ($IFH, $sin_flg) = &getIFH($file);

    my $N = 0;
    my $Pcnt = 0;
    my @COLS = map { $_--; $_ } ($vars->{'DATA'}{'COL_A'}, $vars->{'DATA'}{'COL_B'}, $vars->{'DATA'}{'COL_C'});
    # print STDERR "@COLS\n";
    my $header = <$IFH>;
    my ($n,$c) = (0,q{r});

    while (<$IFH>) {

    	my (@F,$Aflg,$Bflg,$Cflg,$Pair,$ProtA,$ProtB,$PIDA,$PIDB,$set,$sep);

    	next if /^\s*$/o;
    	next if /^\#/o;

    	$N++;

    	chomp;
    	@F = split /\t/, $_;

    	($Pair,$Aflg,$Bflg,$Cflg) = ($F[0], $F[ $COLS[0] ], $F[ $COLS[1] ], $F[ $COLS[2] ]);
    	($ProtA, $ProtB) = split /::->::/, $Pair;

    	# we simplify the network, and the memory required to sotre the data structure,
    	# by storing only information A->B, even for undirected graphs...
    	exists($prots->{'PRT'}{$ProtA}) || ($Pcnt++,
    					    $prots->{'PRT'}{$ProtA} = $Pcnt, # protid, totaldegree, childs, idprot
    					    $prots->{'DEG'}{$Pcnt}  = 0,
    					    $prots->{'CHL'}{$Pcnt}  = [],
    					    $prots->{'IDS'}{$Pcnt}  = $ProtA);
    	exists($prots->{'PRT'}{$ProtB}) || ($Pcnt++,
    					    $prots->{'PRT'}{$ProtB} = $Pcnt, # protid, totaldegree, childs, idprot
    					    $prots->{'DEG'}{$Pcnt}  = 0,
    					    $prots->{'CHL'}{$Pcnt}  = [],
    					    $prots->{'IDS'}{$Pcnt}  = $ProtB);
    	($PIDA,$PIDB) = ($prots->{'PRT'}{$ProtA}, $prots->{'PRT'}{$ProtB});
    	$prots->{'DEG'}{$PIDA}++;
    	push @{ $prots->{'CHL'}{$PIDA} }, $PIDB;

          SWITCH: {
    	  $Aflg && do {
    	      $Bflg && $Cflg && ($set = 'AC', last SWITCH);
    	      $Bflg && ($set = 'AB', last SWITCH);
    	      $Cflg && ($set = 'CA', last SWITCH);
    	      $set = 'AA'; last SWITCH;
    	  };
    	  $Bflg && do {
    	      $Cflg && ($set = 'BC', last SWITCH);
    	      $set = 'BB'; last SWITCH;
    	  };
    	  $Cflg && do {
    	      $set = 'CC'; last SWITCH;
    	  };
    	  $set = undef;
    	};

    	exists($prots->{'PAIRS'}{$set}) || ($prots->{'PAIRS'}{$set} = {});
    	exists($prots->{'PAIRS'}{$set}{$PIDA}) || ($prots->{'PAIRS'}{$set}{$PIDA} = []);

    	push @{ $prots->{'PAIRS'}{$set}{$PIDA} }, $PIDB;

    	exists($prots->{'PAIRS'}{$set}) || ($prots->{'PAIRS'}{$set} = {});
    	exists($prots->{'PAIRS'}{$set}{$PIDA}) || ($prots->{'PAIRS'}{$set}{$PIDA} = []);

    	push @{ $prots->{'PAIRS'}{'ALL'}{$PIDA} }, $PIDB;

        } continue {
    }; # while

    close($IFH) unless $sin_flg  == 2;



    # Precomputing protein order
    my @ORDER = ();
    my $Ocnt = 0;
    ($n,$c) = (0,q{u});
    foreach my $as (keys %{ $prots->{'IDS'} }) {
# $prots->{'PAIRS'}{'ALL'} }) {

	my $maxb = 0; # getting the largest B degree
	exists($prots->{'PAIRS'}{'ALL'}{$as}) && do {

	    my @bs = @{ $prots->{'PAIRS'}{'ALL'}{$as} };

	    foreach my $bs (@bs) {
		$maxb = $prots->{'DEG'}{$bs} if $maxb < $prots->{'DEG'}{$bs};
	    };

	};

	push @ORDER, [ $as, $prots->{'DEG'}{$as}, $maxb, $prots->{'IDS'}{$as} ];
	$Ocnt++;
    } continue {
    }; # while


    $prots->{'COUNT'} = $Ocnt; # number of single points from proteins

    @ORDER =  map { [ $Ocnt--, @$_ ] }
             sort { $b->[1] <=> $a->[1]
		 || $b->[2] <=> $a->[2]
		 || $b->[3] cmp $a->[3] } # Adegree then Bdegree then prot_name
                    @ORDER;


    foreach my $pary (@ORDER) {
	my ($pord, $prid) = ($pary->[0],$pary->[1]);
	$prots->{'ORDER'}{$prid} = $pord;
    };
    $prots->{'ORDARY'} = \@ORDER;


} # load_prots_hash
