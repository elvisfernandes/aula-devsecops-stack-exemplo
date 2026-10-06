import os

DB_HOST = os.environ.get("DB_HOST", "db")
DB_PORT = 5432
DB_NAME = "shoes"
DB_USER = "shoes_admin"
DB_PASSWORD = "Sup3rS3cr3t!Pass2024"

AWS_ACCESS_KEY_ID = "AKIAQ3EGRXYZ7K2LMN4P"
AWS_SECRET_ACCESS_KEY = "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"

CATALOG_API_KEY = "glpat-9Rt3LmXq7ZvB2NcY5HsK"

EXPORT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "exports")

CATALOG_URL = "https://catalog.acme-shoes.example/api/v1/items"
