#!/usr/bin/env perl

use strict;
use warnings;
use inc::Module::Install 1.00;
use Module::Install::Repository 0.06;
use Module::Install::AutoManifest 0.003;
use Module::Install::ReadmeMarkdownFromPod 0.003;
use Module::Install::Homepage 0.01;
use Module::Install::AutoLicense 0.08;
use Module::Install::ManifestSkip 0.14;

all_from 'lib/Test/DBIx/Class.pm';
requires 'Config::Any' => '0.19';
requires 'DBIx::Class' => '0.08123';
requires 'DBIx::Class::Schema::PopulateMore' => '0.15';
requires 'DBIx::Class::TimeStamp' => '0.13';
requires 'DBIx::Class::UUIDColumns' => '0.02005';
requires 'Data::UUID' => '1.215';
requires 'Data::Visitor' => '0.27';
requires 'Digest::MD5' => '2.39';
requires 'Hash::Merge' => '0.11';
requires 'List::MoreUtils' => '0.22';
requires 'Moose' => '1.10';
requires 'MooseX::Attribute::ENV' => '0.01';
requires 'MooseX::Types' => '0.23';
requires 'Path::Class' => '0.21';
requires 'SQL::Translator' => '0.11006';
requires 'Scalar::Util' => '1.23';
requires 'Sub::Exporter' => '0.982';
requires 'Test::Builder' => '0.96';
requires 'Test::Differences' => '0.5';


feature('MySql Support', -default => 0, 'Test::mysqld' => '0.11');
feature('Postgresql Support', -default => 0, 'Test::postgresql' => '0.09');

test_requires 'Test::More' => '0.94';
tests_recursive;

readme_markdown_from_pod;
auto_set_repository;
auto_set_homepage;
auto_manifest;
auto_license;
auto_install;
WriteAll;

