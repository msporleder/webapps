package PkgsrcDashboard::Plugin::Bin;
require Exporter;

use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use strict;
use warnings;
our $VERSION   = 1.00;   # Version number
our @ISA       = qw(Exporter);
our @EXPORT    = qw(plug_execute pkg_bin_old form_info);  # Symbols to be exported by default
our @EXPORT_OK = qw();  # Symbols to be exported on request
our %EXPORT_TAGS = ();  # eg: TAG => [ qw!name1 name2! ]

use strict;
use warnings;

sub _plug_init
{
	my $dbh = DBI->connect("dbi:SQLite:dbname=$pkgdir/pkgsrc-dashboard", undef, undef, {RaiseError => 1, AutoCommit => 0});
    my $sql = qq{ALTER TABLE pkglist ADD COLUMN 'current-bin' TEXT};
    my $sth = $dbh->prepare($sql);
    my $rows = $sth->execute() or die "$sql failed";
    $dbh->commit;
    $sth->finish;
    $dbh->disconnect;

}

sub _is_init
{
	my $pkgdir = $_[0];
	my $dbh = DBI->connect("dbi:SQLite:dbname=$pkgdir/pkgsrc-dashboard", undef, undef, {RaiseError => 1, AutoCommit => 0});
	my $sth = $dbh->column_info( undef, undef, 'pkglist', 'current-bin' );
	my $ret = $sth->fetchrow_hashref();
	return $sth->rows();
}

}

sub form_info
{
	return qq(<input type="text" name="pkgpath" /><br />);
}

sub plug_execute
{
#Main stuff goes here
}

sub pkg_bin_old
{
        my $pkgname = $_[0];
        my $pkgdir = $_[1];
        if ($pkgname =~ /([0-9a-zA-Z-\._\+]+)/)
        {
                $pkgname = $1;
        } else {
                die "tained failed";
        } #untaint $pkgname
        if ( ($pkgdir !~ /^\./) and ($pkgdir =~ /([0-9a-zA-Z-\/\._]+)/) )
        { 
                $pkgdir = $1;
        } else {
                die "failed taint";
        } #taint check
        print p("checking bin: $pkgname, $pkgdir");
        system ("check-dated-bin.pl", "$pkgname", "$pkgdir");
        return $? >> 8;
}

sub fetch_pkg_summary
{
        my $pkgdir = $_[0];
        my $pkgpath = $_[1];
        if ( ($pkgdir !~ /^\./) and ($pkgdir =~ /([0-9a-zA-Z-\/\._]+)/) )
        { 
                $pkgdir = $1;
        } else {
                die "failed taint";
        }#taint check
        if ( $pkgpath =~ /([0-9a-zA-Z-\/\._:]+)/ )
        {
                $pkgpath = $1;
        } else {
                die "failed taint";
        }
        print p("pkgpath: $pkgpath, pkgdir: $pkgdir");
        system ("fetch-pkg-summary.sh", "$pkgdir", "$pkgpath");
}

1;

__END__

=head1 NAME

 PkgsrcDashboard binary freshness check

=head 1 DESCRIPTION

 This checks if a pkg is older than one in a pkg_summary file

=head1 FUNCTIONS

=over

=item pkg_fetch_summary

 Downloads a pkg_summary from a given PKG_PATH

=item pkg_bin_old

 Checks for a newer version of the pkg

=back
