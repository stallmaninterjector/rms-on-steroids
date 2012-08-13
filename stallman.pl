#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#!/usr/bin/perl
#
#       stallman.pl
#
#   Run in a loop, automating the following sequence of actions:
#
#   1.  Scan front page of selected boards, collect list of threads.
#   2.  Scan thread for erroneous usage of "Linux", in the context of
#       describing a complete operating system, as well as the use of words that should be avoided.
#   3.  Interject with random Stallman picture and apt pasta, then sleep.
#   4.  At the end of each sweep, sleep for a few minutes before repeating
#       again, ad nauseum.

use warnings;
use strict;

use LWP::UserAgent;
use HTML::Form;
use Data::Dumper;
use DateTime;
use WWW::Mechanize;
my @threads;
my $output;
my $iteration = 0;
my %boards = ( g => 'boards' );                     # Hash containing boards to sweep.
my $log_file = "$ENV{HOME}/log_interjection";
my @ns_headers = (
    'User-Agent' => 'Mozilla/5.0 (X11; Gentoo; Linux i686; rv:14.0) Gecko/20100101 Firefox/14.0.1',
    'Accept-Charset' => 'iso-8859-1,*,utf-8',
    'Accept-Language' => 'en-US',
    'Referer' => 'https://boards.4chan.org/g/',
);

our $logging_enabled = 1;
our $distro_warn = 1;                               # Warn users about non-freedom respecting distros
our $pic_path = "$ENV{HOME}/rms/";                  # Directory holding delcious Stallman pictures
our $scan_interval = 10;                            # Interval between each sweep of all boards
our $min_post_interval = 30;                        # Minimum delay after each individual interjection
our $post_interval_variation = 5;                   # Upper threshold of random additional delay after interjecting
our $password = int(rand(99999999));                # Generate random password for stallman
our $total_posts = 0;
our @handsome_rms_pics = <$pic_path*>;
our @interjected;                                   # Track posts already responded to.
our $browser = LWP::UserAgent->new;


#pasta list
our $rms_pasta =<<FIN;
I'd just like to interject. What you're referring to as Linux, is in fact, GNU/Linux, or as I've recently taken to calling it, GNU plus Linux. Linux is not an operating system unto itself, but rather another free component of a fully functioning GNU system made useful by the GNU corelibs, shell utilities and vital system components comprising a full OS as defined by POSIX.

Many computer users run a modified version of the GNU system every day, without realizing it. Through a peculiar turn of events, the version of GNU which is widely used today is often called "Linux", and many of its users are not aware that it is basically the GNU system, developed by the GNU Project.

There really is a Linux, and these people are using it, but it is just a part of the system they use. Linux is the kernel: the program in the system that allocates the machine's resources to the other programs that you run. The kernel is an essential part of an operating system, but useless by itself; it can only function in the context of a complete operating system. Linux is normally used in combination with the GNU operating system: the whole system is basically GNU with Linux added, or GNU/Linux. All the so-called "Linux" distributions are really distributions of GNU/Linux.
FIN

our $gnulinux_pasta =<<FIN;
I'd just like to interject. What you're referring to as Linux, is in fact, GNU/Linux, or as I've recently taken to calling it, GNU plus Linux. Linux is not an operating system unto itself, but rather another free component of a fully functioning GNU system made useful by the GNU corelibs, shell utilities and vital system components comprising a full OS as defined by POSIX.

Many computer users run a modified version of the GNU system every day, without realizing it. Through a peculiar turn of events, the version of GNU which is widely used today is often called "Linux", and many of its users are not aware that it is basically the GNU system, developed by the GNU Project.

There really is a Linux, and these people are using it, but it is just a part of the system they use. Linux is the kernel: the program in the system that allocates the machine's resources to the other programs that you run. The kernel is an essential part of an operating system, but useless by itself; it can only function in the context of a complete operating system. Linux is normally used in combination with the GNU operating system: the whole system is basically GNU with Linux added, or GNU/Linux. All the so-called "Linux" distributions are really distributions of GNU/Linux.
FIN

our $bsdstyle_pasta=<<FIN;
The expression "BSD-style license" leads to confusion because it lumps together licenses that have important differences. For instance, the original BSD license with the advertising clause is incompatible with the GNU General Public License, but the revised BSD license is compatible with the GPL.

To avoid confusion, it is best to name the specific license in question and avoid the vague term "BSD-style."
FIN

our $cloudcomp_pasta=<<FIN;
The term "cloud computing" is a marketing buzzword with no clear meaning. It is used for a range of different activities whose only common characteristic is that they use the Internet for something beyond transmitting files. Thus, the term is a nexus of confusion. If you base your thinking on it, your thinking will be vague.

When thinking about or responding to a statement someone else has made using this term, the first step is to clarify the topic. Which kind of activity is the statement really about, and what is a good, clear term for that activity? Once the topic is clear, the discussion can head for a useful conclusion.

Curiously, Larry Ellison, a proprietary software developer, also noted the vacuity of the term "cloud computing." He decided to use the term anyway because, as a proprietary software developer, he isn't motivated by the same ideals as we are.

One of the many meanings of "cloud computing" is storing your data in online services. That exposes you to surveillance.

Another meaning (which overlaps that but is not the same thing) is Software as a Service, which denies you control over your computing.

Another meaning is renting a remote physical server, or virtual server. These can be ok under certain circumstances. 
FIN

our $closed_pasta=<<FIN;
Describing nonfree software as "closed" clearly refers to the term "open source". In the free software movement, we do not want to be confused with the open source camp, so we are careful to avoid saying things that would encourage people to lump us in with them. For instance, we avoid describing nonfree software as "closed". We call it "nonfree" or "proprietary".
FIN

our $commercial_pasta=<<FIN;
Please don't use "commercial" as a synonym for "nonfree." That confuses two entirely different issues.

A program is commercial if it is developed as a business activity. A commercial program can be free or nonfree, depending on its manner of distribution. Likewise, a program developed by a school or an individual can be free or nonfree, depending on its manner of distribution. The two questions--what sort of entity developed the program and what freedom its users have--are independent.

In the first decade of the free software movement, free software packages were almost always noncommercial; the components of the GNU/Linux operating system were developed by individuals or by nonprofit organizations such as the FSF and universities. Later, in the 1990s, free commercial software started to appear.

Free commercial software is a contribution to our community, so we should encourage it. But people who think that "commercial" means "nonfree" will tend to think that the "free commercial" combination is self-contradictory, and dismiss the possibility. Let's be careful not to use the word "commercial" in that way.
FIN

our $consumer_pasta=<<FIN;
The term "consumer," when used to refer to computer users, is loaded with assumptions we should reject. Playing a digital recording, or running a program, does not consume it.

The terms "producer" and "consumer" come from economic theory, and bring with them its narrow perspective and misguided assumptions. These tend to warp your thinking.

In addition, describing the users of software as "consumers" presumes a narrow role for them: it regards them as sheep that passively graze on what others make available to them.

This kind of thinking leads to travesties like the CBDTPA "Consumer Broadband and Digital Television Promotion Act" which would require copying restriction facilities in every digital device. If all the users do is "consume," then why should they mind?

The shallow economic conception of users as "consumers" tends to go hand in hand with the idea that published works are mere "content."

To describe people who are not limited to passive use of works, we suggest terms such as "individuals" and "citizens".
FIN

our $content_pasta=<<FIN;
If you want to describe a feeling of comfort and satisfaction, by all means say you are "content," but using the word as a noun to describe written and other works of authorship adopts an attitude you might rather avoid. It regards these works as a commodity whose purpose is to fill a box and make money. In effect, it disparages the works themselves.

Those who use this term are often the publishers that push for increased copyright power in the name of the authors ("creators," as they say) of the works. The term "content" reveals their real attitude towards these works and their authors. (See Courtney Love's open letter to Steve Case and search for "content provider" in that page. Alas, Ms. Love is unaware that the term "intellectual property" is also biased and confusing.)

However, as long as other people use the term "content provider", political dissidents can well call themselves "malcontent providers".

The term "content management" takes the prize for vacuity. "Content" means "some sort of information," and "management" in this context means "doing something with it." So a "content management system" is a system for doing something to some sort of information. Nearly all programs fit that description.

In most cases, that term really refers to a system for updating pages on a web site. For that, we recommend the term "web site revision system" (WRS).
FIN

our $digital_goods_pasta=<<FIN;
The term "digital goods," as applied to copies of works of authorship, erroneously identifies them with physical goods--which cannot be copied, and which therefore have to be manufactured and sold.
FIN

our $digital_locks_pasta=<<FIN;
"Digital locks" is used to refer to Digital Restrictions Management by some who criticize it. The problem with this term is that it fails to show what's wrong with the practice.

Locks are not necessarily an injustice. You probably own several locks, and their keys or codes as well; you may find them useful or troublesome, but either way they don't oppress you, because you can open and close them.

DRM is like a lock placed on you by someone else, who refuses to give you the key -- in other words, like handcuffs. Therefore, we call them "digital handcuffs", not "digital locks".

A number of campaigns have chosen the unwise term "digital locks"; therefore, to correct the mistake, we must work firmly against it. We may support a campaign that criticizes "digital locks", because we might agree with the substance; but when we do, we always state our rejection of that term and conspicuously say "digital handcuffs" so as to set a better example.
FIN

our $drm_pasta=<<FIN;
"Digital Rights Management" refers to technical schemes designed to impose restrictions on computer users. The use of the word "rights" in this term is propaganda, designed to lead you unawares into seeing the issue from the viewpoint of the few that impose the restrictions, and ignoring that of the general public on whom these restrictions are imposed.

Good alternatives include "Digital Restrictions Management," and "digital handcuffs."
FIN

our $eco_pasta=<<FIN;
It is a mistake to describe the free software community, or any human community, as an "ecosystem," because that word implies the absence of ethical judgment.

The term "ecosystem" implicitly suggests an attitude of nonjudgmental observation: don't ask how what should happen, just study and explain what does happen. In an ecosystem, some organisms consume other organisms. We do not ask whether it is fair for an owl to eat a mouse or for a mouse to eat a plant, we only observe that they do so. Species' populations grow or shrink according to the conditions; this is neither right nor wrong, merely an ecological phenomenon.

By contrast, beings that adopt an ethical stance towards their surroundings can decide to preserve things that, on their own, might vanish--such as civil society, democracy, human rights, peace, public health, clean air and water, endangered species, traditional arts…and computer users' freedom. 
FIN

our $freeware_pasta=<<FIN;
Please don't use the term "freeware" as a synonym for "free software." The term "freeware" was used often in the 1980s for programs released only as executables, with source code not available. Today it has no particular agreed-on definition.

When using languages other than English, please avoid borrowing English terms such as "free software" or "freeware." It is better to translate the term "free software" into your language.

By using a word in your own language, you show that you are really referring to freedom and not just parroting some mysterious foreign marketing concept. The reference to freedom may at first seem strange or disturbing to your compatriots, but once they see that it means exactly what it says, they will really understand what the issue is. 
FIN

our $give_pasta=<<FIN;
It's misleading to use the term "give away" to mean "distribute a program as free software." This locution has the same problem as "for free": it implies the issue is price, not freedom. One way to avoid the confusion is to say "release as free software."
FIN

our $hacker_pasta=<<FIN;
A hacker is someone who enjoys playful cleverness--not necessarily with computers. The programmers in the old MIT free software community of the 60s and 70s referred to themselves as hackers. Around 1980, journalists who discovered the hacker community mistakenly took the term to mean "security breaker."

Please don't spread this mistake. People who break security are "crackers."
FIN

our $ip_pasta=<<FIN;
Publishers and lawyers like to describe copyright as "intellectual property"--a term also applied to patents, trademarks, and other more obscure areas of law. These laws have so little in common, and differ so much, that it is ill-advised to generalize about them. It is best to talk specifically about "copyright," or about "patents," or about "trademarks."

The term "intellectual property" carries a hidden assumption--that the way to think about all these disparate issues is based on an analogy with physical objects, and our conception of them as physical property.

When it comes to copying, this analogy disregards the crucial difference between material objects and information: information can be copied and shared almost effortlessly, while material objects can't be.

To avoid spreading unnecessary bias and confusion, it is best to adopt a firm policy not to speak or even think in terms of "intellectual property".

The hypocrisy of calling these powers "rights" is starting to make the World "Intellectual Property" Organization embarrassed.
FIN

our $lamp_pasta=<<FIN;
"LAMP" stands for "Linux, Apache, MySQL and PHP"--a common combination of software to use on a web server, except that "Linux" in this context really refers to the GNU/Linux system. So instead of "LAMP" it should be "GLAMP": "GNU, Linux, Apache, MySQL and PHP." 
FIN

our $market_pasta=<<FIN;
It is misleading to describe the users of free software, or the software users in general, as a "market."

This is not to say there is no room for markets in the free software community. If you have a free software support business, then you have clients, and you trade with them in a market. As long as you respect their freedom, we wish you success in your market.

But the free software movement is a social movement, not a business, and the success it aims for is not a market success. We are trying to serve the public by giving it freedom--not competing to draw business away from a rival. To equate this campaign for freedom to a business' efforts for mere success is to deny the importance of freedom and legitimize proprietary software.
FIN

our $monetize_pasta=<<FIN;
The natural meaning of "monetize" is "convert into money". If you make something and then convert it into money, that means there is nothing left except money, so nobody but you has gained anything, and you contribute nothing to the world.

By contrast, a productive and ethical business does not convert all of its product into money. Part of it is a contribution to the rest of the world.
FIN

our $mp3_pasta=<<FIN;
In the late 1990s it became feasible to make portable, solid-state digital audio players. Most support the patented MP3 codec, but not all. Some support the patent-free audio codecs Ogg Vorbis and FLAC, and may not even support MP3-encoded files at all, precisely to avoid these patents. To call such players "MP3 players" is not only confusing, it also puts MP3 in an undeserved position of privilege which encourages people to continue using that vulnerable format. We suggest the terms "digital audio player," or simply "audio player" if context permits.
FIN

our $open_pasta=<<FIN;
Please avoid using the term "open" or "open source" as a substitute for "free software". Those terms refer to a different position based on different values. Free software is a political movement; open source is a development model. When referring to the open source position, using its name is appropriate; but please do not use it to label us or our work--that leads people to think we share those views.
FIN

our $pc_pasta=<<FIN;
It's OK to use the abbreviation "PC" to refer to a certain kind of computer hardware, but please don't use it with the implication that the computer is running Microsoft Windows. If you install GNU/Linux on the same computer, it is still a PC.

The term "WC" has been suggested for a computer running Windows.
FIN

our $ps_pasta=<<FIN;
Please avoid using the term "photoshop" as a verb, meaning any kind of photo manipulation or image editing in general. Photoshop is just the name of one particular image editing program, which should be avoided since it is proprietary. There are plenty of free programs for editing images, such as the GIMP.
FIN

our $piracy_pasta=<<FIN;
Publishers often refer to copying they don't approve of as "piracy." In this way, they imply that it is ethically equivalent to attacking ships on the high seas, kidnapping and murdering the people on them. Based on such propaganda, they have procured laws in most of the world to forbid copying in most (or sometimes all) circumstances. (They are still pressuring to make these prohibitions more complete.)

If you don't believe that copying not approved by the publisher is just like kidnapping and murder, you might prefer not to use the word "piracy" to describe it. Neutral terms such as "unauthorized copying" (or "prohibited copying" for the situation where it is illegal) are available for use instead. Some of us might even prefer to use a positive term such as "sharing information with your neighbor."
FIN

our $powerpoint_pasta=<<FIN;
Please avoid using the term "PowerPoint" to mean any kind of slide presentation. "PowerPoint" is just the name of one particular proprietary program to make presentations, and there are plenty of free program for presentations, such as TeX's beamer class and OpenOffice.org's Impress.
FIN

our $protection_pasta=<<FIN;
Publishers' lawyers love to use the term "protection" to describe copyright. This word carries the implication of preventing destruction or suffering; therefore, it encourages people to identify with the owner and publisher who benefit from copyright, rather than with the users who are restricted by it.

It is easy to avoid "protection" and use neutral terms instead. For example, instead of saying, "Copyright protection lasts a very long time," you can say, "Copyright lasts a very long time."

If you want to criticize copyright instead of supporting it, you can use the term "copyright restrictions." Thus, you can say, "Copyright restrictions last a very long time."

The term "protection" is also used to describe malicious features. For instance, "copy protection" is a feature that interferes with copying. From the user's point of view, this is obstruction. So we could call that malicious feature "copy obstruction." More often it is called Digital Restrictions Management (DRM)--see the Defective by Design campaign.
FIN

our $sellsoft_pasta=<<FIN;
The term "sell software" is ambiguous. Strictly speaking, exchanging a copy of a free program for a sum of money is selling; but people usually associate the term "sell" with proprietary restrictions on the subsequent use of the software. You can be more precise, and prevent confusion, by saying either "distributing copies of a program for a fee" or "imposing proprietary restrictions on the use of a program," depending on what you mean.
FIN

our $softwareindustry_pasta=<<FIN;
The term "software industry" encourages people to imagine that software is always developed by a sort of factory and then delivered to "consumers." The free software community shows this is not the case. Software businesses exist, and various businesses develop free and/or nonfree software, but those that develop free software are not run like factories.

The term "industry" is being used as propaganda by advocates of software patents. They call software development "industry" and then try to argue that this means it should be subject to patent monopolies. The European Parliament, rejecting software patents in 2003, voted to define "industry" as "automated production of material goods."
FIN

our $trustedcomp_pasta=<<FIN;
"Trusted computing" is the proponents' name for a scheme to redesign computers so that application developers can trust your computer to obey them instead of you. From their point of view, it is "trusted"; from your point of view, it is "treacherous." 
FIN

our $vendor_pasta=<<FIN;
Please don't use the term "vendor" to refer generally to anyone that develops or packages software. Many programs are developed in order to sell copies, and their developers are therefore their vendors; this even includes some free software packages. However, many programs are developed by volunteers or organizations which do not intend to sell copies. These developers are not vendors. Likewise, only some of the packagers of GNU/Linux distributions are vendors. We recommend the general term "supplier" instead. 
FIN


#distro pasta list


our $arch_pasta=<<FIN;
Arch has the two usual problems: there's no clear policy about what software can be included, and nonfree blobs are shipped with their kernel. Arch also has no policy about not distributing nonfree software through their normal channels.
FIN

our $centos_pasta=<<FIN;
We're not aware of problems in CentOS aside from the two usual ones: there's no clear policy about what software can be included, and nonfree blobs are shipped with the kernel. Of course, with no firm policy in place, there might be other nonfree software included that we missed.
FIN

our $debian_pasta=<<FIN;
Debian's Social Contract states the goal of making Debian entirely free software, and Debian conscientiously keeps nonfree software out of the official Debian system. However, Debian also provides a repository of nonfree software. According to the project, this software is "not part of the Debian system," but the repository is hosted on many of the project's main servers, and people can readily learn about these nonfree packages by browsing Debian's online package database.

There is also a "contrib" repository; its packages are free, but some of them exist to load separately distributed proprietary programs. This too is not thoroughly separated from the main Debian distribution.

Previous releases of Debian included nonfree blobs with the kernel. With the release of Debian 6.0 ("squeeze") in February 2011, these blobs have been moved out of the main distribution to separate packages in the nonfree repository. However, the problem partly remains: the installer in some cases recommends these nonfree firmware files for the peripherals on the machine.
FIN

our $fedora_pasta=<<FIN;
Fedora does have a clear policy about what can be included in the distribution, and it seems to be followed carefully. The policy requires that most software and all fonts be available under a free license, but makes an exception for certain kinds of nonfree firmware. Unfortunately, the decision to allow that firmware in the policy keeps Fedora from meeting the free system distribution guidelines.
FIN


#gentoo is an exception


our $mandriva_pasta=<<FIN;
Mandriva does have a stated policy about what can be included in the main system. It's based on Fedora's, which means that it also allows certain kinds of nonfree firmware to be included. On top of that, it permits software released under the original Artistic License to be included, even though that's a nonfree license.

Mandriva also provides nonfree software through dedicated repositories.
FIN

our $opensuse_pasta=<<FIN;
OpenSUSE offers its users access to a repository of nonfree software. This is an instance of how "open" is weaker than "free".
FIN

our $redhat_pasta=<<FIN;
Red Hat's enterprise distribution primarily follows the same licensing policies as Fedora, with one exception. Thus, we don't endorse it for the same reasons. In addition to those, Red Hat has no policy against making nonfree software available for the system through supplementary distribution channels.
FIN

our $slackware_pasta=<<FIN;
Slackware has the two usual problems: there's no clear policy about what software can be included, and nonfree blobs are included in the kernel. It also ships with the nonfree image-viewing program xv. Of course, with no firm policy in place, there might be other nonfree software included that we missed.
FIN

our $ubuntu_pasta=<<FIN;
Ubuntu provides specific repositories of nonfree software, and Canonical expressly promotes and recommends nonfree software under the Ubuntu name in some of their distribution channels. Ubuntu offers the option to install only free packages, which means it also offers the option to install nonfree packages too. In addition, the version of the kernel, included in Ubuntu contains firmware blobs.

Ubuntu's trademark policy prohibits commercial redistribution of exact copies of Ubuntu, denying an important freedom. 
FIN

our $bsd_pasta=<<FIN;
FreeBSD, NetBSD, and OpenBSD all include instructions for obtaining nonfree programs in their ports system. In addition, their kernels include nonfree firmware blobs.

Nonfree firmware programs used with the kernel, are called "blobs", and that's how we use the term. In BSD parlance, the term "blob" means something else: a nonfree driver. OpenBSD and perhaps other BSD distributions (called "projects" by BSD developers) have the policy of not including those. That is the right policy, as regards drivers; but when the developers say these distributions "contain no blobs", it causes a misunderstanding. They are not talking about firmware blobs.

No BSD distribution has policies against proprietary binary-only firmware that might be loaded even by free drivers.
FIN





open LOGGING, ">", $log_file or die $!;   # Log file location
print LOGGING "...logging to $log_file\n";



&log_msg("### ------------ interjection.pl ------------ ###");
&log_msg("###");
&log_msg("### \$pic_path:\t\t\t$pic_path");
&log_msg("### \$scan_interval:\t\t$scan_interval");
&log_msg("### \$min_post_interval:\t\t$min_post_interval");
&log_msg("### \$post_interval_variation:\t$post_interval_variation");
&log_msg("### \$password:\t$password");
&log_msg("###");
&log_msg("### ----------------------------------------- ###");
&log_msg("Entering main loop...");

while (1) {
    &log_msg("Iteration $iteration");
    for (sort keys %boards) {
#       Aggregate listing of threads on front page of board,
#       pass each thread to &scan_posts to read.

        my ($srvr, $board) = ($boards{$_}, $_);
        my $board_url = "http://boards.4chan.org/$board/0";
        my $page = ($browser->get($board_url, @ns_headers))->content;
        $@ and print STDERR "$!\n";
        push @threads, $page =~ /<div class="thread" id="t(\d+)"/g;
        &scan_posts("http://boards.4chan.org/$board/res/$_") for @threads;
    }

    &log_msg("Ending iteration $iteration. Will resume in $scan_interval seconds.\n");
    sleep($scan_interval);  # long pause between sweeps.
    $iteration++;
}
sub random_string(;$)
{
	my $length = shift || 8;
	my @char = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);

	my $string;
	$string .= $char[rand @char] while ($length--);

	return $string;
}
sub invoke_curl($)
{
	my ($options) = shift;

	my $command = "curl $options --progress-bar -s -S -f ";
	$output = `$command`;
	print "\n";

	return $?;
}
sub scan_posts {
    my $thread_url = shift;
    my %posts;
    my $page = ($browser->get($thread_url, @ns_headers))->content;
#   'name' attribute holds post number, post body is inside blockquote tags.
    %posts = $page =~
        /<blockquote class="postMessage" id="m(\d+)">(.*?)<\/blockquote>/gs;
    for my $no (sort keys %posts) {
        $_ = $posts{$no}; 
        my $match = 0;
#       Strip any remaining tags in post body.
        s/<.*?>.*?<\/.*?>//g;
        s/<.*?>//g;
#       Make it pretty
        s/&quot/"/g;
        s/&gt;/>/g;
        s/&lt;/</g;
        s/&amp;/"/g;
        s/&#44;/,/g;


#Distro warnings take least priority        
        if ( $distro_warn ){
        if (/\sarch\s/i && ! /two usual problems/) {$match = 1;$rms_pasta = $arch_pasta}
        if (/centos/i && ! /two usual ones/) {$match = 1;$rms_pasta = $centos_pasta}
        if (/debian/i && ! /separately distributed proprietary programs/) {$match = 1;$rms_pasta = $debian_pasta}
        if (/fedora/i && ! /allow that firmware in the/) {$match = 1;$rms_pasta = $fedora_pasta}
        if (/mandriva/i && ! /it permits software released/) {$match = 1;$rms_pasta = $mandriva_pasta}
        if (/opensuse/i && ! /offers its users access to a repository/) {$match = 1;$rms_pasta = $opensuse_pasta}
        if (/red hat|rhel/i && ! /enterprise distribution primarily/) {$match = 1;$rms_pasta = $redhat_pasta}
        if (/slackware/i && ! /two usual problems/) {$match = 1;$rms_pasta = $slackware_pasta}
        if (/ubuntu/i && ! /provides specific repositories of nonfree/) {$match = 1;$rms_pasta = $ubuntu_pasta}
        if (/(free|open|net).?bsd/i && ! /all include instructions for obtaining nonfree/) {$match = 1;$rms_pasta = $bsd_pasta}
        }
#GNU/Linux pasta goes last, takes priority over other pastas

        if (/bsd.style/i && ! /advertising clause/) {$match = 1;$rms_pasta = $bsdstyle_pasta}
        if (/cloud computing|the cloud/i && ! /marketing buzzword/) {$match = 1;$rms_pasta = $cloudcomp_pasta}
        if (/closed source/i && ! /lump us in with them/) {$match = 1;$rms_pasta = $closed_pasta}
        if (/commercial/i && ! /nonprofit organizations|Canonical expressly promotes|encourages people to imagine/) {$match = 1;$rms_pasta = $commercial_pasta}
        if (/consumer/i && ! /Digital Television Promotion/) {$match = 1;$rms_pasta = $consumer_pasta}
        if (/content/i && ! /(am|are) content|web site revision system|economic theory/) {$match = 1;$rms_pasta = $content_pasta}
        if (/digital goods/i && ! /erroneously identifies/) {$match = 1;$rms_pasta = $digital_goods_pasta}
        if (/digital locks?/i && ! /digital handcuffs/) {$match = 1;$rms_pasta = $digital_locks_pasta}
        if (/drm|digital rights management/i && ! /lead you unawares/) {$match = 1;$rms_pasta = $drm_pasta}
        if (/ecosystem/i && ! /implicitly suggests an attitude/) {$match = 1;$rms_pasta = $eco_pasta}
        if (/freeware|free.ware/i && ! /often in the 1980s/) {$match = 1;$rms_pasta = $freeware_pasta}
        if (/give away software/i && ! /This locution has/) {$match = 1;$rms_pasta = $give_pasta}
        if (/hacker/i && ! /playful cleverness--not/) {$match = 1;$rms_pasta = $hacker_pasta}
        if (/intellectual property/i && ! /hidden assumption--that|web site revision system/) {$match = 1;$rms_pasta = $ip_pasta}
        if (/lamp/i && ! /glamp/i) {$match = 1;$rms_pasta = $lamp_pasta}
        if (/software market/i && ! /is a social movement/i) {$match = 1;$rms_pasta = $market_pasta}
        if (/monetize/i && ! /a productive and ethical business/) {$match = 1;$rms_pasta = $monetize_pasta}
        if (/mp3 player/i && ! /In the late 1990s/) {$match = 1;$rms_pasta = $mp3_pasta}
        if (/open source/i && ! /Free software is a political movement|lump us in with them/) {$match = 1;$rms_pasta = $open_pasta}
        if (/ pc(\s|\.)/i && ! /been suggested for a computer running Windows/) {$match = 1;$rms_pasta = $pc_pasta}
        if (/photoshopped|shooped|shopped/i && ! /one particular image editing program,/) {$match = 1;$rms_pasta = $ps_pasta}
        if (/\spiracy|pirate/i && ! /sharing information with your neighbor/) {$match = 1;$rms_pasta = $piracy_pasta}
        if (/powerpoint|power point/i && ! /Impress/) {$match = 1;$rms_pasta = $powerpoint_pasta}
        if (/(drm|copyright) protection/i && ! /If you want to criticize copyright/) {$match = 1;$rms_pasta = $protection_pasta}
        if (/sell(ing)? software/i && ! /imposing proprietary restrictions/) {$match = 1;$rms_pasta = $sellsoft_pasta}
        if (/software industry/i && ! /automated production of material goods/) {$match = 1;$rms_pasta = $softwareindustry_pasta}
        if (/trusted computing/i && ! /scheme to redesign computers/) {$match = 1;$rms_pasta = $trustedcomp_pasta}
        if (/vendor/i && ! /recommend the general term/) {$match = 1;$rms_pasta = $vendor_pasta}
        if (/L\s*(i\W*n\W*u\W*|l\W*u\W*n\W*i\W*|o\W*o\W*n\W*i\W*)x(?!\s+kernel)/ix && ! /(GNU|Gah?n(oo|ew))\s*(.|plus|with|and|slash)\s*(L(oo|i|u)n(oo|i|u)(x|cks))/i) {$match = 1;$rms_pasta = $gnulinux_pasta}

            if ( $match ){
            next if grep {$_ == $no} @interjected;

            &log_msg("URL: $thread_url post: $no");
            &log_msg("POST: $_");

            print "Post Number: $no\nPost: $_";
            &interject($thread_url, $no, $page);
            push @interjected, $no;
            $total_posts++;
            &log_msg("Interjection to post $no successful. Freedom delivered! Total posts: $total_posts");
        }
    }
}

sub interject {
#   Prepare pasta, fill form fields, find submit
#   button and click it, then sleep for a semi-
#   random amount of time.
	chomp(my $os = `uname -s`);
    return if (invoke_curl("http://www.google.com/recaptcha/api/challenge?k=6Ldp2bsSAAAAAAJ5uyx_lx34lJeEpTLVkP5k04qc"));
	
	my ($challenge) = $output =~ m/challenge : '([A-z0-9-]+)',/;
	my $outfile = random_string() . ".jpg";
	if ( $os eq "Linux") {return if (invoke_curl("http://www.google.com/recaptcha/api/image?c=$challenge -o /tmp/$outfile"));}
    else { return if (invoke_curl("http://www.google.com/recaptcha/api/image?c=$challenge -o $outfile"));}
	my $vericode;

		if ($os) {
			print "Enter the CAPTCHA here:\n";
			if ($os eq "Darwin") {
				system "qlmanage -p $outfile &> /dev/null &"; # Haven't tested this myself.
			} elsif ($os eq "Linux") {
				system "display /tmp/$outfile &> /dev/null &";
			}
		} else {
			print "Open $outfile to see the CAPTCHA, then enter it here:\n";
		}

		$vericode = <>; # Wait for input

		if ($os) {
			system "pkill -f $outfile"; # Kills the program displaying the image
		}

	# Reset the referrer and delete the image
	if ( $os eq "Linux") {unlink "/tmp/$outfile";}
    else {unlink $outfile;}

    my ($url, $post_no, $page, ) = @_;
    my ($form, $interjection, $submit_button, $pic);
    $interjection = ">>$post_no\n" . $rms_pasta;
    $pic = &select_pic;
    &log_msg("attached pic: $pic");  


    my $mechanize = WWW::Mechanize->new();
    $mechanize->get($url);
    $mechanize->submit_form(
                form_number => 1,
                        fields      => { 
                            com => $interjection,
                            recaptcha_challenge_field => $challenge,
                            recaptcha_response_field => $vericode,
                            upfile => $pic,
                            pwd => $password},
                            );

    if ( $mechanize->status == "403"){print "Banned by Freedom-hating mods ;_;\n"; exit}
    if ( grep /successful/i, $mechanize->content()){print "Freedom Delivered!\n\n"} 
    if ( grep /mistyped/i, $mechanize->content()){print "Mistyped Captcha\n"; &interject($url, $post_no, $page); return} 
    if ( grep /flood/i, $mechanize->content()){print "Flood Detected\n"} 
    if ( grep /duplicate/i, $mechanize->content()){print "Duplicate Image\n"} 

    sleep($min_post_interval + rand($post_interval_variation)); 
}

sub log_msg {
    my $msg = shift;
    exit if ! $logging_enabled;
    my $now = DateTime->now;
    syswrite LOGGING, $now->ymd . " " . $now->hms . ": $msg\n" or die $!;
}

sub select_pic {
#   Select a file from the array and remove its entry.

    log "No more sexy RMS pictures left... ;_;\n" && exit if ! @handsome_rms_pics;
    return splice @handsome_rms_pics, int(rand(@handsome_rms_pics)), 1;
}


