$VAR1 = {
  'schema_class' => 'Test::DBIx::Class::Example::Schema',
  'fixture_sets' => {
    'basic' => {
      'Person' => [
        [
          'name',
          'age',
          'email'
        ],
        [
          'John',
          '40',
          'john@nowehere.com'
        ],
        [
          'Vincent',
          '15',
          'vincent@home.com'
        ],
        [
          'Vanessa',
          '35',
          'vanessa@school.com'
        ]
      ]
    }
  },
  'resultsets' => [
    'Person',
    'Job',
    'Person' => { -as => 'NotTeenager', search => {age => { '>'=>19 } } }
  ]
};
