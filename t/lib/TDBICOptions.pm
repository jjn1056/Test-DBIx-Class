package TDBICOptions;

use File::Path qw!rmtree!;

my $keep_db = $ENV{KEEP_DB};
my $base_dir = $ENV{BASE_DIR};

sub notify{
    if ($keep_db || $base_dir){
        emit(
            'This test is designed to exercise the keep_db and base_dir options of',
            'the Test::DBIx::Class module. By setting either of these via enviroment',
            'variables you are restricting the coverage of these tests. We will',
            'adapt the tests as required to accommodate these settings.',
            '',
        );
    }
    if ($keep_db){
        emit(
            'keep_db is set to true. We will not delete any databases created by',
            'these tests. We cannot test the automatic cleanup usually done when',
            'keep_db is not true',
            '',
        );
    }
    if($base_dir){
        emit(
            'base_dir is set. We will create all databases in this directory. We',
            'cannot test automatic tmp dir creation.',
            '',
        );
    }
}

sub check_base_dir{
    if (!$keep_db && $base_dir){
        if (-d $base_dir){
            opendir(my $dh, $base_dir) || die "can't opendir $base_dir: $!";
            my @content = grep { !/^\.\.?$/ } readdir($dh);
            die "\n\nWe will not use an existing directory with contents as base_dir without\nkeep_db set, otherwise we will delete existing contents"
                if @content;
            closedir $dh;
        }
    }
}

sub emit{
    foreach(@_){
        print "# $_\n";
    }
}

sub print_dirs_created{
    my ($dirs) = @_;
    if($keep_db){
        print "# tmp dirs created:\n";
        foreach(keys %$dirs){
            print "#\t$_\n";
        }
    }
}

sub dir_created{
    my ($dirs_created, $regex, $diag) = @_;

    if ($base_dir){
        $dir = $base_dir;
    } else {
        ($dir) = $diag =~ $regex;
    }

    if (!$keep_db){
      rmtree($dir) if $dir;
    } else {
        $dirs_created->{$dir} = 1;
    }

    return $dir;
}

1;
