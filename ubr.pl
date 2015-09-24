#!/usr/bin/env perl
#
#
# UCOS Backup Reporter - ubr
#
# Copyright (C) 2015 Manuel Azevedo
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# You can configure a cron job to send this report
# perl ubr.pl | mail -a "Content-type: text/html" -a "From:ubrbackup@backupexample.com" -s "ubr Report" user@example.com


#
# Change log:
# Version 0.1 - Initial version
# Version 0.2 - Fix sort issue
# Version 0.3 - Adding configuration file and command line switches
#
#
# Command line switches:
#  See readCLIArguments() function

use constant version     => "0.3 - 24.Sep.2015";
use constant programName => "UCOS backup reporter - ubr";
use constant developer   => "Manuel Azevedo";


use strict;
use File::Find;
use Data::Dumper;
use Time::Local;
use XML::Simple qw(:strict);
use Net::Domain qw(hostfqdn);
use Getopt::Long;
use Config::Std;

#
# App parameters

my $configFile          = "ubr.conf";

my $baseDir             = "./backup";

my $newerBackupMaxDays  = 3;

my $HTMLRemoveBaseDir   = 1;
my $HTMLRemoveXMLString = 1;

my $debug               = 0;

my $sortNewestFirst     = 1;
my $sortDirectoriesAsc  = 1;

# Do not change beyond this point
#


#
# Constants and global variables
#

# UCOS backup manifest XML file names usually end with this value
my $xmlString           = "drfComponent.xml";

# Counts the total number of manifest files founds
my $fileCounter         = 0;

# Stores the entire information about backups found. Think database :)
my %backupData;

# Stores a list of directories
my @backupDirectories;



#
# Functions
#


#
# function readCLIArguments()
#
# Read command line arguments and parse them.
# Display help and version information
# As CLI options take priority over configuration file options and built-in defaults
sub readCLIArguments{
    
    my $help;
    my $version;

    # Get the arguments from the CLI
    Getopt::Long::Configure ("bundling");
    GetOptions(
    'basedir|b'           => \$baseDir,
    'newermaxdays|n'      => \$newerBackupMaxDays,
    'removebasedir!'      => \$HTMLRemoveBaseDir,
    'removexmlstring!'    => \$HTMLRemoveXMLString,
    'sortnewestfirst!'    => \$sortNewestFirst,
    'sortdirectoriesasc!' => \$sortDirectoriesAsc,
    'help|h'              => \$help,
    'version|V'           => \$version,
    'debug|d'             => \$debug,
    'conf|c'              => \$configFile
    );
    
    # Print help to the user. Exit!
    if ($help){
    print "\nUsage: ";
    print $0." -options \n\n";
    print "where options are:\n\n";
    print " Options with arguments:\n";
    print " --conf         or -c   Another config file.                        Default value is '$configFile'\n";
    print " --basedir      or -b   The root directory where the backups are.   Default value is '$baseDir'\n";
    print " --newermaxdays or -n   The minimum number of  days a  directory    Default value is ".formatDays($newerBackupMaxDays)."\n";
    print "                        newest backup is considered expired.      \n\n"; 
    print " Boolean (True/False) options:\n";
    print " --removebasedir        Removes the base directory path from the    Default value is '".textBoolean($HTMLRemoveBaseDir)."'\n";
    print "                        directory listing.\n";
    print " --removexmlstring      Removes  '_drfComponent.xml'  from   the    Default value is '".textBoolean($HTMLRemoveXMLString)."'\n";
    print "                        backup job name.\n";
    print " --sortnewestfirst      Sorts newest backup jobs first.             Default value is '".textBoolean($sortNewestFirst)."'\n";
    print " --sortdirectoriesasc   Sorts directories in ascending order.       Default value is '".textBoolean($sortDirectoriesAsc)."'\n\n";
    print " Options without arguments:\n";
    print " --help         or -h   This menu\n";
    print " --debug        or -d   Enable diagnostics debug messages\n\n";
    
    print " Note:    The boolean options can  be negated by replacing '--' with '--no-' and thus make it false.\n\n";
    print " Example: If you want to order the directory  listing  in  descending, \n";
    print "          just write the option as '--no-sortdirectoriesasc' \n\n";
   
    print "These switches overwrite both the built-in defaults or the '$configFile' configuration file \n\n";
    print "All options are case sensitive!\n";
    exit 0;
    }
    
    # Print version information
    if ($version){
    print "\n";
    print "Application : ".programName."\n";
    print "Version     : ".version."\n";
    print "Copyright   : ".developer."\n";
    print "Platform    : $^O\n\n";
    exit 0;
    }
}





#
# function handleFile($x);
#
# Used for file handling, where $x is the entire filename (including directory) returned by find
#
sub handleFile {

    # Temporary Hash to store the data of each file
    my %backupFile;

    # If the found file matches this string and the end of the file, process it
    if ($_ =~ /$xmlString$/) {

        
        my $backupDate;
        my $backupDateEpoch;
        my $backupEpoch;
        my $backupPrimaryHost;

        # The hostname is between two underscores followed by the XML string. If not found, maybe it's an older DRF version
        if ($_ =~ /.*_(.*)_$xmlString$/) {
            $backupPrimaryHost = $1;
        } else {
            $backupPrimaryHost = "= Not defined =";
        }

        # The date format is YYYY-MM-DD-HH-MM-SS and should start at the beginning of the file
        if ($_ =~ /^(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2})_.*/) {
            $backupDate = $1;
        } else {
            $backupDate = "= Invalid date =";
        }

        # Build the hash with the data.
        %backupFile = ( 
            backupFullName    => $File::Find::name,
            backupLocation    => $File::Find::dir,
            backupFile        => $_,
            backupPrimaryHost => $backupPrimaryHost,
            backupDate        => $backupDate,
            backupEpoch       => getEpoch($backupDate),
        );
        
        # Add it to the backupData hash. The index is just used to order the keys.
        my $item = $backupData{$File::Find::dir}{count}++;
        $backupData{$File::Find::dir}{$item} = \%backupFile;
        # Increase the counter index
        $fileCounter++;

    # If it's a directory
    } elsif (-d $_) {
    # Add it to the directories array.
    push @backupDirectories,$File::Find::name;
    }
}

#
# function backupDataSort()
#
# Sorts each directory backup by the order defined in the global variable $sortNewestFirst
#
sub backupDataSort {
    
    # Make a copy and work with backupDataPre
    my %backupDataPre = %backupData;
    # Let's clear backupData
    undef %backupData;

    # Let's traverse the @backupDirectories (sorted) and for each directory sort its elements
    # before adding into the %backupData hash

    foreach my $dir (keys %backupDataPre) {
        debugMsg("backupDataSort: Sorting backups in $dir");
        my %epochList=();
    # Let's create an sub-hash with just the backups we want to sort
        foreach my $item (sort keys $backupDataPre{$dir}) {
            # Ignore the count item
            if ($item ne "count") {
                $epochList{$item} = $backupDataPre{$dir}{$item}{backupEpoch};
            }
        }
    
    # Get the keys ordered by their value in a @keys array. The order is defined by $sortNewestFirst
    my @keys=();
    if ($sortNewestFirst) {
        @keys = sort { $epochList{$b} <=> $epochList{$a} } keys %epochList;
    } else {
        @keys = sort { $epochList{$a} <=> $epochList{$b} } keys %epochList;
    }

    
        my $newItem=0;
        foreach my $oldItem ( @keys ) {
            $backupData{$dir}{$newItem}=$backupDataPre{$dir}{$oldItem};
            $newItem++;
        }
        # Don't forget to copy the total count too :)
        $backupData{$dir}{count}=$backupDataPre{$dir}{count};
    }
}


#
# function getEpoch($x)
#
# Convert Cisco DRF format date to Epoch date
# $x must be a string in the following format: YYYY-MM-DD-HH-MM-SS
# Returns a Unix timestamp
#
sub getEpoch{
    my $dateYear;
    my $dateMonth;
    my $dateDay;
    my $dateHour;
    my $dateMinutes;
    my $dateSeconds;
    

    ($dateYear,$dateMonth,$dateDay,$dateHour,$dateMinutes,$dateSeconds) = ($_[0] =~ /^(\d+)-(\d+)-(\d+)-(\d+)-(\d+)-(\d+)/);
    
    # Timelocal expects the months to be in the format 0..11 instead of 1..12
    return timelocal($dateSeconds, $dateMinutes,$dateHour,$dateDay,$dateMonth-1,$dateYear);
}

#
# function debugMsg($x[,$y][,$z])
#
# Print a debug line if '$debug' is defined. First argument can be a printf string
sub debugMsg{
    if ($debug) {
    printf "<!-- DEBUG > $_[0] -->\n",$_[1],$_[2];
    $|=1;
    }
}

#
# function validateXML($x,$y,$z)
#
# Where:
#  $x is XMLfile to test
#  $y is Date
#  $z is Base directory where to find XML file
#
# Returns total size if all valid, returns "ERROR" if XML is not valid or not found or "MISSING" if TAR file is not found
#
sub validateXML {

    # Get arguments
    my $XMLfile = $_[0];
    my $XMLdate = $_[1];
    my $XMLdir  = $_[2];

    debugMsg("validateXML: $XMLdir/$XMLfile");
    
    # The file needs to exist! If it does not exist, return "ERROR".
    if (-e $XMLdir."/".$XMLfile) {
        debugMsg("validateXML: $XMLfile exists");
    } else {
        debugMsg("validateXML: $XMLfile not found!");
        return "ERROR";
    }


    # Let's assume the backup is a success. Any test that changes this invalidates the backup
    my $XMLstatus = "SUCCESS";

    # The file size is initially empty!
    my $XMLsize = 0;

    # Read the XML file. Force Array for simplicity. Discard root. If error, return error
    my $XMLref = eval { XMLin($XMLdir."/".$XMLfile,ForceArray => 1, KeepRoot => 0,KeyAttr =>[]) };
    return "ERROR" if($@);

    # The XML backup is separated into FeatureObject groups.
    # We need to convert the reference to an array, hence the @{} block!
    my @XMLfeatures = @{ $XMLref->{FeatureObject} };

    debugMsg("validateXML: Found ".scalar(keys @XMLfeatures)." feature(s):");

    # For each one of the FeatureObjects
    for my $featureKey (@XMLfeatures) {
        
        # Check if the status was changed by previous cycle. If so, exit loop
        last if $XMLstatus ne "SUCCESS";
        
        # Change the status of the backup to this object status.
        $XMLstatus=$featureKey->{Status}[0];
        
        debugMsg("validateXML:  Feature: %-80s  Status: %-20s",$featureKey->{FeatureName}[0],$XMLstatus);
         
        # Each FeatureObject contains 1 vServerObject and several ServerObj
        my @XMLservers = @{ $featureKey->{vServerObject}[0]->{ServerObj} };
        
        debugMsg("validateXML:   Found ".scalar(keys @XMLservers)." servers with these backup component(s):");
        
        # For each one of the ServerObjs
        for my $serverKey (@XMLservers) {
            
            # Check if the status was changed by previous check. If so, exit loop
            last if $XMLstatus ne "SUCCESS";
            
            # Change the status of the backup to this object status.
            $XMLstatus=$serverKey->{Status}[0];
        
            debugMsg("validateXML:    Server: %-80s Status: %-20s",$serverKey->{ServerName}[0],$XMLstatus);
            
            # Each ServerObj contains 1 vComponentObject and several ComponentObject
            my @XMLcomponents = @{$serverKey->{vComponentObject}[0]{ComponentObject}};
            
            debugMsg("validateXML:     Found ".scalar(keys @XMLcomponents)." component object(s) for this server:");
            
            # For each of the ComponentObjects
            for my $componentKey(@XMLcomponents){
            
                # Check if the status was changed by previous check. If so, exit loop
                last if $XMLstatus ne "SUCCESS";
                
                # Change the status of the backup to this object status.
                $XMLstatus=$componentKey->{Status}[0];
            
                debugMsg("validateXML:      Component: %-75s Status: %-20s",$componentKey->{ComponentName}[0],$XMLstatus);
                
                # We now have all the information to build the backup file name and check if it exists
                my $tarFile = $XMLdate."_".$serverKey->{ServerName}[0]."_".$featureKey->{FeatureName}[0]."_".$componentKey->{ComponentName}[0].".tar";
               
        debugMsg("validateXML:      Testing file $XMLdir/$tarFile");
 
        # Check if the TAR file exists
                if (-e $XMLdir."/".$tarFile) {
            # TAR file found. Status is "SUCESS"
                    $XMLstatus = "SUCCESS";
            # For this backup add the size of this TAR file to the total
                    $XMLsize += -s $XMLdir."/".$tarFile;
                } else {
            # TAR file was not found
                    $XMLstatus = "MISSING";
                }
                debugMsg("validateXML:       Filename: %-75s Status: %-20s",$tarFile,$XMLstatus);
            }
        }
    }

    # No TAR file in this backup failed, so it's success
    if ($XMLstatus eq "SUCCESS") {
    debugMsg("validateXML: >>> Sucessfull backup using $XMLsize bytes of space");
    # Change the status to the size of the backup
    $XMLstatus = $XMLsize;
    }
    
    # Return size or error status
    return $XMLstatus;
}


#
# function validateBackup()
#
# This function validates the found XML files and updates the global %backupData hash with Status, Size and Age
#
sub validateBackup {
    # For all backup directories found
    foreach my $dir (keys %backupData) {
        debugMsg("%-50s :",$dir);
        # If there are files in this directory
        if ($backupData{$dir}{'count'} > 0) {
            # For each XML file in this directory
            foreach my $item (keys $backupData{$dir}) {
                # Ignore the count item.
                if ($item ne "count") {
                    # The total number of days of a backup is calculated
                    my $days = int((time()-$backupData{$dir}{$item}{'backupEpoch'})/86400);
                    
                    my $backupSize = validateXML($backupData{$dir}{$item}{'backupFile'},$backupData{$dir}{$item}{'backupDate'},$backupData{$dir}{$item}{'backupLocation'});
                    
                    if ($backupSize =~ /ERROR|MISSING/) {
                        debugMsg("validateBackup: Backup $backupData{$dir}{$item}{'backupFile'} is invalid");
                        $backupData{$dir}{$item}{'backupStatus'}=$backupSize;
                    } else {
                        $backupData{$dir}{$item}{'backupStatus'}="SUCCESS";
                        $backupData{$dir}{$item}{'backupSize'}=$backupSize;
                        debugMsg("validateBackup: $backupData{$dir}{$item}{'backupFile'} is $days old and uses $backupSize bytes");
                    }
                }
            }
        } else {
           debugMsg("validateBackup: %-50s directory is empty",$dir);
        }
    }
}

#
# function htmlHeaders()
#
# Print static HTML headers.
#
sub htmlHeaders{
    print '
<!DOCTYPE html>
<html>
 <head>
  <meta charset="UTF-8">
  <title>ubr Report</title>
    <!-- <link rel="stylesheet" type="text/css" href="stylesheet.css" /> -->
    <style type="text/css">
    .ubrTable {
    display:inline-block;
    margin:0px;padding:0px;
    box-shadow: 10px 10px 5px #888888;
    border:1px solid #000000;
    }
    
    .ubrTable table{
    border-collapse: collapse;
    border-spacing: 0;
    margin:0px;padding:0px;
    }
    
    .ubrTable td{
    vertical-align:middle;
    border:1px solid #000000;
    border-width:0px 1px 1px 0px;
    text-align:left;
    padding:7px;
    font-size:10px;
    font-family:Arial;
    font-weight:normal;
    color:#000000;
    }
    
    
    .ubrTable tr:last-child td{
    border-width:0px 1px 0px 0px;
    }
    
    .ubrTable tr td:last-child{
    border-width:0px 0px 1px 0px;
    }
    
    .ubrTable tr:last-child td:last-child{
    border-width:0px 0px 0px 0px;
    }
    
    
    .ubrTable tr:first-child td{
    background:-o-linear-gradient(bottom, #00bfbf 5%, #007f7f 100%);
    background:-webkit-gradient( linear, left top, left bottom, color-stop(0.05, #00bfbf), color-stop(1, #007f7f) );
    background:-moz-linear-gradient( center top, #00bfbf 5%, #007f7f 100% );
    filter:progid:DXImageTransform.Microsoft.gradient(startColorstr="#00bfbf", endColorstr="#007f7f");
    background: -o-linear-gradient(top,#00bfbf,007f7f);
    background-color:#00bfbf;
    border:0px solid #000000;
    text-align:center;
    border-width:0px 0px 1px 1px;
    font-size:14px;
    font-family:Arial;
    font-weight:bold;
    color:#ffffff;
    }
    
    
    .ubrTable tr:first-child td:first-child{
    border-width:0px 0px 1px 0px;
    }
    
    .ubrTable tr:first-child td:last-child{
    border-width:0px 0px 1px 1px;
    }
    
    
    td.bytes{
    text-align:right;
    }
    
    .empty {
    background-color:#b2b2b2;
    }
    
    .warning {
    background-color:#FFCC00;
    }
    
    .ok {
    background-color:#00bf5f;
    }
    
    .expired{
    background-color:#CC0000;
    }

    </style>
 </head>
 <body>
';

}


#
# function htmlDir($x)
#
# Returns directory string $x with or without leading path, as defined by $HTMLRemoveBaseDir boolean
#
sub htmlDir{
    # Read argument
    my $htmldir=$_[0];
    
    # If global variable is true, let's remove the $baseDir from the string
    if ($HTMLRemoveBaseDir) {
    # $baseDir does not contain a forward slash. Include it to remove it too
    $htmldir =~ s/$baseDir\///;
    }
    
    # Return string
    return $htmldir;
}

#
# function htmlXML($x)
#
# Returns Backup XML filename string with or without trailing $xmlString, as defined in $HTMLRemoveXMLString
#
sub htmlXML{
    #Read arguments
    my $htmlxml=$_[0];
    
    # If global variable is true, let's remove the $xmlString from the string
    if ($HTMLRemoveXMLString) {
    # $xmlString does not contain the underscore. Include it to remove it too
    $htmlxml =~ s/_$xmlString//;
    }
    # Return string
    return $htmlxml;
}

#
# function formatLargeNumber($x)
#
# Where $x is the number you want to return in the format XXX XXX XXX

sub formatLargeNumber {
    
    # At each 3rd digit, insert a separator
    
    my $x = $_[0];
    
    1 while ($x =~ s/^(-?\d+)(\d{3})/$1\'$2/);
    
    return $x;
}

#
# function formatDays($x)
#
# Where $x is an integer with the number of days. If $x is 1 it returns '1 day' else returns 'x days'.

sub formatDays {
    
    my $day=" day";
    
    if ($_[0] != 1) {
    $day .= "s";
    }
    
    return $_[0].$day;
}

#
# function textBoolean($x)
#
# When $x is 0, '0', undef or '' it will return false, otherwise always true
sub textBoolean {
    if ($_[0]) {
        return "true";
    } else {
        return "false";
    }
}


#
# function generateReport()
#
#
# This function generates a clean output from the updated %backupData hash.
# Requires that previous updates be executed first to update %backupData hash.
#
sub generateReport {


    
    # Print generic information table
    print "    
    <div class=\"ubrTable\">
    <table>
    <tr>
    <td>Description</td><td>Value</td>
    </tr>
    <tr>
    <td>Report generated timestamp</td><td>".localtime()." - ".hostfqdn()."</td>
    </tr>
    <tr>
    <td>ubr version</td><td>".version."</td>
    </tr>
    <tr>
    <td>Newest backup is expired if it is</td><td>".formatDays($newerBackupMaxDays)." or older</td>
    </tr>
    <tr>
    <td>Total number of directories found</td><td>".(scalar keys @backupDirectories)."</td>
    </tr>
    <tr>
    <td>Total number of directories with backups found </td><td>".(scalar keys %backupData)."</td>
    </tr>
    <tr>
    <td>Total number of XML backup manifest files</td><td>".$fileCounter."</td>
    </tr>
    </table>
    </div>
    <p>

    ";
    
    
    # Start building report table
    print '<div class="ubrTable">';
    print "<table>\n";
    print " <tr>\n";
    print "  <td>Directory</td><td>Overal status</td><td># backups</td><td>Newest backup age</td><td>Backup XML manifest file</td><td>Backup status</td><td>Date</td><td>Size (bytes)</td><td>Age</td>\n";
    print " </tr>\n";


    # For all backup directories found
    foreach my $dir (@backupDirectories) {
    # The total number of backups per directory is stored in "count"
        my $numberBackups=$backupData{$dir}{'count'};
    # Means this is not an empty directory!
        if ( $numberBackups > 0) {
        # As we use spans to agregate all backups from a server, we need to buffer the various
        # backups per directory in this placeholder before we flush it correctly
            my $backupRow ="";
            # Get the epoch from the first item
            my $backupNewer=$backupData{$dir}{'0'}{'backupEpoch'};
            my $backupAge;
        # Let's assume the backup is OK
            my $backupStatus = "OK";
        # Counter of the number of backups per this directory
        my $count=0;
        # Let's now go to each backup in this directory
        foreach my $item (sort keys $backupData{$dir}){
        # The hash item count is ignored. The remaining are used.
                if ($item ne "count") {
            # If this is the first backup, we define a table row
            if ($count > 0) {
            # The backupStatus is mapped directly to the CSS
            $backupRow .= "\n <tr class=\"".lc($backupStatus)."\">\n";
            }
            
            # Include the XML filename
                    $backupRow  .="<td>".htmlXML($backupData{$dir}{$item}{'backupFile'})."</td>";
            # If the backupStatus of a backup is not sucess, the status of the entire directory changes
            # to warning
                    if (($backupData{$dir}{$item}{'backupStatus'} ne "SUCCESS")) {
                        $backupStatus = "WARNING";
                    }
            # The status of the backup
                    $backupRow .="<td>$backupData{$dir}{$item}{'backupStatus'}</td>";
            # The backup date
                    $backupRow .="<td>$backupData{$dir}{$item}{'backupDate'}</td>";
            
            # The backup size
            my $backupSize = formatLargeNumber($backupData{$dir}{$item}{'backupSize'});
                    $backupRow .="<td class=\"bytes\">$backupSize</td>";
            
            # Calculate the total number of days this backup has
                    $backupAge=int((time()-$backupData{$dir}{$item}{'backupEpoch'})/86400);
                    $backupRow .="<td>".formatDays($backupAge)."</td>\n </tr>\n";
            
            # Calculate which backup is newer
                    if ($backupData{$dir}{$item}{'backupEpoch'} > $backupNewer) {
            debugMsg("generateReport: \$backupNewer=$backupNewer - Item $item backupEpoch=$backupData{$dir}{$item}{'backupEpoch'}");
                        $backupNewer=$backupData{$dir}{$item}{'backupEpoch'}
                    }
        # Count the next item
        $count++;
                }
        
            }
        # The number of days of the newer backup
            my $days = int((time()-$backupNewer)/86400);
        # If the backup files look OK, but the newest backup is older than the trigger
        if ($days >= $newerBackupMaxDays and $backupStatus eq "OK") {
        # Backup is expired
        $backupStatus="EXPIRED"
        }
        # Build row for the directory
        print " <tr class=\"".lc($backupStatus)."\">\n";
        print "  <td rowspan=\"$numberBackups\">".htmlDir($dir)."</td>";
            print "  <td rowspan=\"$numberBackups\">$backupStatus</td>";
        print "  <td rowspan=\"$numberBackups\">$numberBackups</td>";
        print "  <td rowspan=\"$numberBackups\">".formatDays($days)."</td>".$backupRow;
        } else {
        # It's an empty directory
        print " <tr class=\"empty\">\n";
            print "  <td>".htmlDir($dir)."</td>\n";
            print "  <td>Empty</td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>\n";
        print " </tr>\n";
        }
    }
    # Finish the table. Include description table with legend.
    print '
     </table>
    </div>
     <p>
     <div class="ubrTable">
     <table>
      <tr>
       <td>Status</td><td>Description</td>
      </tr>
      <tr>
       <td class="ok">OK</td><td>XML OK, Files found</td>
      </tr>
      <tr>
       <td class="warning">WARNING</td><td>Backup is not OK. Please verify next two errors.</td>
      </tr>
      <tr>
       <td class="warning">MISSING</td><td>At least one of the TAR files described in the XML is missing</td>
      </tr>
      <tr>
       <td class="warning">ERROR</td><td>Could not read XML file. XML file might be invalid</td>
      </tr>
      <tr>
       <td class="expired">EXPIRED</td><td>Backup files are OK, but newest backup is older than defined trigger</td>
      </tr>
      <tr>
       <td class="empty">Empty</td><td>No backup XMLs found</td>
      </tr>
     </table>
    </div>
    </body>
  </html>';
}


# Main execution

# Read the configuration file
debugMsg('Main: Getting configuration file');
#readConfigFile();

# Read command line arguments
debugMsg('Main: Getting configuration from command line');
readCLIArguments();



# Let's print the headers first
# IE changes to quirks mode if there are comments (debug outputs are comments)
# before the headers.
htmlHeaders;


# Find backup files and directories
find(\&handleFile,$baseDir);

# Dump %backupData before sorting
#debugMsg("Main: Unsorted hash");
#print Dumper(\%backupData);

# Sorts the %backupData directory backups by defined order
backupDataSort();


#debugMsg("Main: Sorted hash");
#print Dumper(\%backupData);

# The first directory found is the base directory. This should be always empty, so it will be pushed out of the array
shift @backupDirectories;

# Sort the directory array ascending if defined in $sortDirectoriesAsc, else sort descending

if ($sortDirectoriesAsc) {
    @backupDirectories = sort {$a cmp $b} @backupDirectories;
} else {
    @backupDirectories = sort {$b cmp $a} @backupDirectories;
}


debugMsg("Current time in Epoch time (seconds since 1-Jan-1970): ".time());
debugMsg("Total backup directories found           : ".scalar keys @backupDirectories);
debugMsg("Total non-empty backup directories found : ".scalar keys %backupData);
debugMsg("Total XML files found                    : $fileCounter");

# Validate the XML and TAR files
validateBackup;

# Generate report
generateReport;

debugMsg(" *** Program execution ended ***");




