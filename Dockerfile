FROM centos:buildlfs
VOLUME /mnt/lfs:/mnt/lfs
ENV LFS /mnt/lfs
ENV LC_ALL POSIX
ENV LFS_TGT $(uname -m)-lfs-linux-gnu
ENV PATH /tools/bin:/bin:/usr/bin
COPY wget-list /wget-list

    

ENTRYPOINT sleep 999999999
