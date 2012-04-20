package WWW::Session;

use 5.006;
use strict;
use warnings;

=head1 NAME

WWW::Session - WWW Sessions with multiple backends

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

This module allows you to easily create sessions , store data in them and later
retrieve that information, using mutiple storage backends

Example: 

    use WWW::Session;
    
    #set up the storage backends                 
    WWW::Session->add_storage( 'File', {path => '/tmp/sessions'} );
    WWW::Session->add_storage( 'Memcached', {servers => ['127.0.0.1:11211']} );
    
    #Set up the serialization engine (defaults to JSON)
    WWW::Session->serialization_engine('JSON');
    
    #Set up the default expiration time (in seconds or -1 for never)
    WWW::Session->default_expiration_time(3600);
    
    #and than ...
    
    #Create a new session
    my $session = WWW::Session->new($sid,$hash_ref);
    ...
    $session->sid(); #returns $sid
    $session->data(); #returns $hash_ref
    
    #returns undef if it doesn't exist or it's expired
    my $session = WWW::Session->find($sid); 
    
    #returns the existing session if it exists, creates a new session if it doesn't
    my $session = WWW::Session->find_or_create($sid);  


We can automaticaly deflate/inflate certain informations when we store / retrieve
from storage the session data:

    WWW::Session->setup_field( 'user',
                               inflate => sub { return Some::Package->new( $_[0]->id() ) },
                               deflate => sub { $_[0]->id() }
                            );

Another way to initialize the module :

    use WWW::Session storage => [ 'File' => { path => '/tmp/sessions'},
                                  'Memcached' => { servers => ['127.0.0.1'] }
                                ],
                     serialization => 'JSON',
                     expires => 3600,
                     fields => {
                        user => {
                            inflate => sub { return Some::Package->new( $_[0]->id() ) },
                            deflate => sub { $_[0]->id() },
                        }
                     };
                     

=head1 Internal variables

This modules uses some internal variables used to store the storage, serialization
and field settings

=cut
my @storage_engines = ();
my $serializer = __PACKAGE__->serialization_engine('JSON');
my $default_expiration = -1;
my $fields_modifiers = {};

=head1 SUBROUTINES/METHODS

=head2 new

Creates a new session object with the unique identifier and the given data.
If a session with the same identifier previously existed it will be overwritten

Parameters

=over 4

=item * sid = unique id for this session

=item * data = hash reference containing the data that we want to store in the session object

=item * exipres = for how many secconds is this session valid (defaults to the default expiration time)

=back

Retuns a WWW::Session object

=cut

sub new {
    my ($class,$sid,$data,$expires) = @_;
    
    $expires ||= -1;
    $data ||= {};
    
    die "You cannot use a undefined string as a session id!" unless $sid;
    
    my $self = {
                data    => {},
                expires => $expires,
                sid     => $sid,
               };
    
    bless $self, $class;
    
    $self->set($_,$data->{$_}) foreach keys %{$data};
    
    return $self;
}

=head2 find

Retieves the session object for the given session id

=cut
sub find {
    my ($class,$sid) = @_;
    
    die "You cannot use a undefined string as a session id!" unless $sid;
    
    my $info;
    
    foreach my $storage (@storage_engines) {
        my $info = $storage->retrieve($sid);
        last if defined $info;
    }
    
    if ($info) {
        return $class->load($info);
    }
    
    return undef;
}

=head2 find_or_create

Retieves the session object for the given session id if it exists, if not it
creates a new object with the given session id

=over 4

=item * sid = unique id for this session

=item * data = hash reference containing the data that we want to store in the session object

=item * exipres = for how many secconds is this session valid (defaults to the default expiration time),

=back

=cut
sub find_or_create {
    my ($class,$sid,$data,$expires) = @_;
    
    my $self = $class->find($sid);
    
    if ($self) {
        $self->expires($expires) if defined ($expires);
        $self->set($_,$data->{$_}) foreach keys %{$data};
    }
    else {
        $self = $class->new($sid,$data,$expires);
    }
    
    return $self;
}


=head2 set

Adds/sets a new value for the given field

=cut
sub set {
    my ($self,$field,$value) = @_;
    
    if (! defined $value && exists $fields_modifiers->{$field} && defined $fields_modifiers->{$field}->{default}) {
        $value = $fields_modifiers->{$field}->{default};
    }
    
    my $validated = 1;
    
    if ( exists $fields_modifiers->{$field} && defined $fields_modifiers->{$field}->{filter} ) {
        
        my $validated = 0; #we have a filter, check the value against the filter first
        
        my $filter = $fields_modifiers->{$field}->{filter};
        
        die "Filter must be a hash ref or array ref or code ref" unless ref($filter);
        
        if (ref($filter) eq "ARRAY") {
            if ($value ~~ @{$filter}) {
                $validated = 1;
            }
        }
        elsif (ref($filter) eq "CODE") {
            $validated = $filter->($value);
        }
        elsif (ref($filter) eq "HASH") {
            my $h_valid = 1;
            
            if ( defined $filter->{isa} ) {
                $h_valid = 0 unless ref($value) eq $filter->{isa};
            }
            
            $validated = $h_valid;
        }
    }
    
    if ($validated) {
        $self->{data}->{$field} = $value;
    }
    else {
        warn "Value $value didn't failed validation for key $field";
    }
    
    return $validated;
}


=head2 get

Retrieves the value of the given key from the session object
    
=cut
sub get {
    my ($self,$field) = @_;
    
    return $self->{data}->{$field};
}

=head2 add_storage

Adds a new storge engine to the list of Storage engines that will be used to
store the session info

Usage :

    WWW::Session->add_storage($storage_engine_name,$storage_engine_options);
    
Parameters :

=over 4

=item * $storage_engine_name = Name of the class that defines a valid storage engine

For WWW::Session::Storage::* modules you can use only the name of the storage,
you don't need the full name. eg Memcached and WWW::Session::Storage::Memcached
are synonyms

=item * $storage_engine_options = hash ref containing the options that will be
passed on to the storage engine module when new() is called

=back

Example :

    WWW::Session->add_storage( 'File', {path => '/tmp/sessions'} );
    
    WWW::Session->add_storage( 'Memcached', {servers => ['127.0.0.1:11211']} );

See each storage module for aditional details

=cut
sub add_storage {
    my ($class,$name,$options) = @_;
    
    $options ||= {};
    
    if ($name !~ /::/) {
        $name = "WWW::Session::Storage::$name";
    }
    
    eval "use $name";
        
    die "WWW::Session cannot load '$name' storage engine! Error : $@" if ($@);
    
    my $storage = $name->new($options);
    
    if ($storage) {
        push @storage_engines, $storage;
    }
    else {
        die "WWW::Session storage engine '$name' failed to initialize with the given arguments!";
    }
}

=head2 serialization_engine

Configures the serialization engine to be used for serialising sessions.

The default serialization engine is JSON

Usage :

    WWW::Session->serialization_engine('JSON');
    
Parameters :

=over 4

=item * $serialization_engine_name = Name of the class that defines a valid serialization engine

For WWW::Session::Serialization::* modules you can use only the short name of the module,
you don't need the full name. eg JSON and WWW::Session::Serialization::JSON
are synonyms

=back

=cut
sub serialization_engine {
    my ($class,$name) = @_;
    
    if ($name !~ /::/) {
        $name = "WWW::Session::Serialization::$name";
    }
    
    eval "use $name";
        
    die "WWW::Session cannot load '$name' serialization engine! Error : $@" if ($@);
    
    my $serializer_object = $name->new($fields_modifiers);
    
    if ($serializer_object) {
        $serializer = $serializer_object;
    }
    else {
        die "WWW::Session serialization engine '$name' failed to initialize!";
    }
}


=head1 Private methods

=head2 save

Serializes a WWW::Session object sends it to all storage engines for saving

=cut

sub save {
    my ($self) = @_;
    
    my $data = {
                sid => $self->{sid},
                expires => $self->{expires},
               };
    
    foreach my $field ( keys %{$self->{data}} ) {
        if (defined $fields_modifiers->{$field} && defined $fields_modifiers->{$field}->{inflate}) {
            $data->{data}->{$field} = $fields_modifiers->{$field}->{inflate}->($self->{data}->{$field});
        }
        else {
            $data->{data}->{$field} = $self->{data}->{$field}
        }
    }
    
    my $string = $serializer->serialize($data);
    
    foreach my $storage (@storage_engines) {
        $storage->save($self->{sid},$self->{expires},$string);
    }
}


=head2 load

Deserializes a WWW::Session object from the given string and deflates all the fields that
were inflated when the session was serialized

=cut

sub load {
    my ($class,$string) = @_;
    
    my $self = $serializer->expand($string);
    
    foreach my $field ( keys %{$self->{data}} ) {
        if (defined $fields_modifiers->{$field} && defined $fields_modifiers->{$field}->{deflate}) {
            $self->{data}->{$field} = $fields_modifiers->{$field}->{deflate}->($self->{data}->{$field});
        }
    }
    
    bless $class,$self;
    
    return $self;
}


=head2 import

Configures the module.

=cut

sub import {
}

=head1 AUTHOR

Gligan Calin Horea, C<< <gliganh at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-session at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Session>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Session


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Session>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Session>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Session>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Session/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Gligan Calin Horea.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of WWW::Session
