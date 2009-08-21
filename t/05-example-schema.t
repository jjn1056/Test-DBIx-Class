use Test::More; {

	## This test uses an 'old school' deploy and test setup.  You can use it to
	## compare with the Test::DBIx::Class rewrite.  Also, we just need to test
	## our Example Schema and make sure it's all good.

	use strict;
	use warnings;
	
	require_ok 'Test::DBIx::Class::Example::Schema';

	## Connect and Deploy a Schema
	ok my @connect = (
		$ENV{TEST_DBIX_CLASS_EXAMPLE_DNS}  || 'dbi:SQLite:dbname=:memory:',
		$ENV{TEST_DBIX_CLASS_EXAMPLE_USER} || '',
		$ENV{TEST_DBIX_CLASS_EXAMPLE_PASS} || ''
	)  => 'Created connect info';

	ok my $schema = Test::DBIx::Class::Example::Schema->connect(@connect)
	  => 'Connected to sqlite in memory database';

	eval {
		$schema->deploy();
	}; 
	
	is $@, ''
	  => 'Got no deploy error';

	## Populate Jobs
	ok my $job_rs = $schema->resultset('Job')
	  => 'Found Job';

	ok my ($programmer, $marketer, $admin) = $job_rs->populate([
[name => 'description'],
		[programmer => 'who writes the code'],
		[marketer => 'who sells the code'],
		[admin => 'who runs the code'],
	]) => 'Successful populate on Job';

	is_deeply 
		[map { [@$_{qw/name description/}] } sort {$a->{name} cmp $b->{name}} $job_rs->hri_dump],
		[
			["admin", "who runs the code"],
			["marketer", "who sells the code"],
			["programmer", "who writes the code"],
		], 'Got Expected Data';

	## Populate Companies
	ok my $company_rs = $schema->resultset('Company')
	  => 'Found Company';

	ok my ($bms, $takkle, $safehorizons) = $company_rs->populate([
		['name'],
		['Bristol Myers Squibb'],
		['Takkle'],
		['Safe Horizons'],
	]) => 'Successful populate on Company';
	
	## Populate Persons
	ok my $person_rs = $schema->resultset('Person')
	  => 'Found Person';

	ok my ($john, $vincent, $vanessa) = $person_rs->populate([
		['name', 'age', 'email'],
		['John', 40, 'john@nowehere.com'],
		['Vincent', 15, 'vincent@home.com'],
		['Vanessa', 35, 'vanessa@school.com'],
	]) => 'Successful populate on Person';

	## Populate Phone
	ok my $phone_rs = $schema->resultset('Phone')
	  => 'Found Phone';

	 $john->add_to_phone_rs({number=>2123879509});	
	 $john->add_to_phone_rs({number=>6467081837});	
	 $vincent->add_to_phone_rs({number=>2123879509});
	 $vanessa->add_to_phone_rs({number=>2123879509});	

	## Make someone an employee
	ok my $person_employee = $schema->resultset('Person::Employee')
	  => 'Found Person::Employee';

	ok my $john_employee = $person_employee->create({person=>$john})
	 => 'Make john an employee';

	## Add them to a company
	$bms->add_to_employees(
		$john_employee, {
			job=>$programmer, 
			started=>'01/01/1996', 
			ended=>'01/01/2004',
		}
	);

	## Make some Persons into an Artist
	ok my $person_artist = $schema->resultset('Person::Artist')
	  => 'Found Person::Artist';

	ok my $vanessa_artist = $person_artist->create({person=>$vanessa})
	  => 'Vanessa is now an artist';

	ok my $john_artist = $person_artist->create({person=>$john})
	  => 'John is now an artist';

	## Create some CDs

	ok my $cd_rs = $schema->resultset('CD'),
	  => 'Got the CD Resultset';

	ok my $first_album = $cd_rs->create({
		name => 'My First Album',
		track_rs => [
			{position=>1, title=>'the first song'},
			{position=>2, title=>'yet another song'},
		],
		cd_artist_rs=> [
			{person_artist=>$vanessa_artist},
			{person_artist=>$john_artist},
		],
	});

	done_testing();
}
