FROM mcr.microsoft.com/mssql/server:2019-latest

USER root

COPY .entrypoint.sh .

EXPOSE 1433
EXPOSE 5022

CMD /bin/bash ./entrypoint.sh