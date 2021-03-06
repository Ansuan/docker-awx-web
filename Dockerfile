FROM centos:7

# Do we need this?
#RUN locale-gen en_US.UTF-8
#ENV LANG en_US.UTF-8
#ENV LANGUAGE en_US:en
#ENV LC_ALL en_US.UTF-8

USER root

# Init System
ADD https://github.com/krallin/tini/releases/download/v0.14.0/tini /tini
RUN chmod +x /tini

ADD files/Makefile /tmp/Makefile
RUN mkdir /tmp/requirements
ADD requirements/requirements_ansible.txt \
    requirements/requirements_ansible_uninstall.txt \
    requirements/requirements_ansible_git.txt \
    requirements/requirements.txt \
    requirements/requirements_tower_uninstall.txt \
    requirements/requirements_git.txt \
    /tmp/requirements/
ADD files/ansible.repo /etc/yum.repos.d/ansible.repo
ADD files/config-watcher /usr/bin/config-watcher
ADD files/RPM-GPG-KEY-ansible-release /etc/pki/rpm-gpg/RPM-GPG-KEY-ansible-release
# OS Dependencies
WORKDIR /tmp
RUN mkdir -p /var/lib/awx/public/static
RUN chgrp -Rf root /var/lib/awx && chmod -Rf g+w /var/lib/awx
RUN yum -y install epel-release && \
    yum -y localinstall https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm && \
    yum -y update && \
    yum -y install ansible git mercurial subversion curl python-psycopg2 python-pip python-setuptools openssl libselinux-python setools-libs yum-utils sudo acl make postgresql-devel nginx python-psutil libxml2-devel libxslt-devel libstdc++.so.6 gcc cyrus-sasl-devel cyrus-sasl openldap-devel libffi-devel python-pip xmlsec1-devel swig krb5-devel xmlsec1-openssl xmlsec1 xmlsec1-openssl-devel libtool-ltdl-devel bubblewrap gcc-c++ python-devel python36-setuptools python36-devel krb5-workstation krb5-libs libcurl-devel rsync unzip && \
    ln -s /usr/bin/python36 /usr/bin/python3 && \
    python36 -m ensurepip && \
    pip3 install virtualenv && \
    pip install virtualenv supervisor && \
    CFLAGS="-DXMLSEC_NO_SIZE_T" \
    VENV_BASE=/var/lib/awx/venv make requirements_ansible && \
    VENV_BASE=/var/lib/awx/venv make requirements_awx && \
    yum -y remove gcc postgresql-devel libxml2-devel libxslt-devel cyrus-sasl-devel openldap-devel xmlsec1-devel krb5-devel xmlsec1-openssl-devel libtool-ltdl-devel gcc-c++ python-devel python36-devel && \
    yum -y clean all && \
    rm -rf /root/.cache

RUN mkdir -p /var/log/tower
RUN chmod -R g+w /var/log/tower
RUN mkdir -p /etc/tower
COPY files/awx-4.0.0.tar.gz /tmp/awx-4.0.0.tar.gz
RUN OFFICIAL=yes /var/lib/awx/venv/awx/bin/pip install /tmp/awx-4.0.0.tar.gz
RUN ln -s /var/lib/awx/venv/awx/bin/awx-manage /usr/bin/awx-manage
RUN rm -rf /tmp/*

RUN echo "4.0.0" > /var/lib/awx/.tower_version
ADD files/nginx.conf /etc/nginx/nginx.conf
ADD files/supervisor.conf /supervisor.conf
ADD files/supervisor_task.conf /supervisor_task.conf
ADD files/launch_awx.sh /usr/bin/launch_awx.sh
ADD files/launch_awx_task.sh /usr/bin/launch_awx_task.sh
RUN chmod +rx /usr/bin/launch_awx.sh && chmod +rx /usr/bin/launch_awx_task.sh && chmod +rx /usr/bin/config-watcher
ADD files/settings.py /etc/tower/settings.py
RUN chmod g+w /etc/passwd
RUN chmod -R 777 /var/log/nginx && chmod -R 777 /var/lib/nginx
VOLUME /var/lib/nginx
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/awxweb.key -out /etc/nginx/ssl/awxweb.crt
USER 1000
EXPOSE 8052
WORKDIR /var/lib/awx
ENTRYPOINT ["/tini", "--"]
CMD /usr/bin/launch_awx.sh
