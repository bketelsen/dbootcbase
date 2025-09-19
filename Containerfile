FROM docker.io/library/debian:unstable

ARG DEBIAN_FRONTEND=noninteractive
# Antipattern but we are doing this since `apt`/`debootstrap` does not allow chroot installation on unprivileged podman builds
ENV DEV_DEPS="dracut"

RUN rm /etc/apt/apt.conf.d/docker-gzip-indexes /etc/apt/apt.conf.d/docker-no-languages && \
    apt update -y && \
    apt install -y $DEV_DEPS ostree ca-certificates

COPY noahm.sources /etc/apt/sources.list.d
COPY noahm.gpg /etc/apt
RUN apt-get update && apt-get -y install bootc coreos-bootupd

ENV DRACUT_NO_XATTR=1
RUN apt install -y \
  btrfs-progs \
  dosfstools \
  e2fsprogs \
  fdisk \
  firmware-linux-free \
  linux-image-generic \
  skopeo \
  systemd \
  systemd-boot* \
  xfsprogs

RUN sh -c 'export KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION"  "/usr/lib/modules/$KERNEL_VERSION/initramfs.img" && \
    cp /boot/vmlinuz-$KERNEL_VERSION "/usr/lib/modules/$KERNEL_VERSION/vmlinuz"'

# Update useradd default to /var/home instead of /home for User Creation
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd"

# Setup a temporary root passwd (changeme) for dev purposes
# TODO: Replace this for a more robust option when in prod
RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

RUN apt remove -y $DEV_DEPS && \
    apt autoremove -y
ENV DEV_DEPS=



COPY files/usr/lib/tmpfiles.d/bootc.conf /usr/lib/tmpfiles.d/bootc.conf


# Necessary for `bootc install`
COPY files/ostree/prepare-root.conf /usr/lib/ostree/prepare-root.conf

