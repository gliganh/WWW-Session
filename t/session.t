#!perl

use Test::More tests => 29;
use Test::Exception;

use_ok('WWW::Session');

lives_ok { WWW::Session->add_storage('File',{path => '.'}) } 'File storage added';
lives_ok { WWW::Session->serialization_engine('JSON') } 'JSON serialization configured';

{ #find
	note("tests for save() & find()");
	
	my $session = WWW::Session->new('123',{a => 1, b => 2});

	ok(defined $session,"Session created");

	is($session->sid(),'123','Sid ok');

	is($session->get('a'),1,'Value for a is correct');
	is($session->get('b'),2,'Value for b is correct');
	
	$session->save();
	
	my $session2 = WWW::Session->find('123');
	
	ok(defined $session2,"Session found after save");
	
	is($session2->sid(),'123','Sid for session 2ok');

	is($session2->get('a'),1,'Value for a from session2 is correct');
	is($session2->get('b'),2,'Value for b from session2 is correct');
}


{ #find or create
	note("tests for save() & find_or_create()");
	
	my $session = WWW::Session->new('123',{a => 1, b => 2});

	ok(defined $session,"Session created");

	is($session->sid(),'123','Sid ok');

	is($session->get('a'),1,'Value for a is correct');
	is($session->get('b'),2,'Value for b is correct');
	
	$session->save();
	
	my $session2 = WWW::Session->find_or_create('123',{a => 3, c => 4});
	
	ok(defined $session2,"Session found after save");
	
	is($session2->sid(),'123','Sid for session 2ok');

	is($session2->get('a'),3,'Value for a from session2 is correct');
	is($session2->get('b'),2,'Value for b from session2 is correct');
	is($session2->get('c'),4,'Value for c from session2 is correct');
}


{ #simple set
	note("tests for set() without filters");
	
	my $session = WWW::Session->new('123',{a => 1, b => 2});

	ok(defined $session,"Session created");

	is($session->sid(),'123','Sid ok');

	is($session->get('a'),1,'Value for a is correct');
	is($session->get('b'),2,'Value for b is correct');
	
	$session->set('a',3);
	
	is($session->get('a'),3,'Value for a after set is correct');
	
	$session->save();
	
	my $session2 = WWW::Session->find('123');
	
	ok(defined $session2,"Session found after save");
	
	is($session2->sid(),'123','Sid for session 2ok');

	is($session2->get('a'),3,'Value for a from session2 is correct');
	is($session2->get('b'),2,'Value for b from session2 is correct');
}

