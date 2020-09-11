

# 6.4. Entering the Chroot Environment
# by root user
chroot "$LFS" /bin/env -i \
	HOME=/root \
	TERM="$TERM" \
	PS1='\u:\w\$ ' \
	PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
	/bin/bash --login +h

