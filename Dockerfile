FROM gnunzi/kura-linux:latest AS kura_repo

LABEL maintainer="Giorgio Nunzi"

ARG PACKED=false

ENV \
    GIT_REPO=${GIT_REPO:-https://github.com/eclipse/kura.git} \
    GIT_BRANCH=${GIT_BRANCH:-release-5.2.0}
RUN echo Getting Kura from Branch ${GIT_BRANCH} && \
    git clone "$GIT_REPO" -b "$GIT_BRANCH";

FROM kura_repo
ENV \
    JAVA_HOME=/usr/lib/jvm/default-jvm \
    MAVEN_PROPS=-DskipTests \
    MAVEN_PROPS_DEPENDENCIES=-Dmaven.compiler.failOnError=false \
    KURA_DIR=/opt/eclipse/kura \
    LAUNCHER_VERSION="1.5.800.v20200727-1323" 
# Build platform first
RUN cd /kura/target-platform && mvn clean dependency:resolve -Pno-mirror $MAVEN_PROPS_DEPENDENCIES
RUN cd /kura/target-platform && \
    mvn -B -f pom.xml install -Pno-mirror $MAVEN_PROPS
RUN cd /kura && \
    `# Replace broken 'nn' script` \
    cp kura/distrib/src/main/sh/extract.sh kura/distrib/src/main/sh/extract_nn.sh
#Download dependencies
RUN cd /kura/kura && mvn clean dependency:resolve $MAVEN_PROPS_DEPENDENCIES&& \
    cd /kura/kura/distrib && mvn clean dependency:resolve -Pintel-up2-ubuntu-20-nn $MAVEN_PROPS_DEPENDENCIES
#Compile single bundles
RUN cd /kura/kura/org.eclipse.kura.web2 && mvn -B install $MAVEN_PROPS 
RUN cd /kura/kura/org.eclipse.kura.web2.ext && mvn -B install $MAVEN_PROPS
RUN cd /kura/kura/org.eclipse.kura.api && mvn -B install $MAVEN_PROPS
RUN cd /kura/kura/org.eclipse.kura.core && mvn -B install $MAVEN_PROPS
#Compille all together
RUN cd /kura/kura && mvn -B install $MAVEN_PROPS
RUN cd /kura/kura/distrib && mvn -B install $MAVEN_PROPS -Pintel-up2-ubuntu-20-nn -nsu
#Install
RUN /kura/kura/distrib/target/kura_*_intel-up2-ubuntu-20-nn_installer.sh
RUN  apk del maven git && \
    chmod a+rw -R /opt/eclipse && \
    find /opt/eclipse -type d | xargs chmod a+x && \
    chmod a+rwx /var/log && \
    chmod a+x /usr/local/bin/*
RUN  `# Test for the existence of the entry point` \
    test -x "${KURA_DIR}/bin/start_kura.sh" && \
    \
    cp -av /context/bin/* /usr/local/bin && \
    cd / && \
    rm -Rf /context && \
    install -m 0777 -d "${KURA_DIR}/data" && \
    ln -s /bin/bash /usr/bin/bash && \
    mkdir -p ${KURA_DIR}/packages && \
    PATH=$PATH":/usr/lib/jvm/java-1.8-openjdk/bin" && \
    sed -i "s/\-printf \'\%P.n\'//g" /usr/local/bin/dp-install && \
    dp-install "https://repo1.maven.org/maven2/de/dentrassi/kura/addons/de.dentrassi.kura.addons.utils.fileinstall/0.6.0/de.dentrassi.kura.addons.utils.fileinstall-0.6.0.dp" && \
    add-config-ini "felix.fileinstall.disableNio2=true" && \
    add-config-ini "felix.fileinstall.dir=/load"

EXPOSE 443

VOLUME ["/load"]

ENTRYPOINT ["/usr/local/bin/kura-entry-point"]
