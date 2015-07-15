#!/usr/bin/perl
#Filename��fx_aix.pl
#Author��among	lifeng29@163.com 20120517
#20121126,����interval���ж�
#20130922,�ı�����㷨�ṹ���������ɼ����Ŀ
#20131009,����net��page�ȼ����Ŀ
#20131024,���ӶԶ���εĴ�����������

use warnings;
use strict;
use Getopt::Std;
use vars qw($opt_m $opt_f $opt_d);

getopts('m:f:d:');

unless ($^O eq "aix")
{
	print "�˰汾ֻ֧��aixϵͳ\n";
	exit 1;
}

my $is = 0;	#interval second
unless ($opt_m)
{
	print "���� -m Ϊ��ѡ����\n";
	HelpMsg();
	exit 1;
}
unless ($opt_f)
{
	print "���� -f Ϊ��ѡ����\n";
	HelpMsg();
	exit 1;
}
&checknum($opt_m);
&checknum($opt_d) if ($opt_d);
open AM, "<", $opt_f or die "���ļ� $opt_f ʧ��.\n";

#cpu dic 
my %cpu_dic;
my $cpu_start = 0;
#mem dic 
my %mem_dic1;
my %mem_dic2;
my $mem_start1 = 0;
my $mem_start2 = 0;

#page dic
my %pg_dic;
my $pg_start = 0;

#net dic 
my %net_dic;
my $net_start = 0;

#disk dic 
my %disk_dic1;
my $disk_start1 = 0;
my %disk_dic2;
my $disk_start2 = 0;


while (<AM>)
{
	my $info = $_;
	chomp($info);
	if ($info =~ m/^AAA,interval,(\d+)/)
	{
		$is = $1;
	}
	elsif ($info =~ m/^CPU_ALL/)
	{
		$cpu_dic{$cpu_start} = $info;
		$cpu_start += 1;
	}
	elsif ($info =~ m/^MEM,/)
	{
		$mem_dic1{$mem_start1} = $info;
		$mem_start1 += 1;
	}
	elsif ($info =~ m/^MEMUSE,/)
	{
		$mem_dic2{$mem_start2} = $info;
		$mem_start2 += 1;
	}
	elsif ($info =~ m/^PAGE,/)
	{
		$pg_dic{$pg_start} = $info;
		$pg_start += 1;
	}
	elsif ($info =~ m/^NET,/)
	{
		$net_dic{$net_start} = $info;
		$net_start += 1;
	}
	elsif ($info =~ m/^DISKBUSY,/)
	{
		$disk_dic1{$disk_start1} = $info;
		$disk_start1 += 1;
	}
	elsif ($info =~ m/^DISKXFER,/)
	{
		$disk_dic2{$disk_start2} = $info;
		$disk_start2 += 1;
	}
}
close AM;

##opt_s  10min
#cn��һ���а���������dcnȥ������
my $cn = int($opt_m*60/$is);

my $dcn;
unless ($opt_d)
{
	$dcn = 0;
}
else
{
	$dcn = int($opt_d*60/$is);
}
#print "cn  $cn , $dcn \n";
die "-m ����������� -d ����\n" if ($cn <= $dcn);
######

my $sp = 1;
my $value_ct = 0;
my $cpu_value = 0;
my $mem_value = 0;
my $mem_value1 = 0;
my $pg_value1 = 0;
my $pg_value2 = 0;

my $cpu_res = "CPUʹ����";
my $mem_res ="�����ڴ�ʹ����";
my $mem_vm_res ="�����ڴ�ʹ����";
my $mem_pg_res ="�ڴ�pgoutҳ��";
my $mem_pgs_res ="�ڴ�pgsoutҳ��";

my %net_res;

my %disk_res1;
my %disk_res2;

#net 
my %net_rdic;
my @net_tp = split(/,/, $net_dic{0}) or die "NETδ�ҵ���mail to lifeng29\@163.com  \n";

for (my $i = 2 ; $i <= $#net_tp ; $i++)
{
	my $isn = $i - 1;
	$net_rdic{$isn."_".$net_tp[$i]} = 0;
}
#foreach my $key (sort keys %net_rdic)
#{
#      my $value = $net_rdic{$key};
#      print "$key => $value\n";
#}

#disk
my %disk_rdic1;
my @disk1_tp = split(/,/, $disk_dic1{0}) or die "DISKBUSYδ�ҵ���mail to lifeng29\@163.com  \n";

for (my $i = 2 ; $i <= $#disk1_tp ; $i++)
{
	my $isn = $i - 1;
	$disk_rdic1{$isn."_".$disk1_tp[$i]} = 0;
}

my %disk_rdic2;
my @disk2_tp = split(/,/, $disk_dic2{0}) or die "DISKXFERδ�ҵ���mail to lifeng29\@163.com  \n";

for (my $i = 2 ; $i <= $#disk2_tp ; $i++)
{
	my $isn = $i - 1;
	$disk_rdic2{$isn."_".$disk2_tp[$i]} = 0;
}

##

while (1)
{
	last unless exists $cpu_dic{$sp};
	my $tpp  = $sp%$cn;
	#print "tpp: $cn,$dcn,$tpp ";
	if (($tpp >0) and ($tpp <= $dcn))
	{
		$sp += 1;
		next;
	}
	$value_ct += 1;
	#cpu calc
	my $cpu_info = $cpu_dic{$sp};
	my @cpu_tp = split(/,/, $cpu_info);
	my $cpu = $cpu_tp[2]+$cpu_tp[3];
	$cpu_value += $cpu;
	#mem calc
	my $mem_info1 = $mem_dic1{$sp};
	my $mem_info2 = $mem_dic2{$sp};
	my @mem_tp1 = split(/,/, $mem_info1);
	my @mem_tp2 = split(/,/, $mem_info2);
	my $mem = 100 - $mem_tp1[2] - $mem_tp2[2];
	my $mem1 = 100 - $mem_tp1[3];
	$mem_value += $mem;
	$mem_value1 += $mem1;
	#page calc
	my $page_info = $pg_dic{$sp};
	my @pg_tp = split(/,/, $page_info);
	my $pgout = $pg_tp[4];
	my $pgsout = $pg_tp[6];
	$pg_value1 += $pgout;
	$pg_value2 += $pgsout;
	#net calc
	my $net_info = $net_dic{$sp};
	my @net_tp1 = split(/,/, $net_info);
	for (my $i = 2 ; $i <= $#net_tp1 ; $i++)
	{
		my $isn = $i - 1;
		$net_rdic{$isn."_".$net_tp[$i]} += $net_tp1[$i];
	}
	##
	#disk calc
	my $disk1_info = $disk_dic1{$sp};
	my @disk_tp1 = split(/,/, $disk1_info);
	for (my $i = 2 ; $i <= $#disk_tp1 ; $i++)
	{
		my $isn = $i - 1;
		$disk_rdic1{$isn."_".$disk1_tp[$i]} += $disk_tp1[$i];
	}
	my $disk2_info = $disk_dic2{$sp};
	my @disk_tp2 = split(/,/, $disk2_info);
	for (my $i = 2 ; $i <= $#disk_tp2 ; $i++)
	{
		my $isn = $i - 1;
		$disk_rdic2{$isn."_".$disk2_tp[$i]} += $disk_tp2[$i];
	}
	##
	
	##
	if (($tpp == 0) or !(exists $cpu_dic{($sp+1)}))
	{
		my $amp_cpu = sprintf("%.2f",$cpu_value/$value_ct);
		my $amp_mem = sprintf("%.2f",$mem_value/$value_ct);
		my $amp_mem1 = sprintf("%.2f",$mem_value1/$value_ct);
		my $amp_pg1 = sprintf("%.2f",$pg_value1/$value_ct);
		my $amp_pg2 = sprintf("%.2f",$pg_value2/$value_ct);
		$cpu_res =$cpu_res.",$amp_cpu"."%";
		$mem_res =$mem_res.",$amp_mem"."%";
		$mem_vm_res =$mem_vm_res.",$amp_mem1"."%";
		$mem_pg_res = $mem_pg_res.",$amp_pg1";
		$mem_pgs_res = $mem_pgs_res.",$amp_pg2";
		
		##net
		for (my $i = 2 ; $i <= $#net_tp ; $i++)
		{
			my $isn = $i - 1;
			if (defined($net_res{$net_tp[$i]}))
			{
				$net_res{$net_tp[$i]} =  $net_res{$net_tp[$i]}.",".sprintf("%.2f",$net_rdic{$isn."_".$net_tp[$i]}/$value_ct);
			}
			else
			{
				$net_res{$net_tp[$i]} =  sprintf("%.2f",$net_rdic{$isn."_".$net_tp[$i]}/$value_ct);
			}
			$net_rdic{$isn."_".$net_tp[$i]} = 0;
		}
		##disk
		for (my $i = 2 ; $i <= $#disk_tp1 ; $i++)
		{
			my $isn = $i - 1;
			if (defined($disk_res1{"Disk_Busy_".$disk1_tp[$i]}))
			{
				$disk_res1{"Disk_Busy_".$disk1_tp[$i]} =  $disk_res1{"Disk_Busy_".$disk1_tp[$i]}.",".sprintf("%.2f",$disk_rdic1{$isn."_".$disk1_tp[$i]}/$value_ct);
			}
			else
			{
				$disk_res1{"Disk_Busy_".$disk1_tp[$i]} =  sprintf("%.2f",$disk_rdic1{$isn."_".$disk1_tp[$i]}/$value_ct);
			}
			$disk_rdic1{$isn."_".$disk1_tp[$i]} = 0;
		}
		for (my $i = 2 ; $i <= $#disk_tp2 ; $i++)
		{
			my $isn = $i - 1;
			if (defined($disk_res2{"IO/sec_".$disk2_tp[$i]}))
			{
				$disk_res2{"IO/sec_".$disk2_tp[$i]} =  $disk_res2{"IO/sec_".$disk2_tp[$i]}.",".sprintf("%.2f",$disk_rdic2{$isn."_".$disk2_tp[$i]}/$value_ct);
			}
			else
			{
				$disk_res2{"IO/sec_".$disk2_tp[$i]} =  sprintf("%.2f",$disk_rdic2{$isn."_".$disk2_tp[$i]}/$value_ct);
			}
			$disk_rdic2{$isn."_".$disk2_tp[$i]} = 0;
		}
		##
		$value_ct = 0;
		$cpu_value = 0;
		$mem_value = 0;
		$mem_value1 = 0;
		$amp_pg1 = 0;
		$amp_pg2 = 0;
	}
	$sp +=1 ;
}

print "$cpu_res \n";
print "$mem_res \n";
print "$mem_vm_res \n";
print "$mem_pg_res \n";
print "$mem_pgs_res \n";

foreach my $key (sort keys %net_res)
{
      my $value = $net_res{$key};
      print "$key,$value\n";
}

foreach my $key (sort keys %disk_res1)
{
      my $value = $disk_res1{$key};
      print "$key,$value\n";
}
foreach my $key (sort keys %disk_res2)
{
      my $value = $disk_res2{$key};
      print "$key,$value\n";
}
##sub
sub HelpMsg
{
	print "ʹ�÷�����������AIXϵͳ��ʹ�ü����ڴ�\n";
	print "perl $0 -m 30 -d 2 -f path/to/nmon.nmon\n";
	print " -mָ����ص�ʱ��������λΪ���ӣ�-dָ��ÿ�ֵ�ǰ�����ӱ����ԣ���ʡ�Դ˲���\n";
	print " -f ָ��nmon�ļ���·��\n";
}

sub checknum()
{
	my $tmp = shift;
	unless ($tmp =~ m/^\d+\.?\d*$/)
	{
		print "$tmp ������,�����˳�";
		exit 1;
	}
}