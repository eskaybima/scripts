#!/usr/bin/perl


# reads the comps.xml from a redhat or centos installation
use XML::Simple;

my ($comps_file, $rpm_path, $arch) = @ARGV;

if (!-e $comps_file)
{
    print_usage ("Can't find '$comps_file'");
}
if (!-e $rpm_path)
{
    print_usage ("RPM path '$comps_file' does not exist");
}
if (!$arch)
{
    print_usage ("Architecture not specified");
}

print "reading $comps_file...\n";
print "getting RPMs from $rpm_path...\n";

$xml = new XML::Simple;
$comps = $xml->XMLin($comps_file);

%copied_packages = {};

foreach $group (@{$comps->{group}})
{
    $id = $group->{id};
    if (!($id eq 'base' || $id eq 'core'))
    {
        next;
    }

    print "#### group \@$id\n";
    $packagelist = $group->{packagelist};
    foreach $pr (@{$packagelist->{packagereq}})
    {
        if ($pr->{type} eq 'optional')
        {
            next;
        }

        $cmd = "cp $rpm_path/" . $pr->{content} . "-[0-9]*.$arch.rpm"
                . " $rpm_path/" . $pr->{content} . "-[0-9]*.noarch.rpm .";
        print "$cmd\n";
        `$cmd 2>&1`;

        $copied_packages{$pr->{content}} = 1;
    }
}

sub print_usage
{
    my ($msg) = @_;

    ($msg) && print "$msg\n\n";

    print <<__TEXT__;
parse_comps.pl comps_file rpm_path arch
    comps_file   the full path to the comps.xml file (as provided in the
                 original distro
    rpm_path     the full path to the directory of all RPMs from the distro
    arch         the target system architecture (e.g. x86_64)


__TEXT__

    exit;
}
