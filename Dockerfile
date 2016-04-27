############################################################
# Dockerfile to build RTIR containers
# Based on Ubuntu
############################################################

# Set the base image to Ubuntu
FROM ubuntu:14.04

# File Author / Maintainer
MAINTAINER Dustin Lee

################## BEGIN INSTALLATION ######################

# Need to run mysql without prompt for password
RUN apt-get -qq update && export DEBIAN_FRONTEND=noninteractive && apt-get install -qq \
 mysql-server mysql-client libmysqlclient-dev wget git

RUN apt-get install -qq make apache2 libapache2-mod-fcgid libssl-dev libyaml-perl \
 libgd-dev libgd-gd2-perl libgraphviz-perl supervisor

# Add stuff
RUN wget https://download.bestpractical.com/pub/rt/release/rt-4.2.12.tar.gz && \
 wget https://download.bestpractical.com/pub/rt/release/RT-IR-3.2.0.tar.gz && \
 git clone https://github.com/dlee35/docker-rtir.git

RUN tar xzf rt-4.2.12.tar.gz && \
 tar xzf RT-IR-3.2.0.tar.gz

WORKDIR /rt-4.2.12

RUN ./configure --enable-graphviz --enable-gd

RUN (echo yes;echo yes;echo o conf prerequisites_policy 'follow';echo o conf \
 build_requires_install_policy yes;echo o conf commit)|cpan

# I was asked a y/N question during fixdeps... need to auto accept
RUN echo N | make fixdeps && make testdeps

RUN make install && \
 service mysql start && \
 make initialize-database

# Need to adjust all configuration files to support what I'm trying to do
# Followed this blog:
# http://binarynature.blogspot.com/2013/10/install-request-tracker-4-on-ubuntu-server.html

# Need to add install notes from here:
# https://www.bestpractical.com/docs/rtir/3.2/README.html

WORKDIR /opt/rt4/etc

RUN sed -i 's/RestrictReferrer\,\ 1/RestrictReferrer\,\ 0/' RT_Config.pm && \
mv /docker-rtir/RT_SiteConfig.pm RT_SiteConfig.pm && \
mv /docker-rtir/rt.conf /etc/apache2/sites-available/rt.conf && \
mv /docker-rtir/supervisor.conf /etc/supervisor/conf.d/supervisor.conf

RUN a2enmod ssl fcgid && \
 a2ensite rt && \
 apachectl configtest 

WORKDIR /RT-IR-3.2.0

RUN service mysql start && \
 perl Makefile.PL && \
 make install && \
 echo | make initdb &&\
 rm -rf /rt-4.2.12 /RT-IR-3.2.0

EXPOSE 443

CMD ["/usr/bin/supervisord"]
