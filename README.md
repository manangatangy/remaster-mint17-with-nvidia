remaster-mint17-with-nvidia
===========================

How to create a live DVD of Linux Mint 17 mate, including the Nvidia drivers.

step 1: remaster.sh unpack ../Downloads/mint-iso-and-nvidia/linuxmint-17-mate-64bit-v2.iso

step 2: remaster.sh modify 340
    while in the chroot shell, nothing much was needed except some checks;
    grep 'nouveau' /etc/modprobe.d/* | grep nvidia

step 3: remaster.sh pack mint-17-mate-64bit-v2-nvidia.iso mint-17-mate-64bit-v2-nvidia

step 4: remaster.sh clean

final step: write to a usb/dvd
    I used USB Image writer (mintstick -m iso).  Brasero will burn your dvd, or
    you can just place a blank disk in the reader and up pops an asker for you.

After the drivers have been installed in the filesystem, you can use:
grep 'nouveau' /etc/modprobe.d/* | grep nvidia
to confirm that the nouveau drivers have been blacklisted.
The 'command dpkg -l | grep nvidia' is also useful.

After the new ppa has been added, you can use:
egrep -v '^#|^ *$' /etc/apt/sources.list /etc/apt/sources.list.d/*
to see how the xorg-edgers are now listed.
It may be a good idea to disable/remove them after the packages have
been installed, since they could be a security risk.  This can be done
with the synaptic package manager but I dont know how to do it on the
command line.  I suspect it's just a matter of commenting out the lines
in /etc/apt/sources.list.d/xorg-edgers-ppa-trusty.list.

Background
----------
This procedure was developed based on: 
http://www.binarytides.com/install-nvidia-drivers-ubuntu-14-04/  and
https://docs.google.com/document/d/1iLR4gp_cxw8UMqfiPoOa7ZabnEDyVT8ku17CYs_hI1A/edit

I tried remastersys and it's derivative black-lab-imager as well as mintconstructor.
All these scripts were not easy to track down, and in the end none of them worked.
So I decided to do it myself. After a lot of trawling over many people's postings,
and lots of trial and error, I determined that the above two references were accurate
in every way. So I kind of munged them together into a script that I was happy to use.

Note that I tried the www.nvidia.com provided script, that you download from their
site and it unpacks and install stuff.  But it just wouldn't work in the chroot.

The second reference has some stuff about customizing the desktop, which I ignored.
From https://plus.google.com/+PeteNavarro/posts/Uh3UNgZgw6E, Pete Navarro says:
"Whatever you put in /etc/skel will be on the home folder of your .iso. So if 
you put some files in ~/livecdtmp/edit/etc/skel/Desktop/goodies You will have 
that folder and it's files on the livecd desktop."
I might change the script to do this.

