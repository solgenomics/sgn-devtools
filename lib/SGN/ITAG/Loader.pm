package SGN::ITAG::Loader;

use Moose;
with 'MooseX::Runnable';
with 'MooseX::Getopt';
use autodie qw(:all);
use 5.010;

=head1 NAME

SGN::ITAG::Loader

=head1 DESCRIPTION

Simple wrapper script which generates the commands necessary to load
ITAG1_release. This will evolve more to support loading different ITAG releases
and use different loading scripts.

It can be run with

    mx-run SGN::ITAG::Loader --dbhost localhost dbuser postgres --dbpass '' \
        --loader_options '--analysis --recreate_cache --noexon' \
        --organism 'tomato' --loader gmod_bulk_load_gff3.pl

All the above options are the defaults, so that is exactly the same as

    mx-run SGN::ITAG::Loader

If sgn-devtools/lib is not in your PATH you can add it when you run mx-run

    PERL5LIB=$PERL5LIB:./lib mx-run SGN::ITAG::Loader

Currently it only prints all the commands necessary, it may actually excecute
them in the future.

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

has dbhost => (
    is      => 'ro',
    default => 'localhost',
    isa     => 'Str',
);
has dbuser => (
    is      => 'ro',
    default => 'postgres',
    isa     => 'Str',
);
has dbpass => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);
has dbname => (
    is      => 'ro',
    default => 'cxgn',
    isa     => 'Str',
);
has organism => (
    is      => 'ro',
    default => 'tomato',
    isa     => 'Str',
);
has loader_options => (
    is      => 'ro',
    default => '--analysis --recreate_cache --noexon',
    isa     => 'Str',
);

has loader => (
    is      => 'ro',
    default => 'gmod_bulk_load_gff3.pl',
    isa     => 'Str',
);

#time ./gmod_bulk_load_gff3.pl --dbname cxgn --dbhost db.sgn.cornell.edu  --gfffile ITAG1_genomic_reference.gff3 --organism 'Solanum lycopersicum' --analysis --recreate_cache   --save_tmpfiles --dbuser postgres --dbpass 'foo' &> load2.log & tail -f load2.log

sub run {
    my ($self, %args) = @_;
    my @files = qw(
        ITAG1_genomic_reference.gff3
        ITAG1_genomic.fasta
        ITAG1_gene_models.gff3
        ITAG1_cdna_alignments.gff3
        ITAG1_infernal.gff3
        ITAG1_de_novo_gene_finders.gff3
        ITAG1_sgn_data.gff3
        ITAG1_protein_reference.gff3
        ITAG1_proteins.fasta
        ITAG1_protein_functional.gff3
    );
    for my $file (@files) {
        my $command_template = "time %s --dbhost %s --dbname %s --dbuser %s --dbpass %s --gfffile $file --organism %s %s &> load_itag.$file.$$.log";
        my $cmd = sprintf $command_template, map { $self->$_ }
                    qw/loader dbhost dbname dbuser dbpass organism loader_options/;
        say $cmd;
    }
}

1;
