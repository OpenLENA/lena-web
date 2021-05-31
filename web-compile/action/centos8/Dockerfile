# /Dockerfile
FROM centos:8

COPY entrypoint.sh /entrypoint.sh
  # entrypoint.sh 파일을 추가하고

RUN chmod +x /entrypoint.sh
  # entrypoint.sh 파일에 권한을 주고

ENTRYPOINT ["/entrypoint.sh"]
# entrypoint.sh 를 수행합니다.