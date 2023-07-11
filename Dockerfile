# This Dockerfile is used to build an headles vnc image based on Debian

FROM debian:12-slim

LABEL io.k8s.description="Headless VNC Container with Xfce window manager, chromium" \
      io.k8s.display-name="Headless VNC Container based on Debian"

## Connection ports for controlling the UI:
# VNC port:5901
# noVNC webport, connect via http://IP:6901/?password=vncpassword
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT

### Envrionment config
ENV HOME=/headless \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/headless/install \
    NO_VNC_HOME=/headless/noVNC \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x1024 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false \
    VNC_PASSWORDLESS=true
WORKDIR $HOME

############### Installations ##################

RUN apt-get update
### Install some common tools
RUN apt-get install -y vim wget net-tools locales bzip2 procps apt-utils && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

### Install custom fonts
RUN apt-get install -y ttf-wqy-zenhei fonts-freefont-ttf

### Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN apt-get install -y tigervnc-standalone-server && \
    printf '\n# docker-headless-vnc-container:\n$localhost = "no";\n1;\n' >> /etc/tigervnc/vncserver-config-defaults
RUN mkdir -p $NO_VNC_HOME/utils/websockify && \
    wget -qO- https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME && \
    wget -qO- https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME/utils/websockify && \
    ln -s $NO_VNC_HOME/vnc_lite.html $NO_VNC_HOME/index.html

### Install chrome browser
RUN apt-get install -y chromium && \
    ln -sfn /usr/bin/chromium /usr/bin/chromium-browser

### Install xfce UI
RUN apt-get install -y supervisor xfce4 xfce4-terminal xterm dbus-x11 libdbus-glib-1-2 && \
    apt-get purge -y pm-utils *screensaver*
ADD ./src/common/xfce/ $HOME/


############### configure startup ##################
RUN echo "Install nss-wrapper to be able to execute image as non-root user"
RUN apt-get install -y libnss-wrapper gettext && \
    echo 'source $STARTUPDIR/generate_container_user' >> $HOME/.bashrc

ADD ./src/common/install/set_user_permission.sh $INST_SCRIPTS/
ADD ./src/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME

RUN apt-get clean -y
RUN rm -rf /var/lib/apt/lists/*

USER 1000

ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]
