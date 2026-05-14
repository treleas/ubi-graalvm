# syntax=docker/dockerfile:1.2
FROM redhat/ubi10-minimal:10.1 AS builder

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

RUN microdnf install -y bash findutils gettext shadow-utils audit-libs zlib libxcrypt
RUN mkdir -p /mnt/rootfs/usr/lib64 /mnt/rootfs/usr/bin /mnt/rootfs/usr/sbin /mnt/rootfs/etc /mnt/rootfs/bin && \
    cp -a /usr/bin/bash /usr/bin/sh /usr/bin/envsubst /usr/bin/find -t /mnt/rootfs/usr/bin/ && \
    cp -a /usr/sbin/useradd /usr/sbin/groupadd -t /mnt/rootfs/usr/sbin/ && \
    for bin in /mnt/rootfs/usr/bin/* /mnt/rootfs/usr/sbin/*; do \
        ldd "$bin" | grep -o '/usr/lib64/[^ ]*' | xargs -I {} cp -a {} /mnt/rootfs/usr/lib64/ 2>/dev/null || true; \
        ldd "$bin" | grep -o '/lib64/[^ ]*' | xargs -I {} cp -a {} /mnt/rootfs/usr/lib64/ 2>/dev/null || true; \
    done && \
    cp -a /usr/lib64/libaudit.so.1* /usr/lib64/libz.so.1* /usr/lib64/libbz2.so.1* /usr/lib64/libcrypt.so.2* -t /mnt/rootfs/usr/lib64/ && \
    ln -s /usr/bin/sh /mnt/rootfs/bin/sh && \
    ln -s /usr/bin/bash /mnt/rootfs/bin/bash && \
    cp -a /etc/passwd /etc/group /etc/shadow /etc/login.defs -t /mnt/rootfs/etc/

FROM redhat/ubi10-micro:10.1

ENV JAVA_HOME=/opt/java
ENV PATH=$JAVA_HOME/bin:$PATH

COPY --from=builder /mnt/rootfs/bin/ /bin/
COPY --from=builder /mnt/rootfs/etc/ /etc/
COPY --from=builder /mnt/rootfs/usr/ /usr/

COPY --from=builder /opt/java /opt/java