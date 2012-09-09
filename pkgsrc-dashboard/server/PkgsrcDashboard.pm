package PkgsrcDashboard;

require Exporter;
use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use strict;
use warnings;
our $VERSION   = 1.00;   # Version number
our @ISA       = qw(Exporter);
our @EXPORT    = qw(new run_plugins key_exists init_date_dir pkg_entry);  # Symbols to be exported by default
our @EXPORT_OK = qw();  # Symbols to be exported on request
our %EXPORT_TAGS = ();  # eg: TAG => [ qw!name1 name2! ]

use Module::Pluggable require => 1;
use DBD::SQLite;
use DBI;

#This is the main module for pkgsrc-dashboard
#It will call all the routines for creating reports

our @plugins;

sub new
{
	my $this = shift;
	@plugins = $this->plugins();
	return $this;
}

sub run_plugins
{
	my $parent = shift;
	my $params = shift;
	my $pkgdir = shift;
	foreach my $plug (@plugins)
	{
		$plug->plug_execute($params, $pkgdir);
	}
	return 1;
}

sub form_info
{
	my $parent = shift;
	my $params = shift;
	my $pkgdir = shift;
	foreach my $plug (@plugins)
	{
		print $plug->form_info($params, $pkgdir);
	}
}


#a valid host = $workdir/$hostkey
sub key_exists
{
        my $workdir = $_[0];
        my $hostkey = $_[1];
        if (-d "$workdir/$hostkey")
        {
                return "$workdir/$hostkey";
        } else {
                warn "Try configuring the host in $workdir";
                return 0;
        }
}

sub init_date_dir
{
        my $pkgdir = "$_[0]";
		my $date = "$_[1]";
        mkdir "$pkgdir" or die "could not mkdir $pkgdir";
        my $dbh = DBI->connect("dbi:SQLite:dbname=$pkgdir/pkgsrc-dashboard", undef, undef, {RaiseError => 1, AutoCommit => 0});
        my $sql = qq{CREATE TABLE pkglist ( 'pkgname' TEXT UNIQUE NOT NULL )};
        my $sth = $dbh->prepare($sql);
        my $rows = $sth->execute() or die "$sql failed";
        $dbh->commit;
        $sth->finish;
        $dbh->disconnect;
}

sub pkg_entry
{
        my $pkgdir = "$_[0]";
        my $pkgname = "$_[1]";
        my $dbh = DBI->connect("dbi:SQLite:dbname=$pkgdir/pkgsrc-dashboard", undef, undef, {RaiseError => 1, AutoCommit => 0});
        my $sql = qq{INSERT INTO pkglist ('pkgname') VALUES (?)};
        my $sth = $dbh->prepare($sql);
        my $rows = $sth->execute($pkgname) or die "$sql failed";
        if ($rows)
        {
                $dbh->commit;
                $sth->finish;
                $dbh->disconnect;
                return 1;
        } else {
                $dbh->rollback;
                $sth->finish;
                $dbh->disconnect;
                return 0;
        }

}

1;

__END__

=head1 NAME

 The PkgsrcDashboard parent module

=head1 DESCRIPTION

 This provides the init functions for pkgsrc-dashboard;
 After that it runs all the Plugins it can find

=head1 FUNCTIONS

=over

=item Func1

 foo

=item Fun2

 bar

=back
