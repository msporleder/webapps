package PkgsrcDashboard::Plugin::Src;
require Exporter;

use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use strict;
use warnings;
our $VERSION   = 1.00;   # Version number
our @ISA       = qw(Exporter);
our @EXPORT    = qw(plug_execute pkg_src_old form_info);  # Symbols to be exported by default
our @EXPORT_OK = qw();  # Symbols to be exported on request
our %EXPORT_TAGS = ();  # eg: TAG => [ qw!name1 name2! ]


sub _plug_init
{
	my $dbh = DBI->connect("dbi:SQLite:dbname=$pkgdir/pkgsrc-dashboard", undef, undef, {RaiseError => 1, AutoCommit => 0});
    my $sql = qq{ALTER TABLE pkglist ADD COLUMN 'current-src' TEXT};
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
	my $sth = $dbh->column_info( undef, undef, 'pkglist', 'current-src' );
	my $ret = $sth->fetchrow_hashref();
	return $sth->rows();
}

sub form_info
{
	return qq(src check? <br /> <input type="checkbox" name="srccheck" value="1" />);
}

sub plug_execute
{
#Main stuff goes here
}

sub pkg_src_old
{
        my $pkgname = $_[0];
        if ($pkgname =~ /([0-9a-zA-Z-\._\+]+)/)
        {
                $pkgname = $1;
        } else {
                die "tained failed";
        } #untaint $pkgname

        system ("check-dated-src.pl", "$pkgname");
        return $? >> 8; #see perdoc -f system
}


1;

__END__
=head1 NAME

 PkgsrcDashboard source freshness check

=head1 DESCRIPTION

 PkgsrcDashboard check if newer source is available

=head1 FUNCTIONS

=over

=item pkg_src_old

 Checks to see if a newer source is available in a source repository's INDEX

=back
