#! /usr/pkg/bin/perl
BEGIN { push @INC, "/usr/pkg/libexec/cgi-bin"; }
use strict;
use warnings;
use PkgsrcDashboard;
use CGI qw(:standard :cgi-lib unescape escape);
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
warningsToBrowser(1);

our $workdir = "/usr/pkg/libexec/cgi-bin/working";
our @local = localtime(time());
our $today = sprintf "%04d%02d%02d", $local[5]+1900,$local[4]+1,$local[3];
our $pkgpath = 0;
our $params = Vars();
our $plugrunner = PkgsrcDashboard->new();

do "./pkglist.conf";

print header(), start_html("pkglist");
print p(
 "<form method=get>",
 "host key:<br />",
 "<input type=\"text\" name=\"hostkey\" /><br />",
 "pkg name:<br />",
 "<input type=\"text\" name=\"pkgname\" /><br />",
 "PKG_PATH (optional for bin pkg check):<br />",
 "<input type=\"text\" name=\"pkgpath\" /><br />",
);

print p( $plugrunner->form_info($params) );

print p(
 "<input type=\"submit\" />",
 "</form>",
);

if ( (my $hostkey = escape(param("hostkey"))) and (my $pkgname = escape(param("pkgname"))) )
{
	$hostkey = unescape($hostkey);
	$pkgname = unescape($pkgname);
	#Fix for + to " " conversion
	$hostkey =~ tr/ /+/;
	$pkgname =~ tr/ /+/;
	#is pkgpath set?
	if ( $pkgpath = param("pkgpath") )
	{
		$pkgpath = escape($pkgpath);
		$pkgpath = unescape($pkgpath);
	} else {
		$pkgpath = 0;
	}
#we now have $workdir, and $today
#url params end up in $params
	if ( my $pkgdir = key_exists($workdir, $hostkey) )
	{
		$pkgdir = "$pkgdir/$today";
		if ( ! -d $pkgdir )
		{
			init_date_dir($pkgdir);
			print p("creating $pkgdir");
		}
		if ( pkg_entry($pkgdir, $pkgname) )
		{
			print p("adding $pkgname");
#now run all of the plugins
			$plugrunner->run_plugins($params, $pkgdir);
		}
		else
		{
			die "failed to add $pkgname";
		}
	}
	else
	{
		die "Try creating a $hostkey directory in $workdir";
	}
}
print end_html();
