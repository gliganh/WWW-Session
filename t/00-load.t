#!perl -T

use Test::More tests => 6;

BEGIN {
    use_ok( 'WWW::Session' ) || print "Bail out!\n";
    use_ok( 'WWW::Session::Storage::File' ) || print "Bail out!\n";
    use_ok( 'WWW::Session::Storage::MySQL' ) || print "Bail out!\n";
    use_ok( 'WWW::Session::Storage::Memcached' ) || print "Bail out!\n";
    use_ok( 'WWW::Session::Serialization::JSON' ) || print "Bail out!\n";
    use_ok( 'WWW::Session::Serialization::Storable' ) || print "Bail out!\n";
}

diag( "Testing WWW::Session $WWW::Session::VERSION, Perl $], $^X" );
