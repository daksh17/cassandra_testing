FROM  ubuntu
LABEL maintainer="Dash" 
RUN apt-get update && apt-get install -y python3 
RUN mkdir /app
WORKDIR /app
COPY *.py .
ENTRYPOINT ["python3"]
CMD ["test.py"]
