#! /usr/bin/perl

#####################################################################
# @file        generate_gtest_befriend_macros.pl 
# @author      Callum Noble
# @date        December 2013
# @brief       Passed a gtest file generates recursive pre-processor
#			   macro definitions for forward declaration and 
#			   befriending of all test cases within file.
#
#			   Accessed by macro hook provided in gtest_befriend_hook_macros.h
#####################################################################

use strict;
use warnings;
use Getopt::Long;
use File::Basename;

my $test_file;
my $header_output;
my $help;
my $now = localtime;

GetOptions("f=s" => \$test_file, "o=s" => \$header_output, "h" => \$help); 
usage("Help") if( defined $help );
usage("Input Google test file must be defined") if( ! defined $test_file );

###################################################################
# Determine default output file if not supplied
###################################################################

if( !defined $header_output)
{
	$header_output = $test_file;
	$header_output =~ s/\.[^.]+$//;
	$header_output .= "_macros.h"; 
}

my ($output_basename, $output_dir, $output_suffix) = basename($header_output);

###################################################################
# Re-format file name
###################################################################

my ($test_file_base, $test_dir, $suffix) = basename($test_file);

my $basename = $test_file_base;
$basename =~ s/\.[^.]+$//;

my $uc_basename = uc($basename);
my $uc_basename_header_guard = "$uc_basename"."_MACROS_H";

###################################################################
# Parse out tests from test file
###################################################################

open(FH, "<$test_file") or die "Failed to open file $test_file: $!\n";

my $gtest_count = 0;
my %gtest_cases;
my @gtest_fixtures;

while (<FH>)
{
	# delete any space
	s/\s*//g;

	if( $_ =~ /^(TEST|TEST_F)\((.*?),(.*?)\)$/ )
	{
		++$gtest_count;
		$gtest_cases{ $gtest_count } = { index => $2, 
										 test => $3 };
	}
	elsif( $_=~ /^class(.*?):.*?public::testing::Test/ )
	{
		# record fixtures
		push(@gtest_fixtures, $1);
	}
}

##############################################################
# Meta-Program header file
##############################################################

open(OFH, ">$header_output") or die "Failed to open file $header_output: $!\n";

my $header = <<"HEADER";
/**
 * \@file        $output_basename
 * \@author      Auto-generated
 * \@date        $now
 * \@brief       Auto-generated header containing macros to forward declare and/or
 *				befriend all gtest cases in file $test_file_base. Use in conjunction
 *				with gtest_befriend_hook_macros.h 
 */

 #ifndef $uc_basename_header_guard
 #define $uc_basename_header_guard

 #include "gtest/gtest.h"
 #include "gtest_macros.h"

HEADER

print OFH $header;

##############################################################
# Create macros for each test case
##############################################################

foreach my $key( sort { $a <=> $b } keys %gtest_cases )
{
	my $forward_decl;
	my $friend;

	if( $key > 1)
	{
		$forward_decl = join("","#define ", $basename, "_FD", $key, " ", $basename, "_FD", $key-1, 
						  	 " class GTEST_TEST_CLASS_NAME_(", $gtest_cases{$key}->{'index'},", ",
						  	 $gtest_cases{$key}->{'test'},");\n");
		
		$friend = join("","#define ", $basename, "_FR", $key, " ", $basename, "_FR", $key-1, 
					   " friend class GTEST_TEST_CLASS_NAME_(", $gtest_cases{$key}->{'index'},", ",
					   $gtest_cases{$key}->{'test'},");\n");
	}
	else
	{
		$forward_decl = join("","#define ", $basename, "_FD", $key, 
						     " class GTEST_TEST_CLASS_NAME_(", $gtest_cases{$key}->{'index'},", ",
						     $gtest_cases{$key}->{'test'},");\n");
		
		$friend = join("","#define ", $basename, "_FR", $key, 
					   " friend class GTEST_TEST_CLASS_NAME_(", $gtest_cases{$key}->{'index'},", ",
					   $gtest_cases{$key}->{'test'},");\n");
	}

	print OFH $forward_decl;
	print OFH $friend;
}

#################################################################
# Provide forwards declares and friend access for fixtures also
#################################################################

my $gtest_fixture_num = 1;

foreach ( reverse @gtest_fixtures )
{
		my $index = $gtest_count + $gtest_fixture_num;

		print OFH join("","#define ", $basename, "_FD", $index, " ", $basename, "_FD", $index-1, " class $_;\n");
		print OFH join("","#define ", $basename, "_FR", $index, " ", $basename, "_FR", $index-1, " friend class $_;\n");

		++$gtest_fixture_num;
}

print OFH join("","#define ", $basename, "_max ", $gtest_count + scalar(@gtest_fixtures) , "\n");
print OFH join("","#define ", $basename, "_FD", " BOOST_PP_CAT(", $basename, "_FD,$basename","_max)\n");
print OFH join("","#define ", $basename, "_FR", " BOOST_PP_CAT(", $basename, "_FR,$basename","_max)\n", "#endif\n");

#################################################################
# Usage Blurb
#################################################################

sub usage {
    my $msg = shift;

    my $usage = <<"USAGE";
Usage: $0 -f <gtest_file> [-o <output_header>] [--help]

Message: $msg

When passed google test file, generates macros to forward declare and befriend test cases and classes.
Use to probe internal state of classes without breaking encapsulation

Available options:

    -f	gtest file
    -o  output file
    -h  help

Example:

./generate_gtest_befriend_macros.pl -f x_unittest.cpp
USAGE

	print STDERR $usage;
	exit 1;
}

