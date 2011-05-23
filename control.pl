#!/usr/bin/perl
use Date::Format;

sub servemaestro;
sub servepanel;
sub changepass;
sub edit;
sub add;
sub delete;
sub touch;

sub servemaestro
# dispatches the request to the proper function
{
  my $action = shift;

  if (not $action) {
    &servepanel;
  }
  elsif ($action eq "usermanagement/") {
    &changepass;
  }
  elsif ($action =~ m:^edit(.*):) {
    &edit($1);
  }
  elsif ($action =~ m:^add(.*):) {
    &add($1);
  }
  elsif ($action =~ m:^upload(.*):) {
    &upload($1);
  }
  elsif ($action =~ m:^delete(.*):) {
    &delete($1)
  }
  elsif ($action =~ m:^touch(.*):) {
    &touch($1);
  }
  else {
    return 0;
  }
  return 1;
}

sub servepanel
# big ugly mess of code that generates the control panel
{
  my $restart = sprintf "%.2f days ago", ( (int(time()) - $^T)/86_400 ); # seconds per day
  my $avtime = sprintf "%.5f", ($sumtime / $counter);
  # my $capacity = $avtime > 0 ? (int(60 / $avtime) . " requests per minute") : "unknown";

  print "Content-type: text/html\n\n";
  print "<!doctype html>\n";
  print "<html><head><title>Maestro Control Panel</title>\n";
  print ${$site->{head}};
  print "<link rel='stylesheet' href='/controlpanel.css' type='text/css' />\n";
  print "<script type='text/javascript' src='/toggle.js'></script>\n";
  print "</head><body>\n";
  print ${$site->{header}};
  print<<HTML;
<div class=controlpanel>


<h2>Maestro Control Panel</h2>
<h3>Content management</h3>
<p>
This site's content structure is recursive. The first part of
every page holds the main content. This is followed by a list of summaries
of all the subpages. Every subpage has its own URL where you can access
its main content as well a list of summaries of its sub(sub)pages. Etcera.
</p>
<p>
Comments are a special kind of summaries and can in the future be enabled for any page.
However, until it is fully implemented and tested, the comment functionality
is disabled.
</p>
<p>Please click on one of the following pages to edit it. Or use one of the buttons for
other actions.</p>
HTML
  
  print "<div class=sitetree><ul>";
  &printsite($site, "/");
  print "</ul></div>";

  print<<HTML;
<h3>User management</h3>
<ul style="padding: 0;"><ul style="padding: 0;">
<li><a href="#" onClick="toggle('userpass1'); return false">Change password</a>
<div id=userpass1 class=userpassform style="display: none">
<form action="/maestro/usermanagement/" method="POST">
<input type=hidden name=request value=changepass />
New password: <input type=password name=value2 /><br>
Verify password: <input type=password name=value3 /><br>
<input type=submit value="Change (will take effect immediately!)">
</form>
</div>
</li>

<li><a href="#" onClick="toggle('userpass2'); return false">Add user</a>
<div id=userpass2 class=userpassform style="display: none">
<form action="/maestro/usermanagement/" method="POST">
<input type=hidden name=request value=adduser />
New username: <input type=text name=value1 /><br>
New password: <input type=password name=value2 /><br>
Verify password: <input type=password name=value3 /><br>
<input type=submit value="Change (will take effect immediately!)">
</form>
</div>
</li>

<li><a href="#" onClick="toggle('userpass3'); return false">Delete user</a>
<div id=userpass3 class=userpassform style="display: none">
<form action="/maestro/usermanagement/" method="POST">
<input type=hidden name=request value=deleteuser />
Username: <input type=text name=value1 /><br>
Password: <input type=password name=value2 /><br>
<input type=submit value="Change (will take effect immediately!)">
</form>
</div>
</li>

</ul></ul>

<p>&nbsp;</p>

<h3>Statistics</h3>
<p>
Last restart: $restart<br>
Number of requests since last restart: $counter<br>
Average request time: $avtime seconds<br>
For more statistics please use <a href="http://www.nedstat.com/">Nedstat</a>
</p>
HTML


  print ${$site->{footer}};
  print "</body></html>";
}


###########################################################################################


sub printsite
# recursively prints a <ul> and <li> site listing
{
  my $ref = shift;
  my $url = shift;
  my $level = shift || 0;
  my $indent = "  " x $level;
  
  if ($ref->{title}) {
    print "$indent<li><a title='Edit this page' href='/maestro/edit$url'>$ref->{title}</a>\n";
  }
  else {
    print "$indent<li><a title='Edit this page' href='/maestro/edit$url'>No title</a>\n";
  }

  print "<div class=editbuttons>";
  print "<a href='/maestro/touch$url' title='Move page to top' class=editbutton  style='background-color: #373; border-color: #373;'>&#8593;</a>" if $level;
  print "<a href='/maestro/add$url' title='Add an item to this page' class=editbutton style='background-color: #339; border-color: #339;'>+</a>";
  print "<a href='/maestro/upload$url' title='Add external file to this page' class=editbutton style='background-color: #c90; border-color: #c90;'>/</a>";
  print "<a href='/maestro/delete$url' title='Delete this page (and everything under it)' class=editbutton style='background-color: #933; border-color: #933;' onClick=\"return confirm('Are you sure you want to delete \\'$ref->{title}\\' (at $DOMAIN_NAME$url) and every page beneath it?')\">&#215;</a>" if $level;
  print "</div>";
  
  if (defined @{$ref->{items}}) {
    print "$indent<ul>\n";
    for (@{$ref->{items}}) {
        &printsite($_, $url . $_->{name} . "/", $level+1);
    }
    print "$indent</ul>\n";
  }
  
  print "$indent</li>\n";
}


###########################################################################################


sub changepass {
  my %post = &getpost or return;
  
  if ($post{request} eq "changepass") {
    unless ($post{value2} and $post{value3}) {
      &error("You left one or more fields empty.");
      return;
    }
    if ($post{value2} eq $post{value3}) {
      if ($post{value2} =~ /[a-zA-Z0-9-_\.]/) {
        `/usr/bin/htpasswd -b $MAESTRO_DIR/password $ENV{USER} $post{value2} > /dev/null`;
        print "Location: /maestro/\n\n";
      }
      else {
        &error("Invalid character in password");
      }
    }
    else {
      &error("The two passwords you typed are not the same!");
    }
  }
  
  elsif ($post{request} eq "adduser") {
    unless ($post{value1} and $post{value2} and $post{value3}) {
      &error("You left one or more fields empty.");
      return;
    }
    if ($post{value1} =~ /[a-zA-Z0-9-_\.]/) {
      if ($post{value2} eq $post{value3}) {
        if ($post{value2} =~ /[a-zA-Z0-9-_\.]/) {
          `/usr/bin/htpasswd -b $MAESTRO_DIR/password $post{value1} $post{value2} > /dev/null`;
          print "Location: /maestro/\n\n";
        }
        else {
          &error("Invalid character in password");
        }
      }
      else {
        &error("The two passwords you typed are not the same!");
      }
    }
    else {
      &error("Invalid character in username.");
    }
  }
  
  elsif ($post{request} eq "deleteuser") {
    unless ($post{value1} and $post{value2}) {
      &error("You left one or more fields empty.");
      return;
    }
    if ($post{value1} =~ /[a-zA-Z0-9-_\.]/ and $post{value2} =~ /[a-zA-Z0-9-_\.]/) {
      open my $fh, "$MAESTRO_DIR/password";
      while (<$fh>) {
        if ($_ =~ /^$post{value1}:(.+)/) {
          if (crypt($post{value2}, $1) eq $1) {
            `htpasswd -D $MAESTRO_DIR/password $post{value1} > /dev/null`;
            print "Location: /maestro/\n\n";
            return;
          }
        }
      }
      # else
      &error("The user does not exist or the password is incorrect. User not deleted.");
    }
    else {
      &error("Invalid character in username or password.");
    }
  }
}
    

###########################################################################################

sub edit {
  my $req = shift;
  my $ref = &find($req, $site) or return;
  
  my $name = $ref->{name} || "";
  my $title = $ref->{title} || "";
  my $summary = $ref->{summary} || "";
  my $body = $ref->{body} || "";
  
  # print form if nothing is submitted
  if ($ENV{'REQUEST_METHOD'} eq "GET") {
    print "Content-type: text/html\n\n";
    print "<!doctype html>\n";
    print "<html><head><title>Edit \"$ref->{title}\"</title>\n";
    print ${$site->{head}};
    print "<link rel='stylesheet' href='/controlpanel.css' type='text/css' />\n";
    print "<script type='text/javascript' src='/toggle.js'></script>\n";
    print "</head><body>\n";
    print ${$site->{header}};

    print<<HTML;
<div class=controlpanel>
<form class=editform action="/maestro/edit$req" method=POST>
<p><b>Title:</b> <input type=text name=title value="$title" /></p>
<p><b>Summary:</b> (appears on <i>$ref->{parent}->{title}</i>)<br>
<textarea name=summary>$summary</textarea></p>
<p>
HTML

    if ($body) {
      print<<HTML;
<input type=checkbox onChange="toggle('hiddenbydefault')" checked />
make it a full-fledged page</p>
<div id=hiddenbydefault style="display: block; margin-top: 0.5em;">
HTML
    }
    else {
      print<<HTML;
<input type=checkbox onChange="toggle('hiddenbydefault')" />
make it a full-fledged page (that can contain items of its own)</p>
<div id=hiddenbydefault style="display: none; margin-top: 0.5em;">
HTML
    }
    
    print<<HTML;
<p><b>URL:</b>
<table id=urlcontainer width="100%" border=0 cellspacing=0 cellpadding=0
 style="margin-bottom: 0.5em">
<tr><td>$DOMAIN_NAME$req</td>
</tr></table>
</p>
<p><b>Content:</b><br>
<textarea name=body>$body</textarea></p>
</div>
<input type=submit value=Save />
</form>
</div>
HTML
    print ${$site->{footer}};
    print "</body></html>";
  }
  
  # if the form is posted
  elsif ($ENV{'REQUEST_METHOD'} eq "POST") {
    my %post = &getpost;
    
    if (not -d "$DOCUMENT_ROOT$req") {
      &error("Cannot edit $req: it doesn't exist.");
      return;
    }
    
    if (not $post{title}) {
      &error("Title not specified");
      return;
    }
    
    for ('title', 'summary', 'body') {
      if ($post{$_}) {
        if (open my $fh, ">", "$DOCUMENT_ROOT$req$_") {
          print $fh $post{$_};
        }
      }
    }
    
    # erase the entire site memory structure
    $site = { };
    # and reload it
    $site = &loadpages($DOCUMENT_ROOT);

    print "Location: $req\n\n";
  }
}


###########################################################################################


sub add {
  my $req = shift;
  my $ref = &find($req, $site) or return;

  # print form if nothing is submitted
  if ($ENV{'REQUEST_METHOD'} eq "GET") {
    print "Content-type: text/html\n\n";
    print "<!doctype html>\n";
    print "<html><head><title>Add new page to \"$ref->{title}\"</title>\n";
    print ${$site->{head}};
    print "<link rel='stylesheet' href='/controlpanel.css' type='text/css' />\n";
    print "<script type='text/javascript' src='/toggle.js'></script>\n";
    print "</head><body>\n";
    print ${$site->{header}};

    print<<HTML;
<div class=controlpanel>
<form class=editform action="/maestro/add$req" method=POST>
<p><b>Title:</b> <input type=text name=title /></p>
<p><b>Summary:</b> (appears on <i>$ref->{title}</i>)<br>
<textarea name=summary></textarea></p>
<p><input type=checkbox onChange="toggle('hiddenbydefault')">
make it a full-fledged page</p>
<div id=hiddenbydefault style="display: none; margin-top: 0.5em;">
<p><b>URL:</b>
<table id=urlcontainer width="100%" border=0 cellspacing=0 cellpadding=0
 style="margin-bottom: 0.5em">
<tr><td>$DOMAIN_NAME$req</td>
<td width="100%"><input id=url type=text name=name /></td>
</tr></table>
</p>
<p><b>Content:</b><br>
<textarea name=body></textarea></p>
</div>
<input type=submit value=Save />
</form>
</div>
HTML
    print ${$site->{footer}};
    print "</body></html>";
  }
  
  # if the form is posted
  elsif ($ENV{'REQUEST_METHOD'} eq "POST") {
    my %post = &getpost;
    my $dir;
    my $name;
    
    if (not $post{title}) {
      &error("Title not specified");
      return 1;
    }
    
    $post{name} ? ($name = "\L$post{name}") : ($name = "\L$post{title}");
    $name =~ s/ /-/g;
    $name =~ s/[^a-z-0-9]//g;
    $dir = "$DOCUMENT_ROOT$req$name";
    
    if (-e $dir) {
      &error("That URL already exists!");
      return 1;
    }

    mkdir $dir;

    for ('title', 'summary', 'body') {
      if ($post{$_}) {
        if (open my $fh, ">", "$dir/$_") {
          print $fh $post{$_};
        }
      }
    }

    # erase the entire site memory structure
    $site = { };
    # and reload it
    $site = &loadpages($DOCUMENT_ROOT);

    print "Location: $req\n\n";
  }
}


sub upload {
  my $req = shift;
  my $ref = &find($req, $site) or return;

  # print form if nothing is submitted
  if ($ENV{'REQUEST_METHOD'} eq "GET") {
    print "Content-type: text/html\n\n";
    print "<!doctype html>\n";
    print "<html><head><title>Add a file to \"$ref->{title}\"</title>\n";
    print ${$site->{head}};
    print "<link rel='stylesheet' href='/controlpanel.css' type='text/css' />\n";
    print "<script type='text/javascript' src='/toggle.js'></script>\n";
    print "</head><body>\n";
    print ${$site->{header}};

    print<<HTML;
<div class=controlpanel>
<form class=editform action="/cgi-bin/upload.cgi" method=POST enctype="multipart/form-data">
<input type="hidden" name="dir" value="$req" />
<p>
<input type="file" name="filename" />
</p>
<p>
<input type="submit" value="Upload" /></form>
</div>
HTML
    print ${$site->{footer}};
    print "</body></html>";
  }
}



sub delete
# deletes the requested directory
{
  my $dir = shift;
  # the dir should exist, not be an empty string and should not contain dots!
  if (-d "$DOCUMENT_ROOT$dir" and $dir =~ /^[^\.]+$/) {
    `/bin/rm -rf $DOCUMENT_ROOT$dir`;
    $site = { };
    $site = &loadpages($DOCUMENT_ROOT);
    print "Location: /maestro/\n\n";
  }
  else {
    &error("Cannot delete $DOMAIN_NAME$dir");
  }
}


sub touch
# touches the requested directory
{
  `/usr/bin/touch $DOCUMENT_ROOT$_[0]`;
  $site = { };
  $site = &loadpages($DOCUMENT_ROOT);
  print "Location: /maestro/\n\n";
}

1;
