#!/usr/bin/perl
#Filename：fx_linux.pl
#Author：among	lifeng29@163.com 20120517
#20121126,增加interval的判断
#20130922,改变程序算法结构，增加若干监控项目
#20131009,增加net，page等监控项目
#20131024,增加对多余段的处理，计算更灵活
#内存使用率计算公式为：(总内存-空闲内存-cached-buffers)*100/总内存

use warnings;
use strict;
use Getopt::Std;
use vars qw($opt_m $opt_f $opt_d);

getopts('m:f:d:');

unless ($^O eq "linux")
{
	print "此版本只支持linux系统\n";
	exit 1;
}

my $is = 0;	#interval second
unless ($opt_m)
{
	print "参数 -m 为必选参数.\n";
	HelpMsg();
	exit 1;
}
unless ($opt_f)
{
	print "参数 -f 为必选参数.\n";
	HelpMsg();
	exit 1;
}
&checknum($opt_m);
&checknum($opt_d) if ($opt_d);
open AM, "<", $opt_f or die "打开文件 $opt_f 失败.\n";

#cpu dic 
my %cpu_dic;
my $cpu_start = 0;
#mem dic 
my %mem_dic1;
my %mem_dic2;
my $mem_start1 = 0;
my $mem_start2 = 0;

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
	elsif ($info =~ m/^VM,/)
	{
		$mem_dic2{$mem_start2} = $info;
		$mem_start2 += 1;
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
#cn：一段中包含的量，dcn去除的量
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
die "-m 参数必须大于 -d 参数\n" if ($cn <= $dcn);
######

my $sp = 1;
my $value_ct = 0;
my $cpu_value = 0;
my $mem_value = 0;
my $mem_value1 = 0;
my $mem_value2 = 0;
my $mem_value3 = 0;

my $cpu_res = "CPU使用率";
my $mem_res ="内存使用率";
my $mem_sw_res ="Swap使用率";
my $mem_po_res ="内存PageOut页数";
my $mem_so_res ="内存SwapOut页数";

my %net_res;

my %disk_res1;
my %disk_res2;

#net 
my %net_rdic;
my @net_tp = split(/,/, $net_dic{0}) or die "NET未找到，mail to lifeng29\@163.com  \n";

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
my @disk1_tp = split(/,/, $disk_dic1{0}) or die "DISKBUSY未找到，mail to lifeng29\@163.com  \n";

for (my $i = 2 ; $i <= $#disk1_tp ; $i++)
{
	my $isn = $i - 1;
	$disk_rdic1{$isn."_".$disk1_tp[$i]} = 0;
}

my %disk_rdic2;
my @disk2_tp = split(/,/, $disk_dic2{0}) or die "DISKXFER未找到，mail to lifeng29\@163.com  \n";

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
	my $mem = sprintf("%.2f",($mem_tp1[2]-$mem_tp1[6]-$mem_tp1[11]-$mem_tp1[14])*100/$mem_tp1[2]);	#内存使用率
	my $mem1 =  sprintf("%.2f",($mem_tp1[5]-$mem_tp1[9])*100/$mem_tp1[5]);	#swap使用率
	my $mem2 =  $mem_tp2[9];		#pgpgout
	my $mem3 =  $mem_tp2[11];	#pswpout
	$mem_value += $mem;
	$mem_value1 += $mem1;
	$mem_value2+= $mem2;
	$mem_value3 += $mem3;
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
	#
	
	##
	if (($tpp == 0) or !(exists $cpu_dic{($sp+1)}))
	{
		my $amp_cpu = sprintf("%.2f",$cpu_value/$value_ct);
		my $amp_mem = sprintf("%.2f",$mem_value/$value_ct);
		my $amp_mem1 = sprintf("%.2f",$mem_value1/$value_ct);
		my $amp_mem2 = sprintf("%.2f",$mem_value2/$value_ct);
		my $amp_mem3 = sprintf("%.2f",$mem_value3/$value_ct);
		
		$cpu_res =$cpu_res.",$amp_cpu"."%";
		$mem_res =$mem_res.",$amp_mem"."%";
		$mem_sw_res =$mem_sw_res.",$amp_mem1"."%";
		
		$mem_po_res =$mem_po_res.",$amp_mem2";
		$mem_so_res =$mem_so_res.",$amp_mem3";
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
		$mem_value2 = 0;
		$mem_value3 = 0;
	}
	$sp +=1 ;
}

print "$cpu_res \n";
print "$mem_res \n";
print "$mem_sw_res \n";
print "$mem_po_res \n";
print "$mem_so_res \n";

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
	print "使用方法，适用于Linux系统\n";
	print "perl $0 -m 30 -d 2 -f path/to/nmon.nmon\n";
	print " -m指定监控的时间间隔，单位为分钟，-d指定每轮次前几分钟被忽略，可省略此参数\n";
	print " -f 指定nmon文件的路径\n";
}

sub checknum()
{
	my $tmp = shift;
	unless ($tmp =~ m/^\d+\.?\d*$/)
	{
		print "$tmp 非数字,程序退出";
		exit 1;
	}
}