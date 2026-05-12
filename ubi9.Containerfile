# syntax=docker/dockerfile:1.2
FROM redhat/ubi9-minimal:9.7 AS builder

ARG TARGETARCH
ARG GRAALVM_VERSION=25.0.3

RUN microdnf install -y tar gzip

RUN mkdir -p /opt/java && \
    if [ "$TARGETARCH" = "arm64" ]; then ARCH="aarch64"; else ARCH="x64"; fi && \
    curl -L https://download.oracle.com/graalvm/25/archive/graalvm-jdk-${GRAALVM_VERSION}_linux-${ARCH}_bin.tar.gz | tar -xz -C /opt/java --strip-components=1

RUN rm -rf /opt/java/bin/native-image \
           /opt/java/bin/gu \
           /opt/java/lib/svm \
           /opt/java/lib/src.zip \
           /opt/java/lib/static-libs \
           /opt/java/include \
           /opt/java/man \
           /opt/java/jmods

RUN microdnf install -y libstdc++ zlib gettext shadow-utils audit-libs libcap-ng pam libselinux libsemanage pcre2 libmount bzip2-libs
RUN mkdir -p /mnt/rootfs/usr/lib64 /mnt/rootfs/usr/bin /mnt/rootfs/usr/sbin /mnt/rootfs/etc && \
    cp -a /usr/lib64/libstdc++.so.6* /usr/lib64/libz.so.1* /usr/lib64/libgcc_s.so.1* /usr/lib64/libaudit.so.1* /usr/lib64/libcap-ng.so.0* /usr/lib64/libpam.so.0* /usr/lib64/libselinux.so.1* /usr/lib64/libsemanage.so.2* /usr/lib64/libpcre2-8.so.0* /usr/lib64/libmount.so.1* /usr/lib64/libblkid.so.1* /usr/lib64/libbz2.so.1* -t /mnt/rootfs/usr/lib64/ && \
    cp -a /usr/sbin/useradd /usr/sbin/groupadd -t /mnt/rootfs/usr/sbin/ && \
    cp -a /etc/passwd /etc/group /etc/shadow /etc/login.defs -t /mnt/rootfs/etc/

FROM redhat/ubi9-micro:9.7

ENV JAVA_HOME=/opt/java
ENV PATH=$JAVA_HOME/bin:$PATH

COPY --from=builder /mnt/rootfs /
COPY --from=builder /opt/java /opt/java