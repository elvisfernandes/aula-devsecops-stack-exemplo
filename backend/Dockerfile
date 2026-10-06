FROM python:3.11.4

WORKDIR /app
ADD . /app
RUN pip install -r requirements.txt

EXPOSE 5000 22
CMD ["python", "app.py"]
