# /Dockerfile
FROM RPLACE_WITH_FROM_IMAGE

COPY entrypoint.sh /tmp/entrypoint.sh
  # entrypoint.sh 파일을 추가하고

RUN chmod +x /tmp/entrypoint.sh
  # entrypoint.sh 파일에 권한을 주고

ENTRYPOINT ["sh","/tmp/entrypoint.sh"]
# entrypoint.sh 를 수행합니다.