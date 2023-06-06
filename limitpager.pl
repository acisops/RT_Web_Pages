#!/usr/bin/env perl 

#ACIS Limit Pager - version 1.1
#Evaluation of real-time data when in COMM with the spacecraft
#yellow and red limit checks for ACIS thermal and electrical values 
#pages will be sent to ACIS Team, and sot_lead if 2 successive readings are 
#outside of defined limits
#email sent for any combination of red and yellow, or 2 yellow violations; 
#page only sent for 2 red violations

#Revision History
# - removed individual SOT email addresses and replaced with sot_lead
#   (Nov 20, 2001 - SV)

#written by:  Joe DePasquale
#started:     September 7, 2001
#last update: February 8, 2005 (JD)

#UPDATES:
#Updated limits will be added soon - updated: 15 Oct 2001
#locates OBSID from acisformat.log 
#locates Altitude and Direction from /proj/rac/ops/ephem/gephem.dat  
#takes as input ACIS log files residing in 
#/export/acis-flight/primary/acis/bin/LOGFILES
#The values for the electrical and thermal MSID's in these files are 
#continuously checked against limit boundaries.
#version 1.1 - updated log files, updated email addresses / email content, AOS paging
#version 1.2 - updated for use in primary page
#version 1.3 - added status bit evaluation, added alert file cleanup when not in COMM, added Cold Radiator perigee passage logic
#version 1.4 - removed AOS page -for use in primary page, added email addresses
# current (email): JD, SV, PP, YB, DS, PF, BG, EB
# current (page): JD, SV, PP, YB, DS
# AUG1602 - updated email addresses - includes cell phone email for JD, SV, PP, YB, regular email for RB
# DEC0502 - updated email addresses - name@myvzw.com no longer works  
# DEC1902 - altered status bit trips criteria so that emails/pages are spawned once after 2 successive trips
# (in response to DPA anomaly (pages continued indefinitely))
# JAN2303 - added indication that limit trips are "DATA QUALITY" trips to email text
#version 1.2 - APR3003 - modified limits for 1PIN1AT, 1PDEA[AB]T, 1DPAM[YZ]T,added code to evaluate dither status 
#  NOTE! - version number changed to 1.2 to coincide with CVS version number
#version 1.4 - updated email addresses
#update 02/08/05 - adjusted PSMC limits (1PIN1AT and 1PDEA[AB]T)
#update 05/04/06 - adjusted limits for 1DEAMZT, 1DPAM[Y/Z]T (yel hi = +30 C)
#update 01/28/08 - adjusted Yel Hi limit for 1SSMYT from +20 C to +25 C (also added Paul's blackberry address)
#update 02/15/08 - adjusted Yel Hi limits for 1SSMYT (+25 to +30) and 1SSPYT (+20 to +25)
#
# Script updated by: Gregg Germain
#            update: 16 March, 2011
#            update: Move to han; major change to create one set of files for
#                    our real time web pages. Uses "getpath()" to
#                    select path roots
#
#check for AOS or LOS, allow 5.5 min difference between current time and last update.
#
# UPDATE 07/05/11 - Modified H&S Yellow High limits from 30.0(C) to 35.0(C) for the following:
#       1DEAMZT
#       1DPAMYT
#       1DPAMZT
#
# UPDATE 11/03/11 - TXings LED bit pattern recognition mods
#                 - also commented the code
#                 - also added captures for 1STAT3ST and 1STAT0ST
#                 - Updated limits for:
#                     1CRAT, 1CRBT
#                     1SSMYT, 1SSPYT
#                     1WRAT, 1WRBT
#
# UPDATE 07/17/12 - Changed Data Quality Yellow Low limit of 1DACTBT to -23.5 from -21.0
#
#
# Update: 15 November, 2012
#         Gregg Germain
#         Modified for use on 64bit LINUX
#         Removed GetPathandNode() as all LINUX instances will
#         originate from /export/acisflight
#
# Update: 6 August, 2015
#         Gregg Germain
#         limitpager_V1.5.pl
#         Modified alerts. Yellow go to ACIS Ops Email
#                          Red goes to ACIS Ops Email and Text
#
# Update: 12 August, 2015
#         Gregg Germain
#         limitpager_V1.6.pl
#         Modified all limit ranges to be Health and Safety only
#         
#
# Update: 21 August, 2015
#         Gregg Germain
#         limitpager_V1.7.pl
#         Modified limit ranges of: 1DAHHBVO
#                                   1DAH
#                                   1DAHBCU
#
# Update: 14 December, 2015
#         Gregg Germain
#         limitpager_V1.8.pl
#         Modified limit ranges of: 1DEN1AVO
#                                   1DEN1BVO
#                                   1SSMYT
#                                   1SSPYT
#         Removed the phrase "data quality" from the email text
#         Added John Zuhone to the alert list
#
#
# Update: April 4, 2016
#         Gregg Germain
#         limitpager_V1.8.pl
#         Used new utility - GetNodeName to obtain the name of the node
#                            And place it in the email subjust line
#
# Update: April 21, 2016
#         Gregg Germain
#         limitpager_V2.0.pl
#         Use ReadLimitsFile utility to obtain limits and have all routines
#         use the same file.
#         Also set up easy-to-grasp phone list.
#         
# Update: March 28, 2018
#         limitpager_V2.1.pl
#         Gregg Germain
#         Adding PGF, Kari Haworth, and Jim Francis  to the alert list.
#
# Update: April 5, 2019
#         limitpager_V2.2.pl
#         Gregg Germain
#         - Removing Kari Haworth and Dick Edgar
#         - Adding Jack Steiner
#         - Moving Catherine back to cgrant@mit.edu
#
# Update: September 21, 2022
#         limitpager_V2.3.pl
#         - updated phone lists.

# Update: October 24, 2022
#         limitpager_V2.4.pl
#         - Modified email and text alerts to space out the text alerts
#           with a 10 second delay loop.
#         - Added OpsGenie email addresses to the alert email and text
#           lists
#
# Update: February 6, 2023
#              limitpager_V2.5.pl
#              - arranged for the URL specified in alert emails to be the one
#                specific to the R/T machine that is issuing the alert email.
#
#  Update: May 3, 2023
#                limitpager_V2.6.pl
#                Gregg Germain
#                - Adding Jim Francis to the acisdude lists which brings him into the yellow alerts lists
#                - Removing explicit  Jim Francis addresses from the red alert lists
#                  as he's now in the acisdude lists
###########################################################################

# use warnings;
use Sys::Hostname;

require "/export/acis-flight/UTILITIES/GetNodeName.pl";
require "/export/acis-flight/UTILITIES/ReadLimitsFile.pl";
require "/export/acis-flight/UTILITIES/GetUDP.pl";

# Obtain the upcased node name
$host = GetNodeName();

# Read the values output by a call to GetUDP.pl
($myAcornUDP, $myPmonUDP, $myVloc, $myBaseURL, $myPEloc) = GetUDP();

my $Full_URL = "http:///".$myBaseURL."/acis-mean.html";

# Read in the limits file data
my %userlimits = ReadLimitsFile();

#$mailtype = 0;    # YELLOW ALERT
#$mailtype = 1;    # RED ALERT

# Set the base path
$pathroot = "/export/acis-flight/";

#
# Change Directory to where the .tl files are
#
chdir("/export/acis-flight/acis/bin");

#
# Get the PRESENT date using the perl function `date`, chomp and split it out
#  - date returns something like this: MonJan2012:53:54EST2014
#  - Store final results in $current.....

# remove spaces
@date = split(/\s+/, `date`);

#
# remove any newline
#
chomp(@date[3]);

# pull out hrs:min:secs - this is PRESENT clock time
@current_time = split(/:/, @date[3]);

# current_dec_time is the number of hours since midnight.
# calculate fractional hours; Take the hours [0] and add to that 
#                             the minutes [1] divided by 60.
$current_dec_time = $current_time[0]+($current_time[1]/60);

# Now we need to grab the time from the FORMAT .tl file

#
# look for a TL file that has the term "FORMAT" in it's name
# e.g. acisFORMAT_00418392261.32.tl
#
@format = split(/\s+/, `ls -l | grep FORMAT`);

# @format is an ls -l line for the FORMAT tl file
# format[6] is the day of the month

#how can that possibly work - [6] is the day of the month?
# @old_time = split(/:/, $format[6]);

@old_time = split(/:/, $format[7]);

$old_dec_time = $old_time[0]+($old_time[1]/60);

$diff = $current_dec_time - $old_dec_time;

#
# Variable for 1STAT LED values
#
$STAT7ST = -1;
$STAT6ST = -1;
$STAT5ST = -1;
$STAT4ST = -1;
$STAT3ST = -1;
$STAT2ST = -1;
$STAT1ST = -1;
$STAT0ST = -1;

#trap if current is past midnight
if ($diff < 0)
   {
    $current_dec_time+=24.0;
    $diff = $current_dec_time - $old_dec_time;  
   }

#refresh the alert file, for new COMM
#
# This code will wipe out any alert.dat file that 
# exists and replace it with an empty file.
if ($diff >= 0.17)
   {
    open (OUT, ">LOGFILES/alert.dat");
    close(OUT);
   }

#decimal diff of 5.5 min = 0.09 hours
#if less than 0.09, continue: we are AOS
if ($diff <= 0.09)
  {    

    #find OBSID 
    chdir ("/export/acis-flight/acis/bin/LOGFILES");    
    $format_file = "acisformat.log";

    # open the FORMAT file and extract the OBSID
    open (FORM, $format_file) || die "ERROR: can't open format file";
    foreach $format_line (<FORM>)
      {
	chomp ($format_line);
	@obsid = split(/\s+/, $format_line);
	if ($obsid[0] eq "OBSID")
	   {
	    $obsid = $obsid[2];
	   }
      } # END FOREACH  $format_line (<FORM>)

    close(FORM);

    #find altitude and direction
    #chdir ("/export/acis-flight/FLU-MON/");
    $alt_file = "/export/acis-flight/FLU-MON/gephem.dat";
    @alt_dir = split(/\s+/, `tail $alt_file`);
    $altitude = $alt_dir[1];
    $direction = $alt_dir[2];

    #reading of log files
    chdir ("/export/acis-flight/acis/bin/LOGFILES");
    #define alert file and date
    $alert = </export/acis-flight/acis/bin/LOGFILES/alert.dat>;

    @date = split(/\s+/, `date -u`);
    $now = join("/", @date);
    chomp($now);

    #define log files - assign the names to variables.
    $acisda = "acisda.log";
    $acisdea = "acisdea.log";
    $acisdpa = "acisdpa.log";
    $acisother = "acisother.log";
    $acistempa = "acistempa.log";
    $acistempb = "acistempb.log";
    $acisstat = "acisleds.log";
    $acisformat = "acisformat.log";
    $acisEPHIN = "acisEPHIN.log";

    #read ALERT.DAT FILE, create if doesn't exist
    #alert file format (#trips, mnemonic, time, value, colorcode)
    #open (ALERT, "+</export/acis-flight/acis/bin/LOGFILES/alert.dat") || open (ALERT, ">/export/acis-flight/acis/bin/LOGFILES/alert.dat");

    if (!open (ALERT, "+</export/acis-flight/acis/bin/LOGFILES/alert.dat"))
       {
        open (ALERT, ">/export/acis-flight/acis/bin/LOGFILES/alert.dat");
       }

    # Now read whatever is in the alert.dat file....if anything.
    @alert_line = split (/\s+/, <ALERT>);

    @new_alert_line = "";

    # OPEN the "acisleds.log" file
    # evaluate each status bit contained in "acisleds.log", listed
    # as one bit value per line in the file.
    #
    # sample line entry:
    #  1stat7st      = 0
    #
    # NOTES - there is no processing for 1STAT3ST!!!!!
    #       - No processing needed for 1STAT0ST because that's the 
    #         64s BEP SW is Running heartbeat

    open (STAT, $acisstat) || die "ERROR: Can't open acisleds.log";

    #
    # Read and Process each line in the acisleds log file - one line per LED
    # $stat_line is the line read in from the file
    #
    foreach $stat_line (<STAT>)
    {
        # set the counter for the number of "bad" bit values to zero.
	$trip = 0;

        # remove the "\n" from the line you read from the file
	chomp ($stat_line);

        # split the line on spaces and store each of the three column
        # values into the three variables
        #
        # e.g. $stat = 1stat7st
        #      $equals = "="
        #      $val = 1 (or 0)
	($stat, $equals, $val) = split(/\s+/, $stat_line);


        # process 99 characters out of the alert_line. 
        # why 99 I don't know....
	for ($i = 0; $i < 99; $i++)
	  {
            # If a string in the alert line contains the value stored in
            # $stat (e.g. 1STAT7ST), then set trip to ...something?????
	    if ($alert_line[$i] eq $stat)
	      {
		$trip = $alert_line[$i-1];
		$status = 1;
	      }
	  } # END for ($i = 0; $i < 99; $i++)
	
        #
        # Now process the line you read from the acisleds.log file. 
        #
        # 1STAT7ST - if the line is the 1STAT7ST line
        # RED (0) -> FIFO Empty	GREEN (1) -> FIFO Not Empty
        #
        # YELLOW ALERT
	#
	if ($stat eq "1stat7st")
	{
            $STAT7ST = $val; 

	    if ($val == 1)
	      {
		if ($status == 1)
		  {
		    $trip+=1;
		    $mailtype = 0;  # YELLOW ALERT

                    # if you have tripped this twice, email message
		    if ($trip == 2)
		      {
		       sendmail($trip, $stat, $now, $val, "Yellow_LED", $mailtype);
		      }
		    @stat7_alert_line = ($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    push(@new_alert_line, @stat7_alert_line);
		  }    
		else
	 	  {
		    $trip+=1;
		    @stat7_alert_line = ($trip, $stat, $now, $val, "Yellow_LED", $mailtype);
		    push(@new_alert_line, @stat7_alert_line);		    
		  }
	      } # END if ($val == 1)
	  } # END if ($stat eq "1stat7st")

        # 1STAT6ST
        # RED (0) -> FIFO Full	GREEN (1) -> FIFO Not Full
        #
	# YELLOW ALERT
	#
	if ($stat eq "1stat6st")
	{
            $STAT6ST = $val;    
	    if ($val == 0)
	    {
		if ($status == 1)
		{
		    $trip+=1;
		    $mailtype = 0;   # YELLOW ALERT
		    if ($trip == 2)
		    {
			sendmail($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    }
		    @stat6_alert_line = ($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    push(@new_alert_line, @stat6_alert_line);
		}    
		else
		{
		    $trip+=1;
		    @stat6_alert_line = ($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    push(@new_alert_line, @stat6_alert_line);		    
		}
	    } # END  if ($val == 0)
	} # END if ($stat eq "1stat6st")


        # 1STAT5ST
        # RED (0) -> BEP Held In Reset	GREEN (1) -> BEP Not In Reset
        #
        #  This is a RED ALERT
        #
	if ($stat eq "1stat5st")
	{
            $STAT5ST = $val;    
	    if ($val == 0)
	    {
		if ($status == 1)
		{
		    $trip+=1;
		    $mailtype = 1;  # RED ALERT
		    if ($trip == 2)
		    {
			sendmail($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    }
		    @stat5_alert_line = ($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    push(@new_alert_line, @stat5_alert_line);
		}    
		else
		{
		    $trip+=1;
		    @stat5_alert_line = ($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    push(@new_alert_line, @stat5_alert_line);		    
		}
	    }
	}

        # 1STAT4ST
        # RED (0) -> BEP A Selected	GREEN (1) -> BEP B Selected
        #
        #  This is a RED ALERT
        #
	if ($stat eq "1stat4st")
	{
            $STAT4ST = $val;    
	    if ($val == 1)
	    {
		if ($status == 1)
		{
		    $trip+=1;
		    $mailtype = 1;  # RED ALERT
		    if ($trip == 2)
		    {
			sendmail($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    }
		    @stat4_alert_line = ($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    push(@new_alert_line, @stat4_alert_line);
		}    
		else
		{
		    $trip+=1;
		    @stat4_alert_line = ($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    push(@new_alert_line, @stat4_alert_line);		    
		}
	    }
	}

        # 1STAT3ST
        # RED (0) -> BEP Code Initialized   GREEN (1) -> BEP Code Initializing
	if ($stat eq "1stat3st")
	   {
            $STAT3ST = $val;    
	   }

        # 1STAT2ST
        # RED (0) -> Watchdog Boot	GREEN (1) -> Normal Boot
        #
        # YELLOW ALERT
	#
	if ($stat eq "1stat2st")
 	  {
            $STAT2ST = $val;    
	    if ($val == 0)
	       {
		if ($status == 1)
		   {
		    $trip+=1;
		    $mailtype = 0;  # YELLOW ALERT
		    if ($trip == 2)
		    {
			sendmail($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    }
		    @stat2_alert_line = ($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    push(@new_alert_line, @stat2_alert_line);
	 	   }    
		else
		   {
		    $trip+=1;
		    @stat2_alert_line = ($trip, $stat, $now, $val, "Red_LED", $mailtype);
		    push(@new_alert_line, @stat2_alert_line);		    
		   }
	       } # ENDIF if ($val == 0)
	  } # ENDIF ($stat eq "1stat2st")


        # 1STAT1ST
        # RED (0) -> Science Active	GREEN (1) -> Science Idle
        #
	if ($stat eq "1stat1st")
  	  {
            $STAT1ST = $val;    
	    $scimode = $val;
	  }


        # 1STAT0ST
        # 0 or 1: BEP SW Is Running	Bit Toggles Every 64s
        #
	if ($stat eq "1stat0st")
	  {
            $STAT0ST = $val;    
	  }

    } # end foreach $statline..................
	
    #
    # Now check 1STAT3,2,1,0 LEDS for the TXing trip value
    #
    # NOTE!!!!!  For now this is a yellow alert.
    #
 
    if (($STAT3ST eq 1) &&
        ($STAT2ST eq 1) &&
        ($STAT1ST eq 0) &&
        ($STAT0ST eq 1))
      {
          $mailtype = 0;   # FOR NOW A YELLOW ALERT
          sendmail(1, "TXINGS", $now, $val, "Red", $mailtype);
      }

    # Determine RADMON status
    @tempRAD = split(/\s+/, `tail $acisEPHIN | grep RADPROC`);
    $radmon = $tempRAD[2];

    # Evaluate dither status
    open (FORMAT, $acisformat) || die "ERROR: Can't open acisformat.log";
    foreach $format_line (<FORMAT>)
       {
	$trip = 0;
	chomp ($format_line);
	($format, $equals, $dither_status) = split(/\s+/, $format_line);
	for ($i = 0; $i < 99; $i++)
	{
	    if ($alert_line[$i] eq $format)
	    {
		$trip = $alert_line[$i-1];
		$status = 1;
	    }
	}
	if ($format eq "DITHER")
	   {
	    if ($dither_status eq "DISA")
	       {
		if ($status == 1)
		   {
		    $trip+=1;
		    $mailtype=0;   # YELLOW ALERT
		    if ($trip == 2 && $scimode == 0 && $radmon eq "ENAB")
		       {
			sendmail($trip, $format, $now, $dither_status, "DITHER_STATUS", $mailtype);
		       }
		    @dither_status_alert = ($trip, $format, $now, $dither_status, "DITHER_STATUS");
		    push(@new_alert_line, @dither_status_alert);
		   }
		else
		   {
		    $trip+=1;
		    @dither_status_alert = ($trip, $format, $now, $dither_status, "DITHER_STATUS");
		    push(@new_alert_line, @dither_status_alert);
		   } # END ELSE Status is not equal to 1
	       } # ENDIF ($dither_status eq "DISA")
	   } # ENDIF ($format eq "DITHER")
       } # END FOREACH $format_line (<FORMAT>)

#---------Inline limit assignments STARTED here

#---------Inline limit assignments ENDED here
  
    # Send a reference to the limits file hash in to the subroutine
    # Args: name of log file, pointer reference to limits variable,  New Limits hash
    check_file($acisda, $ref_to_da, \%userlimits);
    check_file($acisdea, $ref_to_dea, \%userlimits);
    check_file($acisdpa, $ref_to_dpa, \%userlimits);
    check_file($acisother, $ref_to_other, \%userlimits);
    check_file($acistempa, $ref_to_tempa, \%userlimits);
    check_file($acistempb, $ref_to_tempb, \%userlimits);

  
   
    open(OUT, ">$alert");
    print (OUT "@new_alert_line");
    close(OUT);
    close(ALERT);

  } #ENDIF diff <= 0.09



###############################################################################
#
#  Subroutine check_file - Check the MSID value in the log file against its
#                          Yellow and Red hi/low limits. Set alert variable 
#                          if any limit is violated.
#
#                    NOTE: This routine assumes you have executed
#:
#                           chdir ("/export/acis-flight/acis/bin/LOGFILES");
#                        
#                           and are sitting in the logfile directory.
#
#                  inputs: name of log file,
#                          pointer reference to limits variable,
#                          New Limits hash variable
#
# Logfiles look like this: start_time     =	00599312052.49
#                          n_frames       =	10
#                          mean_1DPP0BVO  =	 5.26
#                          sigma_1DPP0BVO =	0.00
#                          ................
#			   mean_1DPAMZT   =	31.69
#			   sigma_1DPAMZT  =	0.00
#			   mean_1DPAMYT   =	28.84
#			   sigma_1DPAMYT  =	0.00
#			   end_time       =	00599312347.69
#
#
###############################################################################
    sub check_file
      {
        # Grab the three expected arguments
        #
        # Get the name of the log file which is located at:
        #          /export/acis-flight/acis/bin/LOGFILES
	my ($log) = $_[0];

        # Get the name of the variable containing the limits (old)
	my ($type) = $_[1];

        # Get the name of the hash variable containing the limits (NEW)
	my ($limits) = $_[2];

	$mailtype = 0;
	#open and read log file
	open (LOG, $log) || die "ERROR: can't open log file"; 

        # Initialize the index into the array   
	$dummy = 0;

        # Process each line in the .log file
        # For each log line in the file, we are going to cycle through the
        # entries in the hash table. If we get a match of MSID, then we'll test the values.
	foreach $log_line (<LOG>)
	  {
            # Remove the newline
	    chomp ($log_line);

            # Extract the MSID name, the equal sign, and the numeric value of the MSID
	    ($mnemonic, $equals, $value) = split(/\s+/, $log_line);

            # Now split the mnemonic based upon underscore to separate the "mean" or 
            # "sigma" from the MSID name
	    @msid = split(/_/, $mnemonic);

            # The format of the log file has two lines for each MSID: mean and sigma
            #            start_time    =	00582900215.82
            #            n_frames      =	10
            #            mean_1WRBT    =	-82.00
            #            sigma_1WRBT   =	0.00
            # and so on....we want the line that begins with "mean" because that line
            # Contains the value we are testing against.
	    if ($msid[0] eq mean)
	      {

#------------------>
                # IMPORTANT:  The MSID is checked if and only if it appears in the 
                #             /export/acis-flight/UTILITIES/engplot_limits file
                #             It is THIS FILE that controls what MSIDs are checked 
                #             and not whether or not the MSID appears in a log file.
                if (exists $limits->{$msid[1]})
		{
		    $flag = 0;
		    $trip = 0;

		    #check the alert file to see if this has happened before
		    for ($i = 0; $i < 99; $i++)
		      {
			if ($alert_line[$i] eq $msid[1])
			{
			    $trip = $alert_line[$i-1];
			    $flag = 1;
			    $color = $alert_line[$i+3];
			}
		      }# ENDFOR for ($i = 0; $i < 99; $i++)

		    # Check Limits
		    # 
		    # YELLOW ALERT
                    #                    YL    YH     RL     RH
                    #           0         1     2     3      4
		    # OLD ["1DAHBVO",    0.0, 15.0, -999.0, 999.0],    
		    #
                    # CHECK 1 - If the value is GTE Red Low and LE Yellow Low

                    # Check for Yellow Low violation:  If the value is between Red low and Yellow low, 
                    # incluseive, then it's a Yellow Low violation
		    if ($value >= $limits->{$msid[1]}{"Red_Low"} && $value < $limits->{$msid[1]}{"Yellow_Low"})
		      {
			$mark = "YELLOW_LO";

			if ($flag == 1)
			  {
			    $trip+=1;
			    $mailtype = 0;    # YELLOW ALERT
			    if ($trip == 2)
			      {
				sendmail($trip, $msid[1], $now, $value, $mark, $mailtype);
			      } # END IF ($trip == 2)

			    @ylo_alert_line = ($trip, $msid[1], $now, $value, $mark);
			    push(@new_alert_line, @ylo_alert_line);
			  }    # END $flag IS equal to 1
			else
			  {    
			    $trip+=1;
			    @ylo_alert_line = ($trip, $msid[1], $now, $value, $mark);
			    push(@new_alert_line, @ylo_alert_line);
			  }
		      } # ENDIF ($value >= $limits->{$msid[1]}{"Red_Low"} && $value < $limits->{$msid[1]}{"Yellow_Low"})

		    # Yellow Hi, CODE = 0  YELLOW ALERT
                    #                    YL    YH     RL     RH
                    #           0         1     2     3      4
		    # OLD ["1DAHBVO",    0.0, 15.0, -999.0, 999.0],    
		    #
		    # CHECK 2 - If the value GTE Yellow High AND LT Red High
		    if ($value >= $limits->{$msid[1]}{"Yellow_High"} && $value < $limits->{$msid[1]}{"Red_High"})
		      {
			$mark = "YELLOW_HI";

			if ($flag == 1)
		  	  {
			    $trip+=1;
			    #logic to check if we are in perigee passage, no email for Cold Radiator violation
			    if (($msid[1] eq "1CRAT" || $msid[1] eq "1CRBT") && ($scimode == 1))
			      {
			    	$trip = 1;
			      }
			    $mailtype = 0; # YELLOW ALERT
			    if ($trip == 2)
			      {
                                #  Yellow_hi
				sendmail($trip, $msid[1], $now, $value, $mark, $mailtype);
			      }
			    @yhi_alert_line = ($trip, $msid[1], $now, $value, $mark);
			    push(@new_alert_line, @yhi_alert_line);
			  }    
			else
			  {    
			    $trip+=1;
			    @yhi_alert_line = ($trip, $msid[1], $now, $value, $mark);
			    push(@new_alert_line, @yhi_alert_line);
			  } # END if ($flag == 1)
		      } # END  if ($value >= $limits->{$msid[1]}{"Yellow_High"} && 

                    #                    YL    YH     RL     RH
                    #           0         1     2     3      4
		    # OLD ["1DAHBVO",    0.0, 15.0, -999.0, 999.0],    
		    #Red Lo/Hi  CODE = 1 means RED
                    # CHECK 3 - If the value is LTE to  Red low OR GTE Red High - it's a red alert
		    if ($value <= $limits->{$msid[1]}{"Red_Low"} ||  $value >= $limits->{$msid[1]}{"Red_High"})
		      {
                        # Since the test is either below Red low or above red high, see which one
                        # it is and mark it accordingly
			if ($value <= $limits->{$msid[1]}{"Red_Low"})
                          {
			    $mark = "RED_LOW";
			  }
			else
                          {
			    $mark = "RED_HIGH";
			  }

      			if ($flag == 1)
			{
			    $trip+=1;
			    if ($color == $mark)
			    {
			     	$mailtype = 1;    # RED ALERT
				if ($trip == 2)
				{
				    sendmail($trip, $msid[1], $now, $value, $mark, $mailtype);
				}
				@red_alert_line = ($trip, $msid[1], $now, $value, $mark);
				push(@new_alert_line, @red_alert_line);
			    }
			    else 
			    {
				$mailtype = 0;    # YELLOW ALERT
				if ($trip == 2)
				{
				    sendmail($trip, $msid[1], $now, $value, $mark, $mailtype);
				}
				@red_alert_line = ($trip, $msid[1], $now, $value, $mark);
				push(@new_alert_line, @red_alert_line);
			    }
			}    
			else
			{    
			    $trip+=1;
			    @red_alert_line = ($trip, $msid[1], $now, $value, $mark);
			    push(@new_alert_line, @red_alert_line);
			}
		      } #ENDIF ($value < @{$type}[$dummy]->[3] || $value > @{$type}[$dummy]->[4])  

#----------------------->
		} # if (exists $limits->{$msid[1]})

	    } # ENDIF if ($msid[0] eq mean)
	} # END foreach $log_line (<LOG>)

    }  # ENDSUB CHECK_FILE


######################################################################
#
# sendmail - sub routine for sending the message out
#
#     inputs: $num_trips
#             $id    - MSID  string
#                    - string used in the body of the email message
#             $date
#             $value
#             $color - yellow_hi, Yellow_low, Red_low, red_hi; string
#                    - string used in the body of the email message
#             $code  - mail type  int, 
#                    - indicates a Yellow alert (0) or red alert (1)
#
#######################################################################

    sub sendmail
    { 
	my ($num_trips) = $_[0];
	my ($id) = $_[1];
	my ($date) = $_[2];
	my ($value) = $_[3];
	my ($color) = $_[4];
	my ($code) = $_[5];
	    
        # Create the email lists
        $GreggEmail = "ggermain\\\@cfa.harvard.edu";
        $GreggPhone = " 6177850976\\\@vtext.com";

        $JohnZEmail = "john.zuhone\\\@cfa.harvard.edu";
        $JohnZPhone = "7817085004\\\@vtext.com";

	$PaulPEmail = "pplucinsky\\\@cfa.harvard.edu";
        $PaulPPhone = "6177214366\\\@vtext.com";

	$CatherineGEmail = "cgrant\\\@mit.edu";
#	$CatherineGEmail = "cegrant\\\@cfa.harvard.edu";
        $CatherineGPhone = "6175842686\\\@vtext.com";

        $DickEEmail = "richard.j.edgar\\\@gmail.com";
        $DickEPhone = "6178668615\\\@tmomail.net";

        $RoyceBEmail = "buehler\\\@space.mit.edu";
        $RoyceBPhone = "6178518470\\\@vtext.com";

        $PGFEmail = "pgf\\\@space.mit.edu";
        $PGFPhone = "6179971875\\\@vtext.com";

        $JimFrancisEmail = "francisj\\\@mit.edu";
        $JimFrancisPhone = "7742702359\\\@msg.fi.google.com";

        $JackSteinerEmail = "James.Steiner\\\@cfa.harvard.edu";
        $JackSteinerPhone = "6176809306\\\@vtext.com";

        $BGoekeEmail = "goeke\\\@space.mit.edu";

	$JustMe = "${GreggEmail}, ${GreggPhone}";

	$OpsGenie_yellow_alert_addr = "acis_yellow_alert\\\@alrmns.opsgenie.net";
	$OpsGenie_red_alert_addr = "acis_red_alert\\\@alrmns.opsgenie.net";

        $AcisdudeEmail = "${GreggEmail}, ${PaulPEmail}, ${CatherineGEmail}, ${RoyceBEmail}, ${JohnZEmail}, ${JackSteinerEmail}, ${JimFrancisEmail}";
        $AcisdudePhone = "${GreggPhone}, ${PaulPPhone}, ${CatherineGPhone}, ${JohnZPhone}, ${JackSteinerPhone}, ${JimFrancisPhone}";
        $MITPhone = "$PGFPhone, $JimFrancisPhone";
	
	# Set up arrays of addresses for Red and Yellow alerts
	@RedAlertEmailList = ($AcisdudeEmail, $PGFEmail,  $BGoekeEmail);
	@RedAlertTextList = ($AcisdudePhone, $PGFPhone);

       #
       # Formulate the body of the email based upon whether it's a Dither, TXING or General MSID violation
       #
	if ($id eq "DITHER")
          {
	    $msg = sprintf "\$host - LIMITPAGER ACIS DITHER ALERT During Current COMM Pass!\n"; 
	    $msg .= sprintf "Dither Status tripped 2 times!\n";
	    $msg .= sprintf "Dither is DISABLED!\n";
	    $msg .= sprintf "******************************\n";
	    $msg .= sprintf "Current OBSID: $obsid\n";
	    $msg .= sprintf "Current Altitude / Direction: $altitude / $direction\n";	
	    $msg .= sprintf "Date and Time: @date\n"; 
	    $msg .= sprintf "Check ".$Full_URL." for latest info.\n";
	  }elsif ($id eq "TXINGS")
          {
	    $msg = sprintf "\n$host - LIMITPAGER ACIS TXINGS ALERT During Current COMM Pass!\n"; 
	    $msg .= sprintf "THRESHOLD CROSSING!\n";
	    $msg .= sprintf "******************************\n";
	    $msg .= sprintf "Current Altitude / Direction: $altitude / $direction\n";	
	    $msg .= sprintf "Date and Time: @date\n"; 
	    $msg .= sprintf "Check ".$Full_URL." for latest info.\n";
 	  }
	else   # neither DITHER nor TXINGS - general MSID violation
	  {
	    $msg = sprintf "\nLimit Trip $host - LIMITPAGER ACIS ALERT During Current COMM Pass!\n"; 
	    $msg .= sprintf "$color  limit tripped $num_trips times!\n";
	    $msg .= sprintf "MSID: $id\n";
	    $msg .= sprintf "Last Violation Value: $value\n";
	    $msg .= sprintf "******************************\n";
	    $msg .= sprintf "Current OBSID: $obsid\n";
	    $msg .= sprintf "Current Altitude / Direction: $altitude / $direction\n";	
	    $msg .= sprintf "Date and Time: @date\n"; 
	    $msg .= sprintf "Check ".$Full_URL." for latest info.\n";
	  } # END neither DITHER nor TXINGS - general MSID violation
	
        #
        # Code equals 1 so it's a RED ALERT
        #    
	if ($code == 1)
          {
	   # First send out all the emails in one go
           open(MAIL, "|mailx -s 'Limit Pager RED ALERT - $host - ACIS LIMIT TRIP!' @RedAlertEmailList");
	   print MAIL $msg;
	   close MAIL;

           # Now create a loop to send out all the texts serially with a 10 second delay between
	   # the loops
	   foreach (@RedAlertTextList)
	     {
	       open(MAIL, "|mailx -s 'Limit Pager RED ALERT - $host - ACIS LIMIT TRIP! - Loop' $_");
               print MAIL $msg;
	       close MAIL;

	       # Delay for 10 seconds
	       sleep(10);
	     } # END foreach (@RedAlertTextList}

	   # Send the red alert out via OpsGenie
           open(MAIL, "|mailx -s 'Limit Pager RED ALERT - $host - ACIS LIMIT TRIP!' $OpsGenie_red_alert_addr");
	   print MAIL $msg;
	   close MAIL;

           # Test list - just me
	   #open(MAIL, "|mailx -s 'TEST Limit Pager - RED! ALERT! $host - TEST ACIS LIMIT TRIP!' $JustMe ");
 	 }
	else # Else it's a YELLOW ALERT
         {
           #
           # Operational List
	   #
	   # Open the mail list of individual recipients.
	   open(MAIL, "|mailx -s 'Limit Pager YELLOW ALERT - $host - ACIS LIMIT TRIP!' $AcisdudeEmail");
	   # Now send the mail  out
           print MAIL $msg;
           close MAIL;

	   # Open the mail to OpsGenie
           open(MAIL, "|mailx -s 'Limit Pager YELLOW ALERT - $host - ACIS LIMIT TRIP!' $OpsGenie_yellow_alert_addr");
	   # Now send the mail out via OpsGenie
           print MAIL $msg;
           close MAIL;

           #
           #  Test List just me
           #
	   #open(MAIL, "|mailx -s 'TEST Limit Pager YELLOW ALERT - $host - ACIS LIMIT TRIP!'   $JustMe");
	}


        # END filling the body of the email
    }  # end SUBROUTINE sendmail
 
#DISTRIBUTION LIST V2.0
#yellow limit trip:
#------------------
#sot_lead\@head.cfa.harvard.edu
#pgf\@space.mit.edu
#goeke\@space.mit.edu
#eab\@space.mit.edu

