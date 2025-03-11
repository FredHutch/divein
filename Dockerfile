# Use an official Perl image as the base image
FROM perl:5.28

# Set environment variable to non-interactive mode for apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Install Apache and mod_cgi for running Perl CGI scripts
RUN apt-get update && apt-get install -y \
    apache2 \
    libapache2-mod-perl2 \
    libperl-dev \
    build-essential \
    cpanminus \
    wget \
    gnupg \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    cmake \
    mafft \
    && rm -rf /var/lib/apt/lists/*

RUN cpanm CGI Sort::Fields

# Apache config to make sure the PERL5LIB variable is respected
COPY 000-default.conf /etc/apache2/sites-available/000-default.conf

# Enable CGI module for Apache
RUN a2enmod cgi
RUN a2enmod perl

# Add the R repository and install R 3.6
RUN echo 'deb https://cloud.r-project.org/bin/linux/debian buster-cran35/' >> /etc/apt/sources.list && \
    #apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B8F25A8A73EACF41 && \
    apt-get update && \
    apt-get install -y r-base=3.6* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# install tidyverse
RUN R -e "install.packages('optparse')"
RUN R -e "install.packages('BiocManager')"
RUN R -e "BiocManager::install('Biostrings')"
RUN R -e "install.packages('ape')"
RUN R -e "install.packages('remotes')"
RUN R -e "remotes::install_version('cpp11', version = '0.4.2')"
RUN R -e "remotes::install_version('purrr', version = '0.3.2')"
RUN R -e "remotes::install_version('gtable', version = '0.3.0')"
RUN R -e "remotes::install_version('tidyr', version = '1.0.0')"
RUN R -e "remotes::install_version('dplyr', version = '1.0.0')"
RUN R -e "remotes::install_version('broom', version = '0.5.2')"
RUN R -e "remotes::install_version('dbplyr', version = '1.4.2')"
RUN R -e "remotes::install_version('haven', version = '2.1.1')"
RUN R -e "remotes::install_version('lubridate', version = '1.7.4')"
RUN R -e "remotes::install_version('modelr', version = '0.1.5')"
RUN R -e "remotes::install_version('readr', version = '1.3.1')"
RUN R -e "remotes::install_version('readxl', version = '1.3.1')"
RUN R -e "remotes::install_version('igraph', version = '1.2.4.2')"
RUN R -e "remotes::install_version('tidyverse', version = '1.3.0')"

# install tn93
RUN git clone --branch v1.0.6 --single-branch https://github.com/veg/tn93.git
WORKDIR /tn93
RUN cmake .
RUN make install
WORKDIR /

# copy HIVNetworkClustering
COPY ./Rlib /usr/local/lib/R/site-library

# Install OpenJDK 11 (Java)
RUN apt-get update && \
    apt-get install -y openjdk-11-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify installations
RUN perl -v && java -version

RUN cpanm Email::Simple Email::Sender::Simple Email::Sender::Transport::SMTP

# Install gnuplot and cron
RUN apt-get update && \
    apt-get install -y gnuplot \
    cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy the Perl CGI script into the Apache document root
COPY ./cgi-bin /usr/lib/cgi-bin

# Set the permissions for the cgi-bin directory
RUN chmod +x /usr/lib/cgi-bin/*

# Set the document root to the Apache default folder
COPY ./www /var/www/html

COPY ./bin /usr/local/bin

# Copy precompiled BioPerl module into the container
COPY ./BioPerl /usr/local/lib/perl5/site_perl/5.28.3

# copy crontab file into the container
COPY crontab /etc/cron.d/crontab

# set permissions for the crontab file
RUN chmod 0644 /etc/cron.d/crontab

# Apply cron job
RUN crontab /etc/cron.d/crontab

# Set permissions for outputs and stat 
RUN chmod -R 777 /var/www/html/outputs
RUN chmod -R 777 /var/www/html/stats
RUN chmod -R 777 /var/www/html/treeImages

# Expose port 80 to allow web traffic
EXPOSE 80

# Start Apache in the foreground
CMD service cron start && apache2ctl -D FOREGROUND
