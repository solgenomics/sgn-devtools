use Module::Build;
my $build = Module::Build->new(
    module_name        => 'sgn-devtools',
    dist_author        => 'The SGN Team',
    dist_version            => '0.01',
    license            => 'gpl',
    create_makefile_pl => 'passthrough',
    dist_abstract      => 'SGN Developer Tools',
    add_to_cleanup     => [ ],
    meta_merge           => {
        resources =>
          { repository => 'http://github.com/solgenomics/sgn-devtools', },
    },

    # and now the list of perl module dependencies
    requires           => {
    # These are requirements for sgn-devtools
     'perl'                        => '5.10.0',
     'Carp'                        => 0,
     'Socket'                      => 0,
     'JSON::Any'                   => 0,
     'Mail::Sendmail'              => 0,
     'Tie::Function'               => 0,
     'DBIx::Class::Schema::Loader' => 0,
     'List::MoreUtils'             => 0,
     'DateTime::Format::ISO8601'   => 0,
     'DateTime::TimeZone::Local'   => 0,
     'Pod::Usage'                  => 0,
     'autodie'                     => 0,
    # These are optional developer-only requirements for other SGN repos
     'Catalyst::Restarter' => 0,
    },
    build_requires => {
    },
);
$build->create_build_script;
