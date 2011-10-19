#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::ByteStream;
use Mojo::Util;
use Data::Dumper;
use DBI;

#conf
my $limit_page = 5;
my $site_title = "Matthew Sporleder's blog";
my $site_description = "blog about NetBSD, programming, and the web";
my $site_author = "Matthew Sporleder";

app->secret('mojosmallblog');

my $entry_db = app->home;
$entry_db = $entry_db . "/entry.db";

get '/admin' => sub {
  my $self = shift;

  if ($self->req->param("create_db") eq 1)
  {
    #need init?
    if (! -f $entry_db)
    {
      init_entry_db($entry_db);
      $self->render(text => "creating db");
    }
  }
    
  $self->render('admin');
};

any '/newpost' => sub
{
  my $self = shift;
  if ($self->req->method =~ /(?i:get)/)
  {
    $self->render('newpost');
  }
  if ($self->req->method =~ /(?i:post)/)
  {
    my $title = $self->param('title');
    my $entry = $self->param('entry');
    my $tags = $self->param('tags');
    my $date = $self->param('date') || 'now';
    if ($title and $entry)
    {
      insert_entry($entry_db, $title, $entry, $tags, $date);
      $self->render(text => "$title, $entry <br />$tags");
    }
  }
};

any '/editpost' => sub
{
  my $self = shift;
  $self->render('editpost');
};

get '/rss.xml' => sub
{
  my $self = shift;
  my $latest = get_entry($entry_db, 0, 0);
  $self->stash(content => $latest);
  $self->stash(site_title => $site_title);
  $self->stash(site_description => $site_description);
  $self->stash(site_author => $site_author);
  $self->render;
};

get '/atom.xml' => sub
{
  my $self = shift;
  my $latest = get_entry($entry_db, 0, 0);
  $self->stash(content => $latest);
  $self->stash(site_title => $site_title);
  $self->stash(site_description => $site_description);
  $self->stash(site_author => $site_author);
  $self->render;
};

#last because it catches everything else
get '/(:entry)' => {entry => 'latest'} => sub
{
  my $self = shift;
  if ($self->param('entry') eq 'latest')
  {
  #get the latest entries
    my $cur_page = $self->param('page') || 0;
    my $latest = get_entry($entry_db, 0, $cur_page);
    my $total_page = get_total_pages($entry_db);
    $self->stash(content => $latest);
    $self->stash(cur_page => $cur_page);
    $self->stash(total_page => $total_page->[0]->{tot});
    $self->render;
  }
  else
  {
  #display a specific page
    my $entry = $self->param('entry');
    my $slug = Mojo::ByteStream->new($entry);
    $slug = $slug->url_escape;
    $slug = Mojo::Util::b64_encode $slug;
    chomp $slug;
    my $latest = get_entry($entry_db, $slug, 0); 
    $self->stash(content => $latest);
    $self->render;
  }
  
};

sub init_entry_db
{
  my $dbfile = shift;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
  $dbh->do("PRAGMA foreign_keys = ON");
  #my $dbh = DBI->connect("dbi:SQLite:dbname=:memory","","");
  my @schema;
  push @schema, q#CREATE TABLE 'blog' ( 'id' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 'title' TEXT, 'text' TEXT, 'sb_date' TEXT, 'slug' TEXT )#;
  push @schema, q#CREATE TABLE 'tags' ( 'text' TEXT, ref REFERENCES blog( 'id' ))#;
  push @schema, q#CREATE TABLE 'comments' ( 'text' TEXT, ref REFERENCES blog( 'id' ))#;
  foreach my $sql (@schema)
  {
    print "$sql\n";
#TODO add better error handling
    my $sth = $dbh->prepare("$sql");
    $sth->execute;
  }
}

sub insert_entry
{
  my $dbfile = shift;
  my $title = shift;
  my $text = shift;
  my $tag_str = shift;
  my $date = shift;
  my $slug = Mojo::ByteStream->new($title);
  $slug = $slug->url_escape;
  $slug = Mojo::Util::b64_encode $slug;
  chomp $slug;
  my @tags = split(/\s*\,\s*/, $tag_str);
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
  $dbh->do("PRAGMA foreign_keys = ON");
#TODO add better error handling
  my $sth = $dbh->prepare("INSERT INTO blog( title, text, slug, sb_date ) VALUES(?, ?, ?, datetime(?))");
  $sth->execute( "$title", "$text", "$slug", "$date" );
  my $lastid = $dbh->func('last_insert_rowid');
  
  for my $t (@tags)
  {
#TODO add better error handling
    $sth = $dbh->prepare("INSERT INTO tags( 'text', 'ref' ) VALUES(?, $lastid)");
    $sth->execute($t);
  }
}

sub get_entry
{
  my $dbfile = shift;
  my $entry = shift;
  my $cur_page = shift;
  $cur_page = $cur_page*$limit_page;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
#todo get the tags list
  $dbh->do("PRAGMA foreign_keys = ON");
  my $sql;
  my $res;
  my @keys = ("id", "sb_date", "slug", "title", "text");
  my $keys_txt = join(",", @keys);
  if ($entry eq "0")
  {
    $sql = "SELECT $keys_txt from blog ORDER BY strftime('%s',sb_date) DESC LIMIT $limit_page OFFSET $cur_page";
  }
  else
  {
    $sql = "SELECT $keys_txt from blog WHERE slug = \"$entry\"";
  }
#TODO add better error handling
  $res = $dbh->selectall_arrayref($sql, { Slice => {} });
  return $res;
}

sub get_total_pages
{
  my $dbfile = shift;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
  $dbh->do("PRAGMA foreign_keys = ON");
  my $sql = "SELECT count(*)/$limit_page as tot from blog";
  my $res = $dbh->selectall_arrayref($sql, { Slice => {} });
  return $res;
}

app->start;
__DATA__

@@ entry.html.ep
% foreach my $art (@$content)
% {
% my $slug = Mojo::Util::b64_decode $art->{slug};
<div id=<%== "$art->{id}" %> class="entry">
<h5><span class="title"><%== $art->{title} %>, </span> <span class="sb_date"><%== $art->{sb_date} %></span> <span class="slug"><%= link_to "#" => "$slug" %></span></h5>
<div class="text"><%== $art->{text} %></div>
</div>
<div class="between"><hr /><br /></div>
% }
% for (my $i = 0; $i <= $total_page; $i++)
% {
<%== "<a href=\"?page=$i\">$i</a> " %>
% }

@@ rss.xml.ep
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
<title><%= $site_title %></title>
<description><%= $site_description %></description>
<link><%= url_for "/" %></link>
<ttl>1440</ttl>
% foreach my $art (@$content)
% {
% my $slug = Mojo::Util::b64_decode $art->{slug};
<item>
 <title><%= $art->{title} %></title>
 <link><%= url_for $slug %></link>
 <author><%= $site_author %></author>
 <pubDate><%= $art->{sb_date} %></pubDate>
 <description><%= $art->{text} %></description>
</item>
% }
</channel>
</rss>

@@ atom.xml.ep
<?xml version="1.0" encoding="UTF-8" ?>
<feed xmlns="http://www.w3.org/2005/Atom">
<title><%= $site_title %></title>
<subtitle><%= $site_description %></subtitle>
<link href="<%= url_for "/" %>" />
<updated><%= $content->[0]->{sb_date} %></updated>
<id><%= Mojo::Util::b64_encode $site_title %></id>
% foreach my $art (@$content)
% {
% my $slug = Mojo::Util::b64_decode $art->{slug};
<entry>
 <title><%= $art->{title} %></title>
 <link><%= url_for $slug %></link>
 <id><%= url_for $slug %></id>
 <author><name><%= $site_author %></name></author>
 <updated><%= $art->{sb_date} %></updated>
 <content><%= $art->{text} %></content>
</entry>
% }
</feed>

@@ admin.html.ep
<!doctype html>
<html>
<head><title>admin</title></head>
<body>
<p>
<%= link_to url_for->query(create_db => 1) => begin %>create db<% end %>
</p>
<p>
<%= link_to "new post" => 'newpost' %>
</p>
<p>
<%= link_to "edit posts" => 'editpost' %>
</p>
<p>
<%= link_to "upload media" => 'uploadmedia' %>
</p>
</body>
</html>

@@ newpost.html.ep
<html>
<head><title>new post</title></head>
<body>
<form method="post" action="<%= url_for('newpost') %>">
 <table class="new">
 <tr>
  <td>title</td>
  <td><input type="text" name="title" /></td>
 </tr>
 <tr>
  <td>entry</td>
  <td><textarea name="entry" cols="50" rows="10" ></textarea></td>
 </tr>
 <tr>
  <td>tags</td>
  <td><input type="text" name="tags" /></td>
 </tr>
 </table>
 <br />
 <input type="submit" value="POST" >
</form>
</body>
</html>

@@ editpost.html.ep
<html>
<head><title>edit post</title></head>
<body>
list posts<br />
add tags<br />
edit post<br />
</body>
</html>
