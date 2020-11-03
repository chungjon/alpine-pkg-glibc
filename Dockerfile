FROM alpine:3.12

ENV LANG=C.UTF-8

ENV APP_HOME /alpine-pkg-glibc
RUN mkdir $APP_HOME

# install GNU libc (aka glibc) and set C.UTF-8 locale as default.
COPY APKBUILD glibc-bin.trigger ld.so.conf nsswitch.conf $APP_HOME/
RUN ALPINE_GLIBC_PACKAGE_VERSION="2.32-r0" && \
    ALPINE_GLIBC_PACKAGE_FOLDER="/root/packages/x86_64" && \
    ALPINE_GLIBC_BASE_PACKAGE_FILENAME="$ALPINE_GLIBC_PACKAGE_FOLDER/glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_BIN_PACKAGE_FILENAME="$ALPINE_GLIBC_PACKAGE_FOLDER/glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_I18N_PACKAGE_FILENAME="$ALPINE_GLIBC_PACKAGE_FOLDER/glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    GCC_LIBS_URL="https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-10.1.0-2-x86_64.pkg.tar.zst" && \
    GCC_LIBS_SHA256="f80320a03ff73e82271064e4f684cd58d7dbdb07aa06a2c4eea8e0f3c507c45c" && \
    XZLIB_URL="https://archive.archlinux.org/packages/x/xz/xz-5.2.5-1-x86_64.pkg.tar.zst" && \
    XZLIB_SHA256="28b115269402c0e4a43a67866f57c256b47b9da515ac69a68625d6bf5635d585" && \
    ZLIB_URL="https://archive.archlinux.org/packages/z/zlib/zlib-1%3A1.2.11-3-x86_64.pkg.tar.xz" && \
    ZLIB_SHA256="17aede0b9f8baa789c5aa3f358fbf8c68a5f1228c5e6cba1a5dd34102ef4d4e5" && \
# build apks
    apk add --no-cache --virtual .build-dependencies alpine-sdk && \
    cd /alpine-pkg-glibc && \
    abuild-keygen -a -i -n && \
    abuild -F checksum && \
    abuild -r -F && \
    apk del --purge .build-dependencies && \
# install apks
    apk add --no-cache --virtual .build-dependencies binutils curl zstd && \
    apk add --no-cache --allow-untrusted \
        "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true && \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
    mv /usr/glibc-compat/lib/ld-linux-x86-64.so.2 /usr/glibc-compat/lib/ld-linux-x86-64.so && \
    ln -s /usr/glibc-compat/lib/ld-linux-x86-64.so /usr/glibc-compat/lib/ld-linux-x86-64.so.2 && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib && \
    \
    rm \
        "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    \
    rm -rf "$ALPINE_GLIBC_PACKAGE_FOLDER" && \
    \
# download gcc-libs
    curl -LfsS ${GCC_LIBS_URL} -o /tmp/gcc-libs.tar.zst && \
    echo "${GCC_LIBS_SHA256} */tmp/gcc-libs.tar.zst" | sha256sum -c - && \
    mkdir /tmp/gcc && \
    zstd -d /tmp/gcc-libs.tar.zst --output-dir-flat /tmp && \
    tar -xf /tmp/gcc-libs.tar -C /tmp/gcc && \
    mv /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* /usr/glibc-compat/lib && \
    strip /usr/glibc-compat/lib/libgcc_s.so.* /usr/glibc-compat/lib/libstdc++.so* && \
    \
# do not download xz for compression
    curl -LfsS ${XZLIB_URL} -o /tmp/libxz.tar.zst && \
    echo "${XZLIB_SHA256} */tmp/libxz.tar.zst" | sha256sum -c - && \
    mkdir /tmp/libxz && \
    zstd -d /tmp/libxz.tar.zst --output-dir-flat /tmp && \
    tar -xf /tmp/libxz.tar -C /tmp/libxz && \
    mv /tmp/libxz/usr/lib/liblzma.so* /usr/glibc-compat/lib && \
    \
# do not download zlib for compression - not required
#    curl -LfsS ${ZLIB_URL} -o /tmp/libz.tar.xz && \
#    echo "${ZLIB_SHA256} */tmp/libz.tar.xz" | sha256sum -c - && \
#    mkdir /tmp/libz && \
#    tar -xf /tmp/libz.tar.xz -C /tmp/libz && \
#    mv /tmp/libz/usr/lib/libz.so* /usr/glibc-compat/lib && \
    \
    apk del --purge .build-dependencies glibc-i18n && \
    rm -rf /tmp/*.apk /tmp/gcc /tmp/gcc-libs.tar* /tmp/libxz /tmp/libxz.tar* /tmp/libz /tmp/libz.tar.xz /var/cache/apk/* && \
    \
    echo "Build complete"

WORKDIR $APP_HOME

CMD tail -f /dev/null
