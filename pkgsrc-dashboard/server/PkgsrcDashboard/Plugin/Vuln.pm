package PkgsrcDashboard::Plugin::Vuln;
require Exporter;

use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use strict;
use warnings;
our $VERSION   = 1.00;   # Version number
our @ISA       = qw(Exporter);
our @EXPORT    = qw(plug_execute pkg_vuln form_info);  # Symbols to be exported by default
our @EXPORT_OK = qw();  # Symbols to be exported on request
our %EXPORT_TAGS = ();  # eg: TAG => [ qw!name1 name2! ]

sub _plug_init
{
	my $pkgdir = $_[0];
    my $dbh = DBI->connect("dbi:SQLite:dbname=$pkgdir/pkgsrc-dashboard", undef, undef, {RaiseError => 1, AutoCommit => 0});
    my $sql = qq{ALTER TABLE pkglist ADD COLUMN 'vulnerable' TEXT};
    my $sth = $dbh->prepare($sql);
    my $rows = $sth->execute() or die "$sql failed";
    $dbh->commit;
    $sth->finish;
    $dbh->disconnect;
	return 1;
}

sub _is_init
{
	my $pkgdir = $_[0];
    my $dbh = DBI->connect("dbi:SQLite:dbname=$pkgdir/pkgsrc-dashboard", undef, undef, {RaiseError => 1, AutoCommit => 0});
	my $sth = $dbh->column_info( undef, undef, 'pkglist', 'vulnerable' );
	my $ret = $sth->fetchrow_hashref();
	return $sth->rows();
}

sub plug_execute
{
	my $pkgname = $_[1]->{'pkgname'};
	my $pkgdir = $_[2];
#Main stuff goes here
	if ( _is_init($pkgdir) <= 0 )
	{
		print "initing vulnerable in $pkgdir";
		_plug_init($pkgdir);
	}
    my $dbh = DBI->connect("dbi:SQLite:dbname=$pkgdir/pkgsrc-dashboard", undef, undef, {RaiseError => 1, AutoCommit => 0});
	my $sql = qq{UPDATE pkglist SET 'vulnerable' = ? WHERE pkgname = ?};
	my $sth = $dbh->prepare($sql);
	my $rows = $sth->execute(pkg_vuln($pkgname), $pkgname) or die "$sql failed";
	if ($rows)
	{
		$dbh->commit;
		$sth->finish;
		$dbh->disconnect;
	}
	else
	{
		$dbh->rollback;
		$sth->finish;
		$dbh->disconnect;
	}
}

sub pkg_vuln
{
        my $pkgname = $_[0];
		$ENV{'PATH'} = '/bin:/usr/bin:/usr/sbin:/usr/pkg/libexec/cgi-bin';
		delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
        if ($pkgname =~ /([0-9a-zA-Z-\._\+]+)/)
        {
                $pkgname = $1;
        } else {
                die "tained failed";
        } #untaint $pkgname

        system ("pkg_admin", "audit-pkg", "$pkgname");
        return $? >> 8; #see perdoc -f system
}

sub form_info
{
	return qq(vuln check? <br /> <input type="checkbox" name="pkgvul" value="1" />);
}

1;

__END__

=head1 NAME

 PkgsrcDashboard check if a pkg is vulnerable

=head1 DESCRIPTION

 This checks to see if a pkg is vulnerable
 it also adds the 'vulnerable' column to the databases

=head1 FUNCTIONS

=over

=item pkg_vuln

 Runs pkg_admin audit-pkg pkgname and returns 1 if vulnerable

=item plug_execute

 Facilitate PkgsrcDashbard's needs

=back
