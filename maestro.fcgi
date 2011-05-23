#!/usr/bin/perl -w
# Maestro - a simple content management system for handheld-friendly websites.
# Copyright by J.J.Vens, 2010. Distribution, modification, and use allowed
# under the terms of the latest version of the GNU General Public License.

# Version 0.01

use strict;
use FCGI;
use POSIX 'setsid'; # for daemonizing
use Time::HiRes 'time';
use FindBin '$Bin';

# global variables:
our $DOMAIN_NAME;
our $DOCUMENT_ROOT;
our $MAESTRO_DIR;
our $FCGI_PORT;
our $REQUEST_QUEUE;
our $MAX_POST_LENGTH;
our $CAPTCHA_DIR;
our $CAPTCHA_HIDDEN_DIR;

# include config variables
do "$Bin/maestro.conf" or die;

# and various functions
do "$Bin/comments.pl" or die;
do "$Bin/control.pl" or die;
do "$Bin/misc.pl" or die;

# create socket and request handle
my $socket = FCGI::OpenSocket( $FCGI_PORT, $REQUEST_QUEUE );
my $request = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%ENV, $socket );

# load entire site into memory (that will serve faster!)
our $site = &loadpages($DOCUMENT_ROOT);

# hack some stats
our $counter = 1; # prevents div by 0
our $sumtime = 0;

my $exit_requested = 0;
my $handling_request = 0;

# handler to ignore suddenly closed file descriptors
$SIG{PIPE} = 'IGNORE';

# handler to postpone termination until finishing a request
$SIG{TERM} = sub {
  $exit_requested = 1;
  exit(0) unless $handling_request };
        
print "Maestro is up and running!";

&daemonize;

my $client;
# main request loop:
client: while( $handling_request = $request->Accept() >= 0 )
{  
  my $start = time();

  # first check if a webmaster has logged in
  # (the web server should handle authorization!)
  if ($ENV{REQUEST} =~ m:/maestro/?(.*):) {
    &servemaestro($1);
  }
  
  elsif ($ENV{REQUEST} =~ m:/poll/:) {
    print "Content-type: text/plain\n\n";
    print $counter - 1 . "\n";
    for (keys %ENV) { print "$_ = $ENV{$_}\n" }
    # $counter = 1;
  }

  elsif ( &serve($ENV{REQUEST}) ) {
    ++$counter;
    $sumtime += (time() - $start);
  }

  else {
    print STDERR "Invalid request: $ENV{REQUEST}\n";
  }
  
  $request->Finish();
  $handling_request = 0;
  last if $exit_requested;
}

FCGI::CloseSocket( $socket );


###########################################################################################


sub daemonize
{
  chdir '/' or die "Can't chdir to /: $!";
  defined(my $pid = fork) or die "Can't fork: $!";
  exit if $pid; # parent process exits
  setsid() or die "Can't start a new session: $!";
  umask 0;
}


###########################################################################################


sub loadpages
# given a site content directory, generates and returns
# the underlying directory structure as a recursive hash
{
  my ($dir, $parent) = @_;
  my $ref = { parent => $parent };

  { local $/; # localized slurp mode
    
    # add references to the contents of the following files
    for ('header', 'head', 'footer') {
      if (open my $fh, "$dir/$_") {
        $ref->{$_} = \<$fh>; # assigns a reference to a scalar
      }
      # or copy the parent's reference if it doesn't exist
      else {
        $ref->{$_} = $parent->{$_};
      }
    }
    
    # simply include the contents of the following files
    for ('title', 'summary', 'body') {
      if (open my $fh, "$dir/$_") {
        $ref->{$_} = <$fh>;
      }
    }
    
    # and eval the contents of the comments file
    if (open my $comments, "$dir/comments") {
      $ref->{comments} = eval <$comments>;
    }
  }

  # do the same for each subdirectory
  for my $page (`/bin/ls -t1 $dir`) {
    chomp $page;
    next if $page =~/^\.\.?$/;
    
    if (-d "$dir/$page") {
      push @{$ref->{items}}, &loadpages("$dir/$page",$ref);
      $ref->{items}[-1]{name} = $page;
    }
  }
  
  # return the generated structure
  return $ref;
}


###########################################################################################


sub find
# returns a reference to a given node in the site tree
{
  my ($req, $ref) = @_;
  if ($req eq "/") {
    return $ref;
  }
  elsif ($req =~ m:/([^/]+)(.*):) {
    for (@{$ref->{items}}) {
      if ($_->{name} eq $1) {
        return find($2, $_);
      }
    }
  }
  # else
  return 0;
}  
  

###########################################################################################


sub serve
# generates and prints the requested page
{
  my $req = shift;
  my $ref = &find($req, $site) or return 0;

  print "Content-type: text/html\n\n";
  print "<!doctype html>\n";
  print "<html><head><title>$ref->{title}</title>\n";
  print ${$ref->{head}};
  print "</head><body>\n";
  print ${$ref->{header}};
  print "<div class=content>\n";
  print $ref->{body};
  print "</div>\n";
  for (@{$ref->{items}}) {
    if ($_->{summary}) {
      print "<div class=item>\n";
      print $_->{summary};
      print "</div>\n";
    }
  }
  &printcomments($ref->{comments}) if defined $ref->{comments};
  print ${$ref->{footer}};
  print "</body></html>";
  return 1;
}
