FROM gnunzi/kuradev-linux:latest AS kura_repo

LABEL maintainer="Giorgio Nunzi"

ARG PACKED=false

ENV \
    GIT_REPO=${GIT_REPO:-https://github.com/eclipse/kura.git} \
    GIT_BRANCH=${GIT_BRANCH:-release-5.2.0}
RUN echo Getting Kura from Branch ${GIT_BRANCH} && \
    git clone "$GIT_REPO" -b "$GIT_BRANCH" && \
    apk del git

FROM kura_repo
ENV \
    JAVA_HOME=/usr/lib/jvm/default-jvm \
    MAVEN_PROPS=-DskipTests \
    MAVEN_PROPS_DEPENDENCIES=-Dmaven.compiler.failOnError=false \
    KURA_DIR=/opt/eclipse/kura \
    LAUNCHER_VERSION="1.5.800.v20200727-1323" 
# Build platform first
RUN cd /kura/target-platform && mvn -B dependency:resolve -Pno-mirror $MAVEN_PROPS_DEPENDENCIES
RUN cd /kura/target-platform && \
    mvn -B -f pom.xml clean install -Pno-mirror $MAVEN_PROPS
RUN cd /kura && \
    `# Replace broken 'nn' script` \
    cp kura/distrib/src/main/sh/extract.sh kura/distrib/src/main/sh/extract_nn.sh
#Compile
RUN cd /kura/kura && mvn -B clean install $MAVEN_PROPS
RUN cd /kura/kura/distrib && mvn -B clean install $MAVEN_PROPS -Pintel-up2-ubuntu-20-nn -nsu
#Install
RUN /kura/kura/distrib/target/kura_*_intel-up2-ubuntu-20-nn_installer.sh
COPY bin /usr/local/bin
RUN  `# Test for the existence of the entry point` \
    test -x "${KURA_DIR}/bin/start_kura.sh" && \
    install -m 0777 -d "${KURA_DIR}/data" && \
    ln -s /bin/bash /usr/bin/bash && \
    chmod a+rw -R /opt/eclipse && \
    find /opt/eclipse -type d | xargs chmod a+x && \
    chmod a+rwx /var/log && \
    chmod a+x /usr/local/bin/*
RUN mkdir -p ${KURA_DIR}/packages && \
    PATH=$PATH":/usr/lib/jvm/java-1.8-openjdk/bin" && \
    sed -i "s/\-printf \'\%P.n\'//g" /usr/local/bin/dp-install && \
    dp-install "https://repo1.maven.org/maven2/de/dentrassi/kura/addons/de.dentrassi.kura.addons.utils.fileinstall/0.6.0/de.dentrassi.kura.addons.utils.fileinstall-0.6.0.dp" && \
    add-config-ini "felix.fileinstall.disableNio2=true" && \
    add-config-ini "felix.fileinstall.dir=/load"
COPY kura-debug-entrypoint /usr/local/bin
RUN chmod a+x /usr/local/bin/kura-debug-entrypoint

EXPOSE 443

VOLUME ["/load"]

ENTRYPOINT ["/usr/local/bin/kura-debug-entrypoint"]
