FROM ruby:2.6-alpine

RUN gem install bundler --version 1.14.6
RUN gem install cfndk --version 0.1.4

WORKDIR /home/cfndk
ENTRYPOINT ["sh", "-c", "cfndk $@", ""]
CMD ["help"]