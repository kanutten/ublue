#Main arguments
ARG SOURCE_IMAGE="silverblue"
ARG SOURCE_SUFFIX="-main"
ARG SOURCE_TAG="40"
ARG FEDORA_MAJOR_VERSION=40

# Import main packages
FROM ghcr.io/ublue-os/fsync-kernel:${FEDORA_MAJOR_VERSION}
FROM ghcr.io/ublue-os/akmods-nvidia:fsync-${FEDORA_MAJOR_VERSION}
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}${SOURCE_SUFFIX}:${SOURCE_TAG}

COPY rootfs/ /

# Setup copr repos
RUN curl -Lo /usr/bin/copr https://raw.githubusercontent.com/ublue-os/COPR-command/main/copr && \
    chmod +x /usr/bin/copr && \
    curl -Lo /etc/yum.repos.d/_copr_fiftydinar-gnome-randr-rust.repo https://copr.fedorainfracloud.org/coprs/fiftydinar/gnome-randr-rust/repo/fedora-"${FEDORA_MAJOR_VERSION}"/fiftydinar-gnome-randr-rust-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    ostree container commit

# Install kernel-fsync
COPY --from=fsync-kernel /tmp/rpms /tmp/fsync-rpms
RUN rpm-ostree cliwrap install-to-root / && \
    rpm-ostree override replace \
    --experimental \
        /tmp/fsync-rpms/kernel-[0-9]*.rpm \
        /tmp/fsync-rpms/kernel-headers-*.rpm \
        /tmp/fsync-rpms/kernel-core-*.rpm \
        /tmp/fsync-rpms/kernel-modules-*.rpm \
        /tmp/fsync-rpms/kernel-uki-virt-*.rpm && \
    ostree container commit

# Install nvidia driver
COPY --from=akmods-nvidia /rpms /tmp/akmods-rpms
RUN curl -Lo /tmp/nvidia-install.sh https://raw.githubusercontent.com/ublue-os/hwe/main/nvidia-install.sh && \
    chmod +x /tmp/nvidia-install.sh && \
    FEDORA_MAJOR_VERSION=40 IMAGE_NAME="${SOURCE_IMAGE}${SOURCE_SUFFIX}" /tmp/nvidia-install.sh && \
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json && \
    ostree container commit

# Post install work
COPY build.sh /tmp/build.sh
RUN tmp/build.sh && \
    mkdir -p /var/lib/alternatives && \
    ostree container commit

# Enable custom themes/extensions
RUN systemctl enable dconf-update.service

# Add extra packages
RUN rpm-ostree install \
    gnome-randr-rust \
    neofetch \
    grub-customizer \
    logiops \
    gnome-tweaks \
    distrobox \
    yt-dlp && \
    ostree container commit
RUN systemctl enable logid.service
