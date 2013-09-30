#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use WebService::TVDB;
use File::Basename;
use File::Path;
use File::Fetch;
use Mac::AppleScript qw(RunAppleScript);

if ($#ARGV != 0) {
	print "Usage: tvtags.pl <TV Show file>\n";
	print "ex. tvtags.pl Firefly - 1x14 - The Message.m4v\n";
	exit(1);
}

######################################################################
# Edit these variables if needed.
######################################################################
my $HD = "yes";
my $api_key = "E5DC4EEFA8A7AA8D";
my $mp4tagger = "MP4Tagger";
my $debug = 0;
my $verbose = 1;
my $logfile = "/Users/cade/tvtags.log";
######################################################################
# DO NOT EDIT ANYTHING BLEOW THIS LINE.
######################################################################

my $SeasonNumber;
my $EpisodeNumber;
my $file = $ARGV[0];
my ($filename, $directories) = fileparse("$file");
my ($show,$Season_Episode,$show_name) = split('\ -\ ', $filename);
if ($Season_Episode =~ m/S(\d+)E(\d+)/) {
	($SeasonNumber,$EpisodeNumber) = split('E', $Season_Episode);
	$SeasonNumber =~ s/S//g;
} elsif ($Season_Episode =~ m/(\d+)x(\d+)/) {
	($SeasonNumber,$EpisodeNumber) = split('x', $Season_Episode);
}
$EpisodeNumber =~ s/^0+//g;
$SeasonNumber =~ s/^0+//g;

my $kind = "TV Show";
my $genre;
my $Actors;
my $EpisodeName;
my $AirDate;
my $Description;
my $ProductionCode;
my $Director;
my $Writer;
my @command;
my $artwork;
my @banners;
my $image;
my $link;
my $imageurl;

my $tvdb = WebService::TVDB->new(api_key => "$api_key", language => 'English', max_retries => 10);
my $series_list = $tvdb->search("$show");
my $series = @{$series_list}[0];
$series->fetch();

my $SeriesID = $series->seriesid;
my $IMDB_ID = $series->IMDB_ID;
my $Rating = $series->ContentRating;
my $TVNetwork = $series->Network;
my $SeriesName = $series->SeriesName;
for my $genres (@{ $series->Genre }) {
	$genre .= $genres . ",";
}
$genre =~ s/,$//g;
for my $people (@{ $series->Actors}) {
	$Actors .= $people . ",";
}

#print Dumper($series->episodes);

$Actors =~ s/,$//g;
for my $episode (@{ $series->episodes }) {
	if ($episode->SeasonNumber eq $SeasonNumber && $episode->EpisodeNumber eq $EpisodeNumber) {
		$EpisodeName = $episode->EpisodeName;
		$AirDate = $episode->FirstAired;
		$Description = $episode->Overview;
		$ProductionCode = $episode->ProductionCode;
		$Director = $episode->Director;
		$Director =~ s/^\||\|$//g;
		$Director =~ s/\|/,/g;
		$Writer = $episode->Writer;
		$Writer =~ s/^\||\|$//g;
		$Writer =~ s/\|/,/g;
	}
}

for my $banner (@{ $series->banners }){
	if ($banner->BannerType eq "season" && $banner->Season eq $SeasonNumber) {
		push @banners, {banner => $banner->BannerPath, id => $banner->id, ratingcount => $banner->RatingCount, rating=> $banner->Rating}
	}
}
my $url = 'http://www.thetvdb.com/banners';
my $highestRating = 0;
my $index = 0;
foreach my $art (@banners) {
	if ($art->{rating} && $art->{rating} ge $highestRating) {
		$highestRating = $art->{rating};
		$artwork = $url . "/" . $art->{banner};
	}
}

if (!$artwork) {
	print "Please select the image(s) you would like to preview. (Comma separated list ex. 1,2,3)\n\n";
	foreach my $art (@banners) {
		print "$index) " . $url . "/" . $art->{banner} . "\n";
		$index++;
	}
	print "\nSelection: ";
	my $input = <STDIN>;
	chomp($input);
	my @inputArray;
	if ($input =~ ",") {
		@inputArray = split(',', $input);
	} else {
		push(@inputArray, $input);
	}
	if ($input) {
		foreach my $x (@inputArray) {
			$imageurl = "$url/$banners[$x]->{banner}";
			RunAppleScript(qq(tell application "Safari"\nactivate\nopen location "$imageurl"\nend tell))
				or die "Didn't open Safari.\n";
		}	
	}
	print "Which image would you like to use? ";
	$input = <STDIN>;
	$artwork = $url . "/" . $banners[$input]->{banner};
}

my $ff = File::Fetch->new(uri => "$artwork");
my $where = $ff->fetch() or die $ff->error;
$image = $ff->output_file;

if ($verbose) {
	print "\n************************************\n";
	print "\n";
	print "FILENAME:\t$filename\n";
	print "DIRECTORY:\t$directories\n";
	print "SERIES ID:\t$SeriesID\n";
	print "TYPE:\t\t$kind\n";
	print "HD:\t\t$HD\n";
	print "IMAGE:\t\t$artwork\n";
	print "SERIES NAME:\t$SeriesName\n";
	print "EPISODE NAME:\t$EpisodeName\n";
	print "AIR DATE:\t$AirDate\n";
	print "RATING:\t\t$Rating\n";
	print "GENRE:\t\t$genre\n";
	print "DESC:\t\t$Description\n";
	print "TV NETWORK:\t$TVNetwork\n";
	print "SEASON:\t\t$SeasonNumber\n";
	print "EPISODE NUMBER:\t$EpisodeNumber\n";
	if ($ProductionCode) {
		print "EPISODE ID:\t$ProductionCode\n";
	}
	print "ACTORS:\t\t$Actors\n";
	#print "GUEST ACTORS:\t$GuestStars\n";
	print "DIRECTOR:\t$Director\n";
	print "SCREENWRITER:\t$Writer\n";
	print "\n";
	print "************************************\n";
}

push(@command, "$mp4tagger");
push(@command, "-i \'$file\'");
push(@command, "--media_kind \"$kind\"");
if ($artwork) {
	push(@command, "--artwork \"$image\"");
} else {
	print "\n\n\tWARNING: THIS FILE WILL NOT CONTAIN ANY COVER ART, NO IMAGE FILE WAS FOUND!\n\n";
}
push(@command, "--is_hd_video $HD");
if ($ProductionCode) {
	push(@command, "--tv_episode_id \"$ProductionCode\"");
}
push(@command, "--tv_episode_n \"$EpisodeNumber\"");
push(@command, "--tv_show \'$SeriesName\'");
push(@command, "--tv_season \"$SeasonNumber\"");
push(@command, "--tv_network \"$TVNetwork\"");
push(@command, "--name \'$SeriesName\'");
push(@command, "--genre \"$genre\"");
push(@command, "--release_date \"$AirDate\"");
if ($Rating) {
	push(@command, "--rating \"$Rating\"");
}
push(@command, "--content_rating \"Clean\"");
push(@command, "--cast \"$Actors\"");
push(@command, "--director \"$Director\"");
push(@command, "--screenwriters \"$Writer\"");
push(@command, "--description \"$Description\"");
push(@command, "--long_description \"$Description\"");

system("@command") == 0
	or die "system @command failed: $?";

# Cleanup after ourselves, removing downloaded artwork.	
system("rm -f $image") == 0
	or die "system rm failed: $?";