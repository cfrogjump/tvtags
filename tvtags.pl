#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use WebService::TVDB;
use File::Basename;
use File::Path;
use File::Fetch;

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
my $verbose = "yes";
my $cleanup = "no"; # Define as yes to remove the cover artwork after each tag. 
######################################################################
# DO NOT EDIT ANYTHING BLEOW THIS LINE.
######################################################################

my $SeasonNumber;
my $EpisodeNumber;
my $file = $ARGV[0];
my ($filename, $directories) = fileparse("$file");
my ($show,$Season_Episode,$episode_name) = split('\ -\ ', $filename);
$episode_name =~ s/.m4v//g;
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
my @genre;
my @Actors;

my $tvdb = WebService::TVDB->new(api_key => "$api_key", language => 'English', max_retries => 10);
my $series_list = $tvdb->search("$show");
my $series = @{$series_list}[0];
$series->fetch();

#print Dumper($series);
# Populate the series information
my $SeriesID = $series->seriesid;
my $IMDB_ID = $series->IMDB_ID;
my $Rating = $series->ContentRating;
my $TVNetwork = $series->Network;
my $SeriesName = $series->SeriesName;
for my $genres (@{ $series->Genre }) {
	push(@genre, $genres);
}
$genre = join(',', @genre);

if (@{$series->Actors}) {
	for my $people (@{ $series->Actors}) {
		push (@Actors, $people);
	}
	$Actors = join(',', @Actors);
}

# Popluate the episode information
for my $episode (@{ $series->episodes }) {
	if ($episode->SeasonNumber eq $SeasonNumber && $episode->EpisodeNumber eq $EpisodeNumber) {
		$EpisodeName = $episode->EpisodeName;
		$AirDate = $episode->FirstAired;
		$Description = $episode->Overview;
		$Description =~ s/\"/\\\"/g;
		$ProductionCode = $episode->ProductionCode;
		$Director = $episode->Director;
		if ($Director) {
			$Director =~ s/^\||\|$//g;
			$Director =~ s/\|/,/g;
		}
		$Writer = $episode->Writer;
		if ($Writer) {
			$Writer =~ s/^\||\|$//g;
			$Writer =~ s/\|/,/g;
		}
	}
}

# Try and determine what episode it is if your season and episode number in the filename
# can't be found on TVDB (i.e. Fast N' Loud season 4)
if (!$EpisodeName) {
	foreach my $episode (@{ $series->episodes }) {
		my $EN = $episode->{EpisodeName};
		$EN =~ s/[#\-\%\$*+():].\'\"//g;
		if (lc($EN) eq lc($episode_name)) {
			$EpisodeName = $episode->EpisodeName;
			$AirDate = $episode->FirstAired;
			$Description = $episode->Overview;
			$ProductionCode = $episode->ProductionCode;
			if ($episode->Director) {
				$Director = $episode->Director;
				$Director =~ s/^\||\|$//g;
				$Director =~ s/\|/,/g;
			}
			if ($episode->Writer) {
				$Writer = $episode->Writer;
				$Writer =~ s/^\||\|$//g;
				$Writer =~ s/\|/,/g;
			}
			$SeasonNumber = $episode->SeasonNumber;
			$EpisodeNumber = $episode->EpisodeNumber;
		}
		
	}
	
}

# Determine which season artwork to use. 
for my $banner (@{ $series->banners }){
	if ($banner->BannerType eq "season" && $banner->Season eq $SeasonNumber) {
		push @banners, {banner => $banner->BannerPath, id => $banner->id, ratingcount => $banner->RatingCount, rating=> $banner->Rating}
	}
}
my $url = 'http://www.thetvdb.com/banners';
my $highestRating = 0;
my $index = 0;

foreach my $art (@banners) {
	my $localart = "$SeriesName.jpg";
	if (!-e $localart) {
		if ($art->{rating} && $art->{rating} ge $highestRating) {
			$highestRating = $art->{rating};
			$artwork = $url . "/" . $art->{banner};
		}
	} else {
		$image = $localart;
	}
	
}

# If artwork can't be automatically determined then prompt for input.
if (!$artwork && !$image && @banners) {
	if (scalar @banners eq "1") {
		$artwork = $url . "/" . $banners[0]->{banner};
	} else {
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
				`open $imageurl`;
			}	
		}
		print "Which image would you like to use? ";
		$input = <STDIN>;
		$artwork = $url . "/" . $banners[$input]->{banner};
	}
}

if ($artwork) {
	my $ff = File::Fetch->new(uri => "$artwork");
	my $where = $ff->fetch() or die $ff->error;
	my $tmpimage = $ff->output_file;
	rename $tmpimage,"$SeriesName.jpg";
	$image = "$SeriesName.jpg";
}

if ($verbose eq "yes") {
	print "\n************************************\n";
	print "\n";
	print "FILENAME:\t$filename\n";
	print "DIRECTORY:\t$directories\n";
	print "SERIES ID:\t$SeriesID\n";
	print "TYPE:\t\t$kind\n";
	print "HD:\t\t$HD\n";
	if ($artwork) {
		print "IMAGE URL:\t$artwork\n";
	} elsif	($image) {
		print "IMAGE URL:\t$image\n";
	}
	print "SERIES NAME:\t$SeriesName\n";
	print "EPISODE NAME:\t$EpisodeName\n";
	print "AIR DATE:\t$AirDate\n";
	if ($Rating) {
		print "RATING:\t\t$Rating\n";
	}
	print "GENRE:\t\t$genre\n";
	print "DESC:\t\t$Description\n";
	print "TV NETWORK:\t$TVNetwork\n";
	print "SEASON:\t\t$SeasonNumber\n";
	print "EPISODE NUMBER:\t$EpisodeNumber\n";
	if ($ProductionCode) {
		print "EPISODE ID:\t$ProductionCode\n";
	}
	if ($Actors) {
		print "ACTORS:\t\t$Actors\n";
	}
	#print "GUEST ACTORS:\t$GuestStars\n";
	if ($Director) {
		print "DIRECTOR:\t$Director\n";
	}
	if ($Writer) {
		print "SCREENWRITER:\t$Writer\n";
	}
	print "\n";
	print "************************************\n";
}

# Tag the file with the information.
$file =~ s/\ /\\\ /g;
$file =~ s/\'/\\\'/g;
$file =~ s/\(/\\\(/g;
$file =~ s/\)/\\\)/g;
$file =~ s/\,/\\\,/g;
$file =~ s/\:/\\\:/g;
$file =~ s/\;/\\\;/g;
$file =~ s/\&/\\\&/g;

push(@command, "$mp4tagger");
push(@command, "-i $file");
push(@command, "--media_kind \"$kind\"");
if ($image) {
	push(@command, "--artwork \"$image\"");
} else {
	print "\n\n\tWARNING: THIS FILE WILL NOT CONTAIN ANY COVER ART, NO IMAGE FILE WAS FOUND!\n\n";
}
push(@command, "--is_hd_video $HD");
if ($ProductionCode) {
	push(@command, "--tv_episode_id \"$ProductionCode\"");
}
push(@command, "--tv_episode_n \"$EpisodeNumber\"");
push(@command, "--tv_show \"$SeriesName\"");
push(@command, "--tv_season \"$SeasonNumber\"");
push(@command, "--tv_network \"$TVNetwork\"");
push(@command, "--name \"$EpisodeName\"");
push(@command, "--genre \"$genre\"");
push(@command, "--release_date \"$AirDate\"");
if ($Rating) {
	push(@command, "--rating \"$Rating\"");
}
push(@command, "--content_rating \"Clean\"");
if ($Actors) {
	push(@command, "--cast \"$Actors\"");
}
if ($Director) {
	push(@command, "--director \"$Director\"");
}
if ($Writer) {
	push(@command, "--screenwriters \"$Writer\"");
}
push(@command, "--description \"$Description\"");
push(@command, "--long_description \"$Description\"");

system("@command") == 0
	or die "system @command failed: $?";

# Cleanup after ourselves, removing downloaded artwork.	
if ($image && $cleanup eq "yes") {
	system("rm -f $image") == 0
		or die "system rm failed: $?";
}

# Set the files modification date to match the release date for sorting purposes. 
$AirDate =~ s/-//g;
$AirDate = $AirDate . "1200";
system ("touch -t $AirDate $file") == 0
	or die "touch failed: $?";
