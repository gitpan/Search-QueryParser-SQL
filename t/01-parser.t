use Test::More tests => 18;

use_ok('Search::QueryParser::SQL');

ok( my $parser = Search::QueryParser::SQL->new(
        columns        => [qw( foo color name )],
        default_column => 'name'
    ),
    "new parser"
);

ok( my $query1 = $parser->parse('foo=bar'), "query1" );

cmp_ok( $query1, 'eq', "(foo='bar')", "query1 string" );

ok( my $query2 = $parser->parse('foo:bar'), "query2" );

cmp_ok( $query2, 'eq', "(foo='bar')", "query2 string" );

ok( my $query3 = $parser->parse( 'foo bar', 1 ), "query3" );

cmp_ok( $query3, 'eq', "(name='foo') AND (name='bar')", "query3 string" );

ok( my $query4 = $parser->parse('-color:red (name:john OR foo:bar)'),
    "query4" );

cmp_ok(
    $query4, 'eq',
    "((name='john') OR (foo='bar')) AND (color!='red')",
    "query4 string"
);

ok( my $parser2 = Search::QueryParser::SQL->new(
        columns => [qw( first_name last_name email )],
    ),
    "parser2"
);

ok( my $query5 = $parser2->parse("joe smith"), "query5" );

cmp_ok(
    $query5,
    'eq',
    "(first_name='joe' OR last_name='joe' OR email='joe') OR (first_name='smith' OR last_name='smith' OR email='smith')",
    "query5 string"
);

ok( my $query6 = $parser2->parse('"joe smith"'), "query6" );

cmp_ok(
    $query6,
    'eq',
    "(first_name='joe smith' OR last_name='joe smith' OR email='joe smith')",
    "query6 string"
);

ok( my $parser3 = Search::QueryParser::SQL->new(
        columns       => [qw( foo bar )],
        quote_columns => '`',
    ),
    "parser3"
);

ok( my $query7 = $parser3->parse('green'), "query7" );

cmp_ok( $query7, 'eq', "(`foo`='green' OR `bar`='green')", "query7 string" );

