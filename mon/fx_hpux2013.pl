#!/usr/bin/perl
#Filename：fx_hpux.pl for hpux platform
#Author：among	lifeng29@163.com 20121127
#20130815，增加对adv文件的自动生成
#20131010，改变算法结构
#20131024，修复bug，计算更灵活
#20140505，修复time计算bug
#20140730，修复2位年份格式的错误

use warnings;
use strict;
use Time::Local;
use Getopt::Std;
use vars qw($opt_m $opt_f $opt_d $opt_p);

getopts('m:f:d:p:');

unless ($^O eq "hpux")
{
	print "此版本只支持hpux系统\n";
	exit 1;
}

my %adv = (
	"01_cpu使用率" => "GBL_CPU_TOTAL_UTIL",
	"02_物理内存" => "GBL_MEM_PHYS",
	"03_sys内存" => "GBL_MEM_SYS",
	"04_user内存" => "GBL_MEM_USER",
	"05_cache内存" => "GBL_MEM_CACHE",
	"06_free内存" => "GBL_MEM_FREE",
	"07_mem_po" => "GBL_MEM_PAGEOUT",
	"08_mem_queue" => "GBL_MEM_QUEUE",
	"09_mem_so" => "GBL_MEM_SWAPOUT",
	"10_swap_util" => "GBL_SWAP_SPACE_UTIL",
	"11_swap保留空间" => "GBL_SWAP_SPACE_RESERVED",
	"12_disk_queue" => "GBL_DISK_QUEUE",
	"13_disk_util" => "GBL_DISK_UTIL",
	"14_network_allpk" => "GBL_NET_PACKET",
	"15_network_perpk" => "GBL_NET_PACKET_RATE",
	#"16_system_io" => BYDSK_SYSTEM_IO,
	#"17_test" => TBL_SHMEM_AVAIL,
);

my $advfile = qq(GBL_STATDATE,"_",GBL_STATTIME);

foreach my $key (sort keys %adv)
{
	my $value =$adv{$key};
	$advfile = $advfile.'," ",'.$value;
}

if ($opt_p)
{
	open ADV, ">$opt_p";
	print ADV "print $advfile\n";
	close ADV;
	print "写入文件$opt_p成功\n";
	print "监控使用方法：nohup glance -bootup -adviser_only -syntax $opt_p -iterations 360 >mon_mix_20u_30m_201307081428_IPP.mon \& \n";
	exit 0;
}

##start
unless ($opt_m)
{
	print "参数 -m 为必选参数\n";
	HelpMsg();
	exit 1;
}
unless ($opt_f)
{
	print "参数 -f 为必选参数\n";
	HelpMsg();
	exit 1;
}
&checknum($opt_m);
&checknum($opt_d) if ($opt_d);
open AM, "<", $opt_f or die "打开文件 $opt_f 失败\n";

my %dic = ();

while (<AM>)
{
	my $info = $_;
	chomp($info);
	next unless ($info =~m /^\d+/);
	my @tpinfo = split(/\s+/, $info);
	my $tm = $tpinfo[0];
	$tm = &chtm($tm);
	$dic{$tm} = $info;
}
close AM;

#cn：一段中开始的时间，dcn去除的时间
my $cn = $opt_m*60;
my $dcn;
unless ($opt_d)
{
	$dcn = 0;
}
else
{
	$dcn = $opt_d*60;
}
#print "cn  $cn , $dcn \n";
die "-m 参数必须大于 -d 参数\n" if ($cn <= $dcn);
#exit 1;

my $sttime;	#开始时间
my $dt_ct = 0;	#序列索引
my $res_ct = 1;	#结果索引
my $value_ct = 0;

my $cpu_value = 0;
my $mem_value1 = 0;
my $mem_value2 = 0;
my $mem_value3 = 0;
my $mem_value4 = 0;
my $sw_value = 0;
my $disk_value1 = 0;
my $disk_value2 = 0;
my $net_value = 0;

my $cpu_res = "CPU使用率";
my $mem_res ="内存使用率";
my $mem_qres = "MEM_QUEUE";
my $mem_po_res ="MEM_PAGEOUT";
my $mem_so_res ="MEM_SWAPOUT";
my $sw_res ="SWAP_SPACE_UTIL";
my $disk_qres ="DISK_QUEUE";
my $disk_ures = "DISK_UTIL";
my $net_rres = "NET_PACKET_RATE";

##
my @dtgp = sort keys %dic;
foreach my $dt (@dtgp)
{
	$sttime = $dt unless defined($sttime);
	my $tpc = ($dt-$sttime)%$cn;
	$dt_ct +=1 ,next if (($dcn >0) and ($tpc < $dcn));
	my @dtv = split(/\s+/, $dic{$dt});
	##value start
	$value_ct += 1;
	$cpu_value += $dtv[1];
	my $allmem = &chmb($dtv[2]);
	my $sysmem = &chmb($dtv[3]);
	my $usermem = &chmb($dtv[4]);
	$mem_value1 += ($sysmem+$usermem)/$allmem;
	$mem_value2 += $dtv[8];
	$mem_value3 += $dtv[7];
	$mem_value4+= $dtv[9];
	$sw_value += $dtv[10];
	$disk_value1 += $dtv[12];
	$disk_value2 += $dtv[13];
	$net_value += $dtv[15];
	
	#last unless defined($dtgp[$dt_ct+1]);
	my $pgtime = $sttime + $res_ct*$cn;
	#print "pg time : $dt , $pgtime , $dtgp[$dt_ct] , $dtgp[$dt_ct+1]  \n";
	if (!(defined($dtgp[$dt_ct+1])) or (($dtgp[$dt_ct] < $pgtime) and ($dtgp[$dt_ct+1] >= $pgtime)))
	{
		my $amp_cpu = sprintf("%.2f",$cpu_value/$value_ct);
		$cpu_res =$cpu_res.",$amp_cpu"."%";
     	#mem
     	my $amp_mem1 = sprintf("%.2f",($mem_value1/$value_ct)*100);
     	$mem_res =$mem_res.",$amp_mem1"."%";
     	#MEM_QUEUE
     	my $amp_mem2 = sprintf("%.2f",$mem_value2/$value_ct);
     	$mem_qres =$mem_qres.",$amp_mem2";
     	#mem pgout
     	my $amp_mem3 = sprintf("%.2f",$mem_value3/$value_ct);
     	$mem_po_res =$mem_po_res.",$amp_mem3";
     	#mem swap out
     	my $amp_mem4 = sprintf("%.2f",$mem_value4/$value_ct);
     	$mem_so_res =$mem_so_res.",$amp_mem4";
     	#sw_res 
     	my $amp_sw = sprintf("%.2f",$sw_value/$value_ct);
     	$sw_res =$sw_res.",$amp_sw"."%";
		#disk qres
     	my $amp_disk1 = sprintf("%.2f",$disk_value1/$value_ct);
     	$disk_qres =$disk_qres.",$amp_disk1";
		#disk_ures
     	my $amp_disk2 = sprintf("%.2f",$disk_value2/$value_ct);
     	$disk_ures =$disk_ures.",$amp_disk2"."%";
		#net res
     	my $amp_net = sprintf("%.2f",$net_value/$value_ct);
     	$net_rres =$net_rres.",$amp_net";
     	
     	$cpu_value = 0;
     	$mem_value1 = 0;
     	$mem_value2 = 0;
     	$mem_value3 = 0;
     	$mem_value4 = 0;
		$sw_value = 0;
		$disk_value1 = 0;
		$disk_value2 = 0;
		$net_value = 0;
     	
     	##all
     	$res_ct += 1;
     	$value_ct = 0;
      }
	$dt_ct += 1;	##next index
      #print "$dt  ,@dtv\n";
}

print "$cpu_res \n";
print "$mem_res \n";
print "$mem_qres \n";
print "$mem_po_res \n";
print "$mem_so_res \n";
print "$sw_res \n";
print "$disk_qres \n";
print "$disk_ures \n";
print "$net_rres \n";

##sub

sub HelpMsg
{
	print "使用方法：适用于hpux系统\n";
	print "首先使用  perl $0 -p advfilename.adv \n";
	print "此命令生成glance参数文件，advfilename.adv 为生成的文件名\n";
	print "监控说明：确保安装有glance，glance可执行，系统默认5s一次监控，iterations指监控次数 \n";
	print "监控使用方法：nohup glance -bootup -adviser_only -syntax hp.adv -iterations 360 >filename.mon \& \n";
	print "分析方法：perl $0 -m 30 -d 2 -f path/to/filename.mon\n";
	print " -m指定监控的时间间隔，单位为分钟，-d指定每轮的前几分钟被忽略，可省略此参数， -f 指定mon文件的路径 \n";
}

sub chmb
{
	my $tp = shift;
	my $rt = 0;
	if ($tp =~ m/(\S+)mb$/)
	{
		my $va = $1;
		$rt = $va/1024;
	}
	elsif ($tp =~ m/(\S+)gb$/)
	{
		$rt = $1;
	}
	else
	{
		print "error , help ,mail to lifeng29\@163.com  \n";
		exit 1;
	}
	return $rt;
}

sub checknum()
{
	my $tmp = shift;
	unless ($tmp =~ m/^\d+\.?\d*$/)
	{
		print "$tmp 非数字,程序退出";
		print "error , help ,mail to lifeng29\@163.com  \n";
		exit 1;
	}
}

sub chtm()
{
	my $tmp = shift;
	my $tmstr = "";
	if ($tmp =~ m/(\d{2})\/(\d{2})\/(\d+)\_(\d{2})\:(\d{2})\:(\d{2})/)
	{
		if (length($3) == 4)
		{
			$tmstr = timelocal($6,$5,$4,$2,$1-1,$3-1900);
		}
		else
		{
			$tmstr = timelocal($6,$5,$4,$2,$1-1,$3+2000-1900);
		}
	}
	else
	{
		print "data error： $tmp \n";
		exit 1;
	}
	return $tmstr;
}

