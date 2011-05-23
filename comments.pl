#!/usr/bin/perl
use Data::Dumper;
   $Data::Dumper::Indent = 1;
   $Data::Dumper::Terse = 1;
   $Data::Dumper::Quotekeys = 0;
use Authen::Captcha;

sub servecomments;
sub getcomments;
sub loadcomments;
sub savecomments;
sub sortcomments;
sub printcomments;
sub postcomment;
sub votecomment;
sub findcomment;

sub servecomments
{
  #TODO
}

sub getcomments
{
  my $filename = shift;
  open my $file, $filename or return "[ ]";
  local $/; # enable localized slurp mode
  return <$file>;
}

sub loadcomments
# returns a hash with _all_ the comments
{
  opendir SITE, $DOCUMENT_ROOT or die;
  my %comments;
  for my $page(readdir SITE)
  {
    next if $page =~ /\.\.?/;
    if (-d "$DOCUMENT_ROOT/$page")
    {
      opendir PAGE, "$DOCUMENT_ROOT/$page" or die;
      for my $item (readdir PAGE)
      {
        next if $page =~ /\.\.?/;
        if (-d "$DOCUMENT_ROOT/$page/$item")
        {
          if (-e "$DOCUMENT_ROOT/$page/$item/comments")
          {
            $comments{$item} = eval &getcomments("$DOCUMENT_ROOT/$page/$item/comments");
            if ($@)
            {
              die "Comment file /$page/$item/comments is corrupted!\n";
            }
            &sortcomments($comments{$item});
          }
        }
      }
    }
  }
  return %comments;
}

sub savecomments
{
  my $ref = shift;
  my $filename = shift;
  open my $file, ">", $filename or die "Can't write to $filename\n";
  print $file Dumper($ref) and return 1;
}

sub sortcomments
# sort comments recursively
{
  my $ref = shift;
  @{$ref} = sort {$b->{points} <=> $a->{points}} @{$ref};
  for (@{$ref})
  {
    if (@{$_->{replies}})
    {
      &sortcomments($_->{replies});
    }
  }
}


sub printcomments
# print comments recursively
{
  my $ref = shift;
  my $level = shift || 0;
  my $indent = "  " x $level;
  
  # if this is the first invocation
  if (not $level)
  {
    if (not defined $ref)
    {
      print "<div class=between>There are no comments.</div>";
      $ref = [ ];
    }
    else
    {
      print "<div class=between>Comments:</div>";
    }
  }
    
  
  # for every invocation:
  for (@{$ref})
  {
    my $id = $_->{'id'};
    print "$indent <div class=" . ($level ? "reply" : "content") . ">\n";
    print "$indent <div class=from>from <b>$_->{from}</b> on $_->{date} ";
    print "$indent (<span id=\"$id-points\">$_->{points}&nbsp;" . (abs($_->{points}) == 1 ? "point" : "points" ) . "</span>):";
    print<<HTML;
$indent </div>
$indent <div class=message>
$indent $_->{body}
$indent </div>
$indent <div class=actions>
$indent <a href="upvote-comment/?$id" onClick="vote('up',$id,this); return false;">&#8593;Upvote</a>
$indent <a href="downvote-comment/?$id" onClick="vote('down',$id,this); return false;">&#8595;Downvote</a>
$indent <a href="#" onClick="toggle('form$id'); return false;">&#8635;Reply</a>
$indent </div>
$indent <div class=commentform id="form$id" style="display: none;">
$indent <form action="post-a-comment/" method=POST>
$indent <input type=text name=name onFocus="clearname(this)" value="Your name" /><br />
$indent <textarea name=message onFocus="clearcomment(this)">Your comment</textarea><br />
$indent <input type=hidden name=parent value="$id" />
$indent <input type=submit value=Submit />
$indent </form>
$indent </div>
HTML
    
    # print any replies recursively
    if (@{$_->{replies}})
    {
      &printcomments( $_->{replies}, $level + 1 );
    }
    print "$indent </div>\n";
  }

  if (not $level)
  {
    print<<HTML;
<div class=item>
<div class=commentform>
Leave a comment!<br />
<form action="post-a-comment/" method=POST>
<input type=text name=name onFocus="clearname(this)" value="Your name" /><br />
<textarea name=message onFocus="clearcomment(this)">Your comment</textarea><br />
<input type=hidden name=parent value=0 />
<input type=submit value=Submit />
</form>
</div>
</div>
HTML
  }
}


sub postcomment {
  
  return if not $ENV{'REQUEST_METHOD'} eq "POST";
  
  my ($page, $item) = @_;
  my %post = &getpost or return;
  
  # change <'s, >'s, and &'s to html-code
  $post{'name'} =~ s/&/&amp;/g;
  $post{'name'} =~ s/</&lt;/g;
  $post{'name'} =~ s/>/&gt;/g;
  $post{'message'} =~ s/&/&amp;/g;
  $post{'message'} =~ s/</&lt;/g;
  $post{'message'} =~ s/>/&gt;/g;
  $post{"message"} =~ s/\r//g; # and remove \r's

  if (not defined $post{answer}) { # if the captcha has not yet been solved
    my $captcha = Authen::Captcha->new(
       data_folder => "$CAPTCHA_HIDDEN_DIR",
       output_folder => "$CAPTCHA_DIR",
       width => 46,
       height => 50);
       
    # the following function also returns an md5sum of the image,
    # which is totally useless and insecure in almost any implementation
    my ($md5sum, $answer) = $captcha->generate_code(6);
    # (however, we do need it to address the image this generates)
   
    # a better and more secure solution:
    # store the answer in plain text, along with a unique user-id,
    # in a non-accessible directory (even better would be a hash of the answer)
    my $id; $id .= int(rand(10)) for 0..16;
    open ANS, ">", "$CAPTCHA_HIDDEN_DIR/$id" or die $!;
    print ANS $answer;
    close ANS;

    rename "$CAPTCHA_DIR/$md5sum.png", "$CAPTCHA_DIR/$id.png" or die $!;

    &printheader;
    &printhtml("Post a comment");
    print<<HTML;
<div class=item>
<div class=commentform>
You are about to post the following comment.
After you've made sure there are no spelling blunders,
please answer the <a href=\"http://en.wikipedia.org/wiki/Captcha\">captcha</a>
below to prove that you are human.
<form action="/$page/$item/post-a-comment/" method=POST>
<input type="hidden" name="user-id" value="$id" />
<div style="font-size: smaller; padding-top: 1em;">Your name:</div>
<input type="text" name="name" value="$post{name}"/><br />
<div style="font-size: smaller; padding-top: 0.5em;">Your comment:</div>
<textarea name="message" rows="8">$post{message}</textarea><br />
<div style="padding-top: 1em;">Type the characters you see in this picture into the green box:</div>
<img src="/captcha/$id.png" align="top" style="margin-bottom:2px;" alt="If you cannot see this picture, you cannot post this form. Please email us your comment and we will place it manually!" />
<input type="text" name="answer" style="background: #66cc66; width: 4.5em; font-size: 1.5em; font-family: sans-serif;" />
<input type="submit" value="Submit" style="font-size: 1.25em; float: right;" />
</p>   
</form></div></div>
HTML
  }
  else {
    # check if the answer is empty:
    $post{'answer'} or &error("You didn't fill in the captcha. Go back and give it a try!");
    $post{'user-id'} or return;
    
    # check if it's correct
    open ANS, "$CAPTCHA_HIDDEN_DIR/$post{'user-id'}" or return;
    if ( <ANS> eq $post{'answer'} ) {
      &printheader;
      &printhtml("Post successful");
      print<<HTML;
<div class=item>
You answered the captcha correctly!<br>
However, we could not place your comment because this function
hasn't been implemented yet...
</div>
HTML
    }
    else {
      &printheader;
      &printhtml("Failed");
      print<<HTML;
<div class=item>
Your gave a wrong answer to the captcha.<br>
Go back, refresh to obtain a new captcha, and try again!
</div>
HTML
    }
      
    # delete state whether correct or not
    unlink "$CAPTCHA_HIDDEN_DIR/$post{'user-id'}";
    unlink "$CAPTCHA_DIR/$post{'user-id'}.png";
  }
}

sub votecomment
{
  my $direction = shift;
  my $page = shift;
  my $item = shift;
  my $id = shift;
  my $comment = &findcomment($comments{$item}, $id);
  
  if ($comment)
  {
    ++$comment->{points} if $direction eq "up";
    --$comment->{points} if $direction eq "down";

    my $string = "Content-type: text/plain; charset=ISO-8859-1\n\n" .
              $comment->{points} .
              (abs($comment->{points}) == 1 ? "&nbsp;point" : "&nbsp;points");
    # what happens if you sort first and dereference later?
    &sortcomments($comments{$item});
    &savecomments($comments{$item}, "$DOCUMENT_ROOT/$page/$item/comments");
    return $string;
  }
}

sub findcomment
# search comments recursively
{
  my $ref = shift;
  my $id = shift;
  my $result;
  return 0 unless @{$ref};
  
  for (@{$ref})
  {
    if ($id eq $_->{'id'})
    {
      return $_;
    }
    elsif (@{$_->{replies}})
    {
      $result = &findcomment( $_->{replies}, $id );
    }
  }
  return $result;
}

1;
