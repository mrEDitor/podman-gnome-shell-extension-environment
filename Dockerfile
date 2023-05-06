# Fedora version (e.g. 32, 33, ...) can be passed using --build-arg=fedora_version=...
ARG fedora_version=latest
FROM registry.fedoraproject.org/fedora:${fedora_version}

# Copy system configuration.
COPY etc /etc
COPY usr /usr

# Install required packages, enable Xvfb via systemd on display :99.
# Add the gnomeshell user with no password.
# Unmask and nodejs:16 are required on Fedora 32.
# TODO: build-only, test-only variants
RUN source /etc/os-release &&\
    dnf update -y &&\
    if test $ID -eq 32; then dnf module enable -y nodejs:16; fi &&\
    dnf --nodocs install -y xorg-x11-server-Xvfb tigervnc-server gtk4-devel sudo \
        gnome-session-xsession gnome-extensions-app gnome-terminal \
        ImageMagick xdotool xautomation git yarn &&\
    systemctl unmask systemd-logind.service console-getty.service getty.target &&\
    systemctl enable xvfb@:99.service &&\
    systemctl set-default multi-user.target &&\
    systemctl --global disable dbus-broker &&\
    systemctl --global enable dbus-daemon &&\
    dnf clean all -y &&\
    rm -rf /var/cache/dnf &&\
    adduser -mUG users,adm,wheel gnomeshell &&\
    echo "gnomeshell     ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Add the scripts.
COPY bin /usr/local/bin

CMD [ "/usr/sbin/init", "systemd.unified_cgroup_hierarchy=0" ]
