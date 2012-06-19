#!/usr/bin/perl -w 
#
# perl file for reading ini style files

use Config::IniFiles;
use Getopt::Long;

sub unquote($);


my @getopt_args = (
    '-Gv',
    '-Sv',
    '-Dv',
    '-Gs',
    '-Ss',
    '-Ds',
    'P',
    'S',
    'V',  
    'f=s',
    's=s',
    'p=s',
    'v=s',
    'h',
    '-help',
);    

Getopt::Long::config("noignorecase", "bundling");
unless (GetOptions(\%options, @getopt_args)) {
    usage();
}

#my $FileName = unquote($options{'f'}) if defined $options{'f'};
#my $Section  = unquote($options{'s'}) if defined $options{'s'};
#my $Param    = unquote($options{'p'}) if defined $options{'p'};
#my $Value    = unquote($options{'v'}) if defined $options{'v'};

my $FileName = ($options{'f'}) if defined $options{'f'};
my $Section  = ($options{'s'}) if defined $options{'s'};
my $Param    = ($options{'p'}) if defined $options{'p'};
my $Value    = ($options{'v'}) if defined $options{'v'};

usage() if $options{'h'} || $options{'help'};
#print "Missings arguments.\nTry econf.pl --help or econf.pl -h for more information\n" if !@ARGV;

if ($options{'V'}) {
    die <<"EOT";
This is the first version of econf. 
2005-2006 Copyright Rene Spit.
EOT
}
if (defined $options{'f'}) {
    if ($options{'S'}) {
	g_secs();
    }
}
if (defined $options{'f'} && defined $options{'s'}) {
    if ($options{'Gv'}) {
	if (defined $options{'p'}) {
    	    g_val();
	}
    }
    if ($options{'Sv'}) {
	if (defined $options{'p'}) {    
	    s_val();
	}
    }
    if ($options{'Dv'}) {
	d_val();
    }
    if ($options{'Gs'}) {
	g_sec();
    }
    if ($options{'Ss'}) {
	s_sec();
    }
    if ($options{'Ds'}) {
	d_sec();
    }
    if ($options{'P'}) {
	g_pars();
    }
}


sub g_val  {
    if ( $FileName ne "" && $Section ne "" && $Param ne "" ) {	 
	my $cfg=new Config::IniFiles(-file=>$FileName);
	if ($cfg->val($Section,$Param)) {
		print $cfg->val($Section,$Param) . "\n";
	}
    }
}

sub g_sec  {
    if ( $FileName ne "" && $Section ne "" ) {	 
	my $cfg=new Config::IniFiles(-file=>$FileName);
	if ($cfg->SectionExists($Section)) {
	    print "[" . $Section . "]\n";
	} else {
	    print "The section \[" . $Section . "\] in "
		  . $FileName . " doestn't exist\n";
	} 
    }
}

sub g_pars  {
    if ( $FileName ne "" && $Section ne "" ) {	 
	my $cfg=new Config::IniFiles(-file=>$FileName);
	if ($cfg->SectionExists($Section)) {
	    @params=$cfg->Parameters($Section);
	    foreach $par (@params) {
		print $par . "\n";
	    }
	} 
    }
}

sub g_secs  {
    if ( $FileName ne "" ) {	 
	my $cfg=new Config::IniFiles(-file=>$FileName);
	@sections=$cfg->Sections();
	foreach $section (@sections) {
	    print $section . "\n";
	} 
    }
}

sub s_val  {
    if ( $FileName ne "" && $Section ne "" && $Param ne "" && $Value ne "" ) {	 
	my $cfg=new Config::IniFiles(-file=>$FileName);
    
	if (!$cfg->SectionExists($Section)) {
	    s_sec();
	}
	if ($cfg->val( $Section, $Param )) {
    	    $cfg->setval($Section,$Param,$Value);
	} else {
	    $cfg->newval($Section,$Param,$Value);
	}
	$cfg->WriteConfig($FileName);
    }
}

sub s_sec  {
    if ( $FileName ne "" && $Section ne "" ) {	 
	my $cfg=new Config::IniFiles(-file=>$FileName);
	
	if (!$cfg->SectionExists($Section)) {
    	    $cfg->AddSection($Section);
	}
	$cfg->WriteConfig($FileName);
    }
}

sub d_val  {
    if ( $FileName ne "" && $Section ne "" && $Param ne "" ) {	 
	my $cfg=new Config::IniFiles(-file=>$FileName);

	if ($cfg->val($Section, $Param)) {
    	    $cfg->delval($Section,$Param);
	} 
	$cfg->WriteConfig($FileName);
    }
}

sub d_sec  {
    if ( $FileName ne "" && $Section ne "" ) {	 
	my $cfg=new Config::IniFiles(-file=>$FileName);

	if ($cfg->SectionExists($Section)) {
    	    $cfg->DeleteSection($Section);
	}
	$cfg->WriteConfig($FileName);
    }
}

sub unquote($) {
    my $string = shift;
    $string =~ s/^\"+//g;
    $string =~ s/\"+$//g; 
    return $string;
}

sub usage {
    die <<"EOT";
Usage: econf.pl <--Gv> -f <file> -s <section> -p <parameter> 
   or: econf.pl <--Sv> -f <file> -s <section> -p <parameter> -v <value>
   or: econf.pl <--Dv> -f <file> -s <section> -p <parameter> 
   or: econf.pl <--Gs> -f <file> -s <section> 
   or: econf.pl <--Ss> -f <file> -s <section> 
   or: econf.pl <--Ds> -f <file> -s <section> 
   or: econf.pl <-S> -f <file>     
   or: econf.pl <-P> -f <file> -s <section>    

    --Gv, 	   Get value
		   Checks for the value of an given section and parameter
    --Sv, 	   Set value
		   Sets the value of an given section and parameter
		   Creates the parameter if the given parameter doesn't exists
    --Dv, 	   Delete value 
		   Delete a parameter
    --Gs, 	   Get section 
		   Checks for the existents of an given section. Returns the 
		   [section]
    --Ss,	   Set section
		   Create/Set the section
    --Ds, 	   Delete section
		   Delete the entire section
    -S		   Returns all sections 
    -P		   Returns all parameters inside a section
		   
    -f <file>	   Inifile (windowsstyle)
    -s <section>   Section-names must be unique 
    -p <parameter> Parameters must be unique inside an section
    -v <value>	   Value may contain any character
    -h, --help     Shows this page
    
    INI file format;
    
    BOF
    [section]
	parameter=value
	parameter1=value1
	parameter2=value2...
    
    [section1]
	parameter=value...
    EOF
    
EOT
}
