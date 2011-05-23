#!/usr/bin/perl

sub getpost;
sub parse;
sub error;

sub getpost
# returns a hash with posted input
{
  my $input;
  my $supposed_length = $ENV{"CONTENT_LENGTH"};

  if (not $supposed_length)
  {
    print STDERR "No data was posted\n";
    return;
  }

  if ($supposed_length > $MAX_POST_LENGTH)
  {
    print STDERR "Refused a $supposed_length byte POST request\n";
    return;
  }

  my $actual_length = read(STDIN, $input, $supposed_length) or next client;
  if ($actual_length != $supposed_length)
  {
    print STDERR "Refused POST request with not enough data\n";
    return;
  }
  
  return &parse($input);
}


sub parse
# parses a URL-encoded string into a hash
{
  my $data = shift;
  my %hash;
  for ( split(/\&/,$data) )
  {
    (my $key, my $val) = split(/=/);
    $val =~ s/\+/ /g;
    # this magic restores char values (even utf8!)
    $val =~ s/%([0-9a-fA-F]{2})/chr(hex($1))/ge;
    chomp $val;
    $hash{$key} = $val;
  }
  return %hash;
}


sub error
{
  print "Content-type: text/plain\n\n";
  print @_;
}

sub sanitize
# sanitizes user input for display on html pages
{
  my $hashref = shift;
  
  for (values %{$hashref}) {
    $_ =~ s/&/&amp;/g;
    $_ =~ s/</&lt;/g;
    $_ =~ s/>/&gt;/g;
    $_ =~ s/\r//g; # and remove \r's
  }
}


1;
