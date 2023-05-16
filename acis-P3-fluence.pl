#!/usr/bin/perl

# ACIS particle fluence warning system for Chandra (based on ACE data)

# Created By Shanil Virani

# April 29, 2000
#
# Script updated by: Gregg Germain
#            update: 16 March, 2011
#            update: Move to han; major change to create one set of files for
#                    our real time web pages.
#                    Uses "getpath()" to select the path roof for all 
#                    input and output files
#
# Update: Gregg Germain
#         December 2012
#         Modified to work under 64 bit Linux
#
#
# Update: Gregg Germain
#         February 2016
#         DSN summary file moved by MTA from
#            /proj/rac/ops/ephem/dsn_summary.dat
#
#                 to
#
#            /home/mta/Snap/DSN.schedule
#
#
# Update: Gregg Germain
#         October 1, 2018
#         Point to the DSN summary file located in
#
#           /export/acis-flight/UTILITIES/DSN_summary.dat
#
#
# Update: Gregg Germain
#         July 9, 2019
#         Added Jack Steiner
#         Updated Dick Edgar's entries
#         Created the email and phone lists for easier maintenance
#
# Update: April 29, 2023
#              Gregg Germain
#              - Added Jim Francis to the alert list
#              - Added OpsGenie as an emailing method
#              - Fixed typos in comments
#
use Fcntl qw(:DEFAULT :flock);
use Sys::Hostname;

# Get local machine name - up case it
$host = uc(hostname() );

# Set the base path
$pathroot = "/export/acis-flight/FLU-MON/";

#
# Bogus limit initialization
#
$bogus_p3_delta_limit = 1.0e+05;

$fluence_file = $pathroot."ACE-flux.dat";
$acisflux_file = $pathroot."ACIS-FLUENCE.dat";

$alert_file = $pathroot."falert.dat";
$fluence_archive = $pathroot."ACIS-fluence.arc";
$ACE_fluence_archive = $pathroot."ACE-fluence.arc";
$ephem_file = $pathroot."gephem.dat";
$focalplane_file = $pathroot."FPHIST-2001.dat";
$gratings_file = $pathroot."GRATHIST-2001.dat";

#$DSNsched_file = '/proj/rac/ops/ephem/dsn_summary.dat';
#$DSNsched_file = '/home/mta/Snap/DSN.schedule';
$DSNsched_file = '/export/acis-flight/UTILITIES/DSN_summary.dat';

$direction_file = $pathroot."cxodirect.dat";

$direction_file_out = $pathroot."$TestPathOut/cxodirect.dat";
$acisflux_file_out = $pathroot."$TestPathOut/ACIS-FLUENCE.dat";
$alert_file_out = $pathroot."$TestPathOut/falert.dat";
$fluence_archive_out = $pathroot."$TestPathOut/ACIS-fluence.arc";
$ACE_fluence_archive_out = $pathroot."$TestPathOut/ACE-fluence.arc";

$sampl = 300;         # ACE sample time (seconds)
$writebit = 0;        # flag to write to archive and rollover counters

#-----------------------------------------------------------------
# read the Chandra altitude direction file: cxodirect.dat
#-----------------------------------------------------------------
open (CXOA, $direction_file) or die "No CXO altitude information found in $direction_file!\n";

while ($altdir = <CXOA>) {
         $cxoaltdir = $altdir;
}	 

close(CXOA);

chomp($cxoaltdir);

#
# read the ephemeris file: gephem.dat
#
open (EF, $ephem_file) or die "Ephemeris file $ephem_file not found!\n";
@e = split ' ',<EF>;
die "No ephemeris data found in $ephem_file\n" if (!@e or $#e < 5);
$r = $e[0];
$direct = $e[1];

#
# read the fluence file: ACE-flux.dat - get new E and P fluxes
#
open(FNAME, $fluence_file);
$histind = 0;
while ($line = <FNAME>) {
       push (@histcount,$line);
       $histind = $histind + 1;
}
close(FNAME);

@words= split ' ', $histcount[-3];
@words2= split ' ', $histcount[-1];

# Assign ACE electron and proton fluxes

# Electrons   38-53   175-315 
$E1f=$words[7];
$E2f=$words[8];

# Protons  47-68   115-195   310-580   795-1193 1060-1900 
$P1f=$words[10];   # REALLY P2
$P2f=$words[11];   # REALLY P3
$P3f=$words[12];   # REALLY P5
$P4f=$words[13];   # REALLY Fp6p
$P5f=$words[14];   # REALLY P7

# Concatenate Time of Flux Measurement

$currenttime = `date +"%Y:%j:%T:%Z"`;

@tfields = split(":",$currenttime);

if ($tfields[5] =~ "EDT") {
    $tzone=4;
} elsif ($tfields[5] =~ "EST") {
    $tzone=5;
} else {
    $tzone=4;
    print "Could not determine time zone information from date.\n";
}

$currentDECDOY = $tfields[0] + ($tfields[1] + ($tfields[2]+$tzone)/24 + $tfields
[3]/1440+ $tfields[4]/86400)/1000;

#-----------------------------------------------------------------
# Open the focal plane file: FPHIST-2001.dat
#-----------------------------------------------------------------
$fpindex = 0;
open (FPHIST, $focalplane_file) or die "Focal plane history file $focalplane_file not found!\n";
    flock(FPHIST,LOCK_SH) || die "Error: Cannot get a shared lock on $focalplane_file\n";
    while ($fpline = <FPHIST>) {
	@fpcount = split '\t', $fpline;
	@fpdecyr = split(":",$fpcount[0]);
	$fpdecyear = $fpdecyr[0] + ($fpdecyr[1] + $fpdecyr[2]/24 + $fpdecyr[3]/1440 + $fpdecyr[4]/86400)/1000;
	push (@fptime,$fpdecyear);
	push (@fpinst,$fpcount[1]);

	if ($fpindex > 0) {
	    if ($currentDECDOY <= $fptime[$fpindex] && $currentDECDOY >= $fptime[$fpindex-1]) {	      
	      $currentfpinst = $fpinst[$fpindex-1];	
	      last;
	    } elsif ($currentDECDOY < $fptime[0]) {
	      print "Unable to determine current FPINST at beginning of FPINST file.\n";
	      last;
	    }
	}    
	
	$fpindex = $fpindex + 1;
   }

close (FPHIST);#releases the lock

if ($currentfpinst eq "") {
    print "Unable to determine current FPINST at $currentDECDOY.\n";
}

$fpinfactor=1;

$fooyear=int($fptime[$fpindex]);
$decday=($fptime[$fpindex]-$fooyear)*1000;
$fooday=int($decday);
$dechour=($decday-$fooday)*24;
$foohour=int($dechour);
$foomin=int(($dechour-$foohour)*60);
$foosec=(($dechour-$foohour)*60 - $foomin)*60;


$foosec=sprintf("%6.3f",$foosec);

$simtime=sprintf("%4d:%3d:%2.2d:%2.2d:%6.3f",$fooyear,$fooday,$foohour,$foomin,$foosec);

# set flux factor based upon instrument
if ($fpinst[$fpindex-1] =~ "ACIS-S") {  
    $fpinfactor=1;
} elsif ($fpinst[$fpindex-1] =~ "ACIS-I") {
    $fpinfactor=1;
} elsif ($fpinst[$fpindex-1] =~ "HRC-I") {
    $fpinfactor=0;
} elsif ($fpinst[$fpindex-1] =~ "HRC-S") {
    $fpinfactor=0;
} else {
    $fpinfactor=1;
    print "FP instrument was not found in $focalplane_file\n";
}

#-----------------------------------------------------------------
# Open the gratings file: GRATHIST-2001.dat
# -----------------------------------------------------------------
$grindex = 0;
open (GRATHIST, $gratings_file) or die "Gratings history file $gratings_file not found!\n";
    flock(GRATHIST,LOCK_SH) || die "Error: Cannot get a shared lock on $gratings_file\n";
    while ($grline = <GRATHIST>) {
	@grcount = split '\t', $grline;
	@grdecyr = split(":",$grcount[0]);
	$grdecyear = $grdecyr[0] + ($grdecyr[1] + $grdecyr[2]/24 + $grdecyr[3]/1440 + $grdecyr[4]/86400)/1000;


	push (@grtime,$grdecyear);
	push (@hetg,$grcount[1]);
	push (@letg,$grcount[2]);
	if ($grindex > 0) {
	    if ($currentDECDOY <= $grtime[$grindex] && $currentDECDOY >= $grtime[$grindex-1]) {	      
	      $currenthetgstat = $hetg[$grindex-1];	
	      $currentletgstat = $letg[$grindex-1];	
	      last;
	    }  elsif ($currentDECDOY < $grtime[0]) {
	      print "Unable to determine current GRAT STATUS at beginning of GRATHIST file.\n";
	      last;
	    }
	
	}
	$grindex = $grindex + 1;
    }
close (GRATHIST);#releases the lock

if ($currentletgstat eq "") {
    print "Unable to determine current LETG STAT at $currentDECDOY.\n";
}

if ($currenthetgstat eq "") {
    print "Unable to determine current HETG STAT at $currentDECDOY.\n";
}


# Set grating factors based upon which (if any) grating is in
$gratfactor=1;

if ($hetg[$grindex-1] =~ "HETG-IN") {  
    $gratfactor=1/5;
} elsif ($hetg[$grindex-1] =~ "HETG-OUT") {
    $gratfactor=1;
} else {
    $gratfactor=1;
    print "HETG Gratings status was not found in $gratings_file\n";
}

$gratfactor2=1;
if ($letg[$grindex-1] =~ "LETG-IN") {
    $gratfactor2=1/2;
} elsif ($letg[$grindex-1] =~ "LETG-OUT") {
    $gratfactor2=1;
} else {
    $gratfactor2=1;
    print "LETG Gratings status was not found in $gratings_file\n";
}

#----------------------------------------------------------------------------
# Open ACIS orbital fluence file to get OLD fluence history: ACIS-FLUENCE.dat
#----------------------------------------------------------------------------
open (ACISFLUX, $acisflux_file) or die "ACIS fluence orbit history file $acisflux_file not found!\n";
$fluxind = 0;
while ($line = <ACISFLUX>) {
       push (@fluxcount,$line);
       $histind = $fluxind + 1;
}
close(ACISFLUX);

# Assign PREVIOUS ACIS electron and proton fluences

@acisfluxdata = split ' ', $fluxcount[-1];

$OLDACISE1F=$acisfluxdata[6];
$OLDACISE2F=$acisfluxdata[7];

$OLDACISP1F=$acisfluxdata[8];
$OLDACISP2F=$acisfluxdata[9];
$OLDACISP3F=$acisfluxdata[10];
$OLDACISP4F=$acisfluxdata[11];
$OLDACISP5F=$acisfluxdata[12];

$NEWINTTIME=$acisfluxdata[13] + $sampl;

# Now get the PREVIOUS (OLD) ACIS electron and proton FLUX
@oldacisflux = split ' ', $fluxcount[-3];

$OLDACISFLUXE1F=$oldacisflux[7];  # E 38-53      DE1
$OLDACISFLUXE2F=$oldacisflux[8];  # E 175-315    DE4

$OLDACISFLUXP1F=$oldacisflux[10]; # P 47-68      P2
$OLDACISFLUXP2F=$oldacisflux[11]; # P 115-195    P3
$OLDACISFLUXP3F=$oldacisflux[12]; # P 310-580    P5
$OLDACISFLUXP4F=$oldacisflux[13]; # P 795-1193   FP6p
$OLDACISFLUXP5F=$oldacisflux[14]; # P 1060-1900  P7


#
# Set values for a test
#
# Ok now you have both the old values and new FLUX values. Compare 
# them and look for any bogus jumps

#TTTTTTTTTTTTTTTTTTTTTTTt
#print "\nNEW P3 value: $P2f";
#print "\nOLD P3 value: $OLDACISFLUXP2F";


$bogus_p3_flag = 0;

$bogus_p3_delta = abs($P2f - $OLDACISFLUXP2F);

if( $bogus_p3_delta >= $bogus_p3_delta_limit)
    { 
      $bogus_p3_new = $P2f;
      # Use the old flux value BUT back out the gratings and FP effects
      # because they will be re-introduced downstream
      $bogus_p3_old = ($OLDACISFLUXP2F/$gratfactor/$gratfactor2)*$fpinfactor;

      $bogus_p3_flag = 1;
      # restore the P3 (P2f) value to the old value so that
      # the new one is not used.
      # restore the P3 (P2f) value to the old value so that
      # the new one is not used.
      $P2f = ($OLDACISFLUXP2F/$gratfactor/$gratfactor2)*$fpinfactor;
    }

#--------------------------------------------------------------
#
#  Now calculate the fluence values.
#
#--------------------------------------------------------------

if ($cxoaltdir eq "A" && $direct eq "A") {

#    print "CXO is currently ascending\n";
#    print "cxoaltdir = $cxoaltdir AND direct = $direct\n"; 

# Calculate NEW ACIS flux based on latest ACE measurement.

    $ACISE1f=$E1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISE2f=$E2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP1f=$P1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP2f=$P2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP3f=$P3f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP4f=$P4f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP5f=$P5f*$gratfactor*$gratfactor2*$fpinfactor;

#
# Calculate new ACIS fluence: previous ACIS fluence value + new ACIS flux measurement * ACE sample time
#

    $TOTALACISE1F = $ACISE1f * $sampl + $OLDACISE1F;
    $TOTALACISE2F = $ACISE2f * $sampl + $OLDACISE2F;
    $TOTALACISP1F = $ACISP1f * $sampl + $OLDACISP1F;
    $TOTALACISP2F = $ACISP2f * $sampl + $OLDACISP2F;
    $TOTALACISP3F = $ACISP3f * $sampl + $OLDACISP3F;
    $TOTALACISP4F = $ACISP4f * $sampl + $OLDACISP4F;
    $TOTALACISP5F = $ACISP5f * $sampl + $OLDACISP5F;

} elsif ($cxoaltdir eq "A" && $direct eq "D") {

#    print "CXO has just transistioned from A to D\n";
#    print "cxoaltdir = $cxoaltdir AND direct = $direct\n"; 

# Calculate NEW ACIS flux based on latest ACE measurement.

    $ACISE1f=$E1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISE2f=$E2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP1f=$P1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP2f=$P2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP3f=$P3f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP4f=$P4f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP5f=$P5f*$gratfactor*$gratfactor2*$fpinfactor;

#
# Calculate new ACIS fluence: previous ACIS fluence value + new ACIS flux measurement * ACE sample time
#

    $TOTALACISE1F = $ACISE1f * $sampl + $OLDACISE1F;
    $TOTALACISE2F = $ACISE2f * $sampl + $OLDACISE2F;
    $TOTALACISP1F = $ACISP1f * $sampl + $OLDACISP1F;
    $TOTALACISP2F = $ACISP2f * $sampl + $OLDACISP2F;
    $TOTALACISP3F = $ACISP3f * $sampl + $OLDACISP3F;
    $TOTALACISP4F = $ACISP4f * $sampl + $OLDACISP4F;
    $TOTALACISP5F = $ACISP5f * $sampl + $OLDACISP5F;

} elsif ($cxoaltdir eq "D" && $direct eq "D") {

#    print "CXO is currently in its descent leg\n";
#    print "cxoaltdir = $cxoaltdir AND direct = $direct\n"; 

# Calculate NEW ACIS flux based on latest ACE measurement.

    $ACISE1f=$E1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISE2f=$E2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP1f=$P1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP2f=$P2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP3f=$P3f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP4f=$P4f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP5f=$P5f*$gratfactor*$gratfactor2*$fpinfactor;

#
# Calculate new ACIS fluence: previous ACIS fluence value + new ACIS flux measurement * ACE sample time
#

    $TOTALACISE1F = $ACISE1f * $sampl + $OLDACISE1F;
    $TOTALACISE2F = $ACISE2f * $sampl + $OLDACISE2F;
    $TOTALACISP1F = $ACISP1f * $sampl + $OLDACISP1F;
    $TOTALACISP2F = $ACISP2f * $sampl + $OLDACISP2F;
    $TOTALACISP3F = $ACISP3f * $sampl + $OLDACISP3F;
    $TOTALACISP4F = $ACISP4f * $sampl + $OLDACISP4F;
    $TOTALACISP5F = $ACISP5f * $sampl + $OLDACISP5F;

} elsif ($cxoaltdir eq "D" && $direct eq "A") {

#    print "CXO has just transistioned from D to A\n";
#    print "cxoaltdir = $cxoaltdir AND direct = $direct\n"; 

    $writebit = 1;
    $fpinfactor = 0;
    $NEWINTTIME = 0;

    $OLDACISE1F = 0;
    $OLDACISE2F = 0;
    $OLDACISP1F = 0;
    $OLDACISP2F = 0;
    $OLDACISP3F = 0;
    $OLDACISP4F = 0;
    $OLDACISP5F = 0;

    $ACISE1f=$E1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISE2f=$E2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP1f=$P1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP2f=$P2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP3f=$P3f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP4f=$P4f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP5f=$P5f*$gratfactor*$gratfactor2*$fpinfactor;

#
# Calculate new ACIS fluence: previous ACIS fluence value + new ACIS flux measurement * ACE sample time
#

    $TOTALACISE1F = 0;
    $TOTALACISE2F = 0; 
    $TOTALACISP1F = 0;
    $TOTALACISP2F = 0; 
    $TOTALACISP3F = 0; 
    $TOTALACISP4F = 0; 
    $TOTALACISP5F = 0; 

} else {

    print "Fell into the ELSE section of fluence calculation loop. CHECK!\n";
    print "cxoaltdir = $cxoaltdir AND direct = $direct\n"; 

    $writebit = 1;
    $fpinfactor = 0;
    $NEWINTTIME = 0;

    $OLDACISE1F = 0;
    $OLDACISE2F = 0;
    $OLDACISP1F = 0;
    $OLDACISP2F = 0;
    $OLDACISP3F = 0;
    $OLDACISP4F = 0;
    $OLDACISP5F = 0;

    $ACISE1f=$E1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISE2f=$E2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP1f=$P1f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP2f=$P2f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP3f=$P3f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP4f=$P4f*$gratfactor*$gratfactor2*$fpinfactor;
    $ACISP5f=$P5f*$gratfactor*$gratfactor2*$fpinfactor;

#
# Calculate new ACIS fluence: previous ACIS fluence value + new ACIS flux measurement * ACE sample time
#

    $TOTALACISE1F = 0;
    $TOTALACISE2F = 0; 
    $TOTALACISP1F = 0;
    $TOTALACISP2F = 0; 
    $TOTALACISP3F = 0; 
    $TOTALACISP4F = 0; 
    $TOTALACISP5F = 0; 
}

#-----------------------------------------------------------------
# open the ACIS_FLUENCE.dat  for output
#-----------------------------------------------------------------
open (OUT, ">$acisflux_file_out");
print OUT "Latest valid ACIS flux and fluence data...",' 'x35,"$r km $direct$fpinst[$fpindex-1]:$hetg[$grindex-1]:$letg[$grindex-1]\n";
print OUT "$histcount[$histind-7]";
print OUT "$histcount[$histind-6]";
print OUT "$histcount[$histind-5]";
printf OUT "%4d%3d%3d%6d%8d%8d%3d  %.2e  %.2e%3d  %.2e  %.2e  %.2e  %.2e  %.2e   %3.2f\n",@words[0..6],$ACISE1f,$ACISE2f,$words[9],$ACISP1f,$ACISP2f,$ACISP3f,$ACISP4f,$ACISP5f, $words[15];
print OUT "ACIS Fluence data...Start DOY,SOD                                                                                   Int(s)\n";
printf OUT "%4d%3d%3d%6d%8d%8d %13.0f %12.0f   %12.0f   %11.0f   %10.0f   %10.0f   %9.0f        %6.0f\n",@words2[0..5],$TOTALACISE1F,$TOTALACISE2F,$TOTALACISP1F,$TOTALACISP2F,$TOTALACISP3F,$TOTALACISP4F,$TOTALACISP5F,$NEWINTTIME;
close(OUT);


#-----------------------------------------------------------------
# read the DSN schedule: dsn_summary.dat
#-----------------------------------------------------------------

     # get present time and break it out into Greenwich Mean Time
     $tsec = time;
     ($sec,$min,$hour,$dum,$dum,$dum,$dum,$doy) = gmtime($tsec);
     # Calculate the numeric day of year
     $doy += (($sec/60 + $min)/60 + $hour)/24 + 1;

     open(DF,$DSNsched_file) or die "Cannot open $DSNsched_file\n";
     while (<DF>) {
        @cols = split;
        @support = split(/\//, $cols[0]);
        $day = $support[0];
        @GMTtime = split(/\-/, $support[1]);
        $SupDOY = $day + $GMTtime[0]/2400;
        push @c,"$day:$cols[1]-$cols[2] UT\n" if ($doy < $SupDOY);
        last if ($#c == 2);
     }
     close(DF);


#-----------------------------------------------------------------
# read the alert file: falert.dat  (generally "0 0")
#-----------------------------------------------------------------

@pal = split ' ',<AF> if (open AF, $alert_file);
print STDERR "$host - No ACIS alert information found in $alert_file\n" if !@pal;

$flim = 1e9;          # fluence limit

# TEST purposes
#$flim = 1.0;

$scalef = 3;          # scale factor between successive alert thresholds
$Nalerts = 1;         # maximum number of alert messages
$Palert = 30*60;      # 30 minute alert interval (seconds)

# use an open-ended geometric scaling for fluence thresholds
# 1e+09 for the first round
$threshold = $flim * $scalef**(int($pal[0]/$Nalerts));

# do the fluence limit checking and alerting

if ($TOTALACISP2F > $threshold && $tsec > ($pal[1]+$Palert)) {
    chomp ($date = `date`);
    $msg  = sprintf "\n$host P3SCALING ACIS ALERT!! \n";
    $msg .= sprintf "ACIS P3 fluence = %.2e ",$TOTALACISP2F;
    $msg .= sprintf "p/(cm^2-sr-MeV), ";
    $msg .= sprintf "in previous %.1f hrs\n",$NEWINTTIME/3600;
    $msg .= sprintf "Above limit=%.1E ",$threshold;
    $msg .= sprintf "at 112 - 187 keV.\n";
    $msg .= sprintf "Latest ACE P3 proton";
    $msg .= sprintf "flux = %.2e ",$ACISP2f;
    $msg .= sprintf "p/(cm^2-s-sr-MeV).\n";
    $msg .= sprintf "Next SIM trans (to ";
    $msg .= sprintf "$fpinst[$fpindex]) occurs at ";
    $msg .= sprintf "UT:$simtime.\n";
    $msg .= sprintf "Present CXO alt: $r km and $direct.\n";
    $msg .= sprintf "CXO SI config:\n";
    $msg .= sprintf "$fpinst[$fpindex-1]:$hetg[$grindex-1]:$letg[$grindex-1]\n";
    $msg .= sprintf "Next DSN contacts:\n @c";
    $msg .= $date;
    &send_email();
    $pal[0]++;
    if (open AF, ">$alert_file_out") { print AF "$pal[0]  $tsec  (ACIS alert number $pal[0], sent at $date)\n" } 
    else { print STDERR "Cannot write to $alert_file\n"};
}

# If the Bogus Flag was set, sent out a message
if ($bogus_p3_flag == 1)
    {
     chomp ($date = `date`);
     $msg  = sprintf "\n$host - Bogus ACE P3 alert!  ";
     $msg .= sprintf "Bogus P2F is: %.1f\n",  $bogus_p3_new;     
     $msg .= sprintf "Bogus OLDACISFLUX  is: %.1f\n", $bogus_p3_old;
     $msg .= sprintf "Bogus Delta is: %.1f\n", $bogus_p3_delta;
     $msg .= $date;
     &send_email_to_acisdude();
     # Clear out bogus values
     $bogus_p3_delta = 0;
     $bogus_p3_flag = 0;
    }

#
# write to fluence_archive(ACIS-fluence.arc) and 
#          ACE_fluence_archive (ACE-fluence.arc) and
#          alert_file (falert.dat)
if ($writebit == 1) {
    open (AL, ">>$fluence_archive_out") or die "Cannot append to ACIS fluence archive $fluence_archive\n";
    print AL "$fluxcount[-1]";
    open (ACEL, ">>$ACE_fluence_archive_out") or die "Cannot append to ACE fluence archive $ACE_fluence_archive\n";
    print ACEL "$histcount[-1]";
    open (ALTF, ">$alert_file_out") or die "Cannot write to ACE alert counter file $alert_file\n";
    print ALTF "0 0\n";
}

close(AL);
close(ACEL);
close(ALTF);

#-----------------------------------------------------------------
# Update the Chandra altitude direction file: cxodirect.dat
#-----------------------------------------------------------------
open (CXOW, ">$direction_file_out") or die "No CXO altitude information found in $direction_file!\n";
   print CXOW "$direct\n";
close(CXOW);

# set the email addresses for people to be alerted

#################################################################################
#
#  send_email
#
#################################################################################
sub send_email
 {
   # Create the email lists
   $GreggEmail = "ggermain\\\@cfa.harvard.edu";
   $GreggPhone = " 6177850976\\\@vtext.com";

   $JohnZEmail = "john.zuhone\\\@cfa.harvard.edu";
   $JohnZPhone = "7817085004\\\@vtext.com";

   $PaulPEmail = "pplucinsky\\\@cfa.harvard.edu";
   $PaulPPhone = "6177214366\\\@vtext.com";

   $CatherineGEmail = "cgrant\\\@mit.edu";
#   $CatherineGEmail = "cegrant\\\@cfa.harvard.edu";
   $CatherineGPhone = "6175842686\\\@vtext.com";

   $DickEEmail = "redgar\\\@cfa.harvard.edu";
   $DickEPhone = "6178668615\\\@tmomail.net";

   $RoyceBEmail = "buehler\\\@space.mit.edu";
   $RoyceBPhone = "6178518470\\\@vtext.com";

   $JackSteinerEmail = "James.Steiner\\\@cfa.harvard.edu";
   $JackSteinerPhone = "6176809306\\\@vtext.com";

   $JimFrancisEmail = "francisj\\\@mit.edu";
   $JimFrancisPhone = "7742702359\\\@msg.fi.google.com";
   
   $AcisdudeEmail = "${GreggEmail}, ${PaulPEmail}, ${CatherineGEmail}, ${RoyceBEmail}, ${JohnZEmail}, ${JackSteinerEmail}, ${$JimFrancisEmail}";

   $AcisdudeEmailPhone = "${GreggPhone}, ${PaulPPhone}, ${CatherineGPhone}, ${JohnZPhone}, ${JackSteinerPhone}, ${JimFrancisPhone}, ${AcisdudeEmail}";

   $OpsGenie_yellow_alert_addr = "acis_yellow_alert\\\@alrmns.opsgenie.net";
   $OpsGenie_red_alert_addr = "acis_red_alert\\\@alrmns.opsgenie.net";

   
  #
  #  Operational
  #

  #
  #  A-Team
  #
   open (MAIL, "|mailx -s '$host - ACIS FLUENCE ALERT (ACE P3 Channel)!!' $AcisdudeEmail");
   print MAIL $msg;
   close MAIL;
  
  # Open the mail to OpsGenie
  open(MAIL, "|mailx -s '$host - ACIS FLUENCE ALERT (ACE P3 Channel)!!' $OpsGenie_yellow_alert_addr");
  print MAIL $msg;
  close MAIL;
   
  #
  #  Me only for testing purposes.
  #
#  open (MAIL, "|mailx -s '$host - ACIS FLUENCE ALERT (ACE P3 Channel)!!' ggermain\@cfa.harvard.edu");
#  print MAIL $msg;
#  close MAIL;
 }

#################################################################################
#
#  send_email_to_acisdude
#
#################################################################################
sub send_email_to_acisdude
 {
   # Create the email lists
   $GreggEmail = "ggermain\\\@cfa.harvard.edu";
   $GreggPhone = " 6177850976\\\@vtext.com";

   $JohnZEmail = "john.zuhone\\\@cfa.harvard.edu";
   $JohnZPhone = "7817085004\\\@vtext.com";

   $PaulPEmail = "pplucinsky\\\@cfa.harvard.edu";
   $PaulPPhone = "6177214366\\\@vtext.com";

   $CatherineGEmail = "cgrant\\\@mit.edu";
#   $CatherineGEmail = "cegrant\\\@cfa.harvard.edu";
   $CatherineGPhone = "6175842686\\\@vtext.com";

   $DickEEmail = "redgar\\\@cfa.harvard.edu";
   $DickEPhone = "6178668615\\\@tmomail.net";

   $RoyceBEmail = "buehler\\\@space.mit.edu";
   $RoyceBPhone = "6178518470\\\@vtext.com";

   $JackSteinerEmail = "James.Steiner\\\@cfa.harvard.edu";
   $JackSteinerPhone = "6176809306\\\@vtext.com";

   $AcisdudeEmail = "${GreggEmail}, ${PaulPEmail}, ${CatherineGEmail}, ${RoyceBEmail}, ${JohnZEmail}, ${JackSteinerEmail}, ${$JimFrancisEmail}";
   $AcisdudeEmailPhone = "${GreggPhone}, ${PaulPPhone}, ${CatherineGPhone}, ${JohnZPhone}, ${JackSteinerPhone}, ${JimFrancisPhone}, ${AcisdudeEmail}";

  #
  #  A-Team
  #
  open (MAIL, "|mailx -s '$host - ACIS BOGUS ACE P3 ALERT',  $AcisdudeEmail" );
  print MAIL $msg;
  close MAIL;
  #
  #  Me
  #
  #open (MAIL, "|mailx -s '$host - ACIS BOGUS FLUX ALERT (ACE P3)!!' gregg\@head.cfa.harvard.edu");
#  	print MAIL $msg;
#	close MAIL;
 } # END SEND_EMAIL_TO_ACISDUDE

sub LOCK_SH()  { 1 }     #  Shared lock (for reading)
sub LOCK_EX()  { 2 }     #  Exclusive lock (for writing)
sub LOCK_NB()  { 4 }     #  Non-blocking request (don't stall)
sub LOCK_UN()  { 8 }     #  Free the lock (careful!)


#DISTRIBUTION LIST V3.0
#yellow limit trip:
#------------------
# acisdude@head.cfa.harvard.edu
#sot_lead\@head.cfa.harvard.edu
#pgf\@space.mit.edu
#goeke\@space.mit.edu

#red limit trip:
#---------------
#  6177214366\@vtext.com          - Paul's phone
#  6178518470\@vtext.com          - Royce's phone
#  6177850976\@vtext.com          - Gregg's phone
#  6178668615\@vtext.com          - Dick Edgar's phone


#pplucinsky\@vzw.blackberry.net - Paul's phone
#sot_lead\@head.cfa.harvard.edu
#pgf\@space.mit.edu
#goeke\@space.mit.edu


# Defunct
#---------
#6178723731\@vtext.com          - Joe's phone
#6177216763\@vtext.com          - Nancy's phone
#joseph.depasquale\@vzw.blackberry.net - Joe's phone
#dschwartzo\@vzw.blackberry.net - Dan's phone
