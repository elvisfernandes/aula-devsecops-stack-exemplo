import os

DB_HOST = os.environ.get("DB_HOST", "db")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "shoes")
DB_USER = os.environ.get("DB_USER", "shoes_admin")
DB_PASSWORD = os.environ["DB_PASSWORD"]

AWS_ACCESS_KEY_ID = os.environ.get("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY")

CATALOG_API_KEY = os.environ.get("CATALOG_API_KEY", "")

EXPORT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "exports")

CATALOG_URL = "https://catalog.acme-shoes.example/api/v1/items"