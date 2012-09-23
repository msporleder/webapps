#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::ByteStream;
use Mojo::Util;
use Data::Dumper;
use DBI;
use Mojo::Headers;
use Time::Piece;

#conf
my $config = plugin 'Config' => default =>
{
page_ttl => 2880,
limit_page => 5,
site_title => "smallblog blog",
site_description => "blog about stuff",
site_author => "me",
username => "admin",
password => "smallblog",
entry_db_base => app->home . "/db"
};

my $page_ttl = $config->{page_ttl};
my $limit_page = $config->{limit_page};
my $site_title = $config->{site_title};
my $site_description = $config->{site_description};
my $site_author = $config->{site_author};
my $entry_db = $config->{entry_db_base} . "/entry.db";

app->secret('mojosmallblog');


any '/admin' => sub {
  my $self = shift;
  $self->res->headers->cache_control("no-cache");
#get auth
  if (! $self->req->headers->authorization || ! check_auth($self->req->headers->authorization) )
  {
    $self->res->headers->www_authenticate("Basic realm=\"$site_title\"");
    $self->res->code("401");
    $self->stash(auth => $self->req->headers->authorization);
    $self->render('401');
  }

  if ($self->req->param("create_db") eq 1)
  {
    #need init?
    if (! -f $entry_db)
    {
      init_entry_db($entry_db);
      $self->render(text => "creating db");
    }
  }

  if ($self->req->param("newpost") eq 1)
  {
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
  }
#/newpost
  if ($self->req->param("editpost") eq 1)
  {
    if ($self->req->param("delete"))
    {
      del_entry($entry_db, $self->req->param("delete"));
      $self->render(text => "deleting " . $self->req->param("delete"));
    }
    if ($self->req->method =~ /(?i:get)/)
    {
      my $cur_page = $self->param('page') || 0;
      my $latest = get_entry($entry_db, 0, $cur_page);
      my $total_page = get_total_pages($entry_db);
      $self->stash(total_page => $total_page->[0]->{tot});
      $self->stash(content => $latest);
      $self->render('editpost');
    }
  }
#/editpost
  $self->render('admin');
};


get '/rss.xml' => sub
{
  my $self = shift;
  my $latest = get_entry($entry_db, 0, 0);
  $self->stash(content => $latest);
  $self->stash(site_title => $site_title);
  $self->stash(site_description => $site_description);
  $self->stash(site_author => $site_author);
  $self->stash(page_ttl => $page_ttl);
  $self->render('rss');
};

get '/atom.xml' => sub
{
  my $self = shift;
  my $latest = get_entry($entry_db, 0, 0);
  $self->stash(content => $latest);
  $self->stash(site_title => $site_title);
  $self->stash(site_description => $site_description);
  $self->stash(site_author => $site_author);
  $self->render('atom');
};

#last because it catches everything else
get '/(*entry)' => {entry => 'latest'} => sub
{
  my $self = shift;
  $self->res->headers->cache_control("public, max-age=$page_ttl");
  if ($self->param('entry') eq 'latest')
  {
  #get the latest entries
    my $cur_page = $self->param('page') || 0;
    my $latest = get_entry($entry_db, 0, $cur_page);
    my $total_page = get_total_pages($entry_db);
    $self->stash(content => $latest);
    $self->stash(cur_page => $cur_page);
    $self->stash(total_page => $total_page->[0]->{tot});
    $self->stash(site_title => $site_title);
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
    if (! $latest->[0])
    {
      $self->res->code("404");
      $self->render('404');
    }
    $self->stash(content => $latest);
    $self->stash(total_page => 0);
    $self->stash(site_title => $latest->[0]->{title});
    $self->render;
  }
  
};

sub check_auth
{
  my $auth = shift;
  chomp $auth;
  $auth =~ s/(?i-smx:Basic\s*)?//g;
  $auth = Mojo::Util::b64_decode $auth;
  (my $u, my $p) = split(':', $auth);
  if ($u eq $config->{username} && $p eq $config->{password})
  {
    return 1; #true
  }
  else
  {
    return 0; #false
  }
}

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
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","") or die "connect: $DBI::errstr $dbfile";
  $dbh->do("PRAGMA foreign_keys = ON");
#TODO add better error handling
  my $sth = $dbh->prepare("INSERT INTO blog( title, text, slug, sb_date ) VALUES(?, ?, ?, datetime(?))");
  $sth->execute( "$title", "$text", "$slug", "$date" ) or die "execute $DBI::errstr $dbfile";
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
  my @keys = ("blog.id", "blog.sb_date", "blog.slug", "blog.title", "blog.text");
  my $keys_txt = join(",", @keys);
  if ($entry eq "0")
  {
    $sql = "SELECT $keys_txt from blog ORDER BY strftime('%s',blog.sb_date) DESC LIMIT $limit_page OFFSET $cur_page";
    $res = $dbh->selectall_arrayref($sql, { Slice => {} });
  }
  else
  {
    #single entry
    $sql = "SELECT $keys_txt from blog WHERE slug = \"$entry\"";
    $res = $dbh->selectall_arrayref($sql, { Slice => {} });
  }
#TODO add better error handling
  foreach my $e (@$res)
  {
    my $sqltags = "SELECT text AS t_text from tags WHERE ref = $e->{id}";
    my @restags = @{$dbh->selectall_arrayref($sqltags, { Slice => {} })};
    my @tags;
    foreach my $t (@restags) { push(@tags, $t->{t_text}); }
    $e->{t_text} = join(",", @tags);
  }
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

sub del_entry
{
  my $dbfile = shift;
  my $entry = shift;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
#todo get the tags list
  $dbh->do("PRAGMA foreign_keys = ON");
  my $res;
  if ($entry =~ m#^\d+$#)
  {
    my $rv = $dbh->do("DELETE from tags WHERE ref=$entry");
    my $rv2 = $dbh->do("DELETE from blog WHERE id=$entry");
  }
  else
  {
    print "wtf? $dbfile, $entry\n";
  }
  
}

app->start;
__DATA__

@@ entry.html.ep
% layout 'entry', title => $site_title;
<body>
<div id="blog">
% foreach my $art (@$content)
% {
% my $slug = Mojo::Util::b64_decode $art->{slug};
<div id=<%== "$art->{id}" %> class="entry">
<h5><span class="title"><%== $art->{title} %>, </span> <span class="sb_date"><%== $art->{sb_date} %></span> <span class="slug"><%= link_to "#" => "$slug" %></span></h5>
<div class="text"><%== $art->{text} %></div>
<p><span class="tags">tags: <%= join(", ", split(/\s+/, $art->{t_text})) %></span></p>
</div>
<div class="between"><hr /><br /></div>
% }
<div class="botnav">
% for (my $i = 0; $i <= $total_page; $i++)
% {
%  if ($total_page > 1)
%  {
<%== "<a href=\"?page=$i\">$i</a> " %>
%  }
% }
</div>
</div>

@@ rss.xml.ep
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
<atom:link href="<%= (url_for)->to_abs %>" rel="self" type="application/rss+xml" />
<title><%= $site_title %></title>
<description><%= $site_description %></description>
<link><%= (url_for "entry")->to_abs %></link>
<ttl><%= $page_ttl %></ttl>
% foreach my $art (@$content)
% {
% my $slug = Mojo::Util::b64_decode $art->{slug};
<item>
 <title><%= $art->{title} %></title>
 <link><%= (url_for $slug)->to_abs %></link>
 <guid><%= (url_for $slug)->to_abs %></guid>
 <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/"><%= $site_author %></dc:creator>
% my $t822 = Time::Piece->strptime("$art->{sb_date}", "%Y-%m-%d %T");
% my $t822_stamp = $t822->day . ", " . $t822->mday ." ". $t822->monname ." ". $t822->year ." ". $t822->hms ." ". "GMT";
 <pubDate><%= $t822_stamp %></pubDate>
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
<%= link_to url_for->query(newpost => 1) => begin %>new post<% end %>
</p>
<p>
<%= link_to url_for->query(editpost => 1) => begin %>edit post<% end %>
</p>
<p>
<%= link_to url_for->query(upload => 1) => begin %>upload media<% end %>
</p>
<ul>
</ul>
</body>
</html>

@@ newpost.html.ep
<html>
<head><title>new post</title></head>
<body>
<form method="post" action="<%= url_for('admin')->query(newpost => 1) %>">
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
% foreach my $art (@$content)
% {
% my $slug = Mojo::Util::b64_decode $art->{slug};
<div class="entry">
 id: <%= $art->{id} %> <a href="<%= url_for('admin')->query(editpost => 1, delete => $art->{id}) %>">del</a> 
                       <a href="<%= url_for('admin')->query(editpost => 1, edit => $art->{id}) %>">edit</a>
<br />
 title: <%= $art->{title} %><br />
 slug: <%= url_for $slug %><br />
 tags: <%= $art->{t_text} %><br />
 text: <%= $art->{text} %><br />
<div class="between"><hr /><br /></div>
% }
<div class="botnav">
% for (my $i = 0; $i <= $total_page; $i++)
% {
%  if ($total_page > 1)
%  {
<a href="<%= url_for('admin')->query(editpost => 1, page => $i) %>"><%= $i %></a>
%  }
% }
</div>
</body>
</html>

@@ 401.html.ep
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
 "http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd">
<HTML>
  <HEAD>
    <TITLE>Error</TITLE>
    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=ISO-8859-1">
  </HEAD>
  <BODY><H1>401 Unauthorized.</H1></BODY>
</HTML>

@@ 404.html.ep
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
 "http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd">
<HTML>
  <HEAD>
    <TITLE>Error</TITLE>
    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=ISO-8859-1">
  </HEAD>
  <BODY><H1>404 not found.</H1></BODY>
</HTML>
