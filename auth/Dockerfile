FROM python:3.13-slim

WORKDIR /app

COPY auth.py .
RUN pip install flask

EXPOSE 5000

CMD ["python", "auth.py"] 