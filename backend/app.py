import hashlib
import logging
import os
import re
import socket

import requests
import yaml
from flask import Flask, Response, jsonify, request, send_from_directory
from flask_cors import CORS
from werkzeug.exceptions import HTTPException

import config
from db import get_conn, init_db

app = Flask(__name__)
CORS(app, origins=os.environ.get("CORS_ORIGINS", "http://localhost:3000").split(","))

logger = logging.getLogger(__name__)

COLUMNS = ("id", "brand", "model", "size", "color", "price", "stock")
SELECT = "SELECT id, brand, model, size, color, price, stock FROM shoes"
HOSTNAME_RE = re.compile(r"^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$")


def row_to_dict(row):
    data = dict(zip(COLUMNS, row))
    data["price"] = float(data["price"])
    return data


def query(sql, params=(), fetch="all"):
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(sql, params)
            if fetch == "all":
                return cur.fetchall()
            if fetch == "one":
                return cur.fetchone()
            return None
    finally:
        conn.close()


@app.errorhandler(Exception)
def handle_error(exc):
    if isinstance(exc, HTTPException):
        return jsonify(error=exc.description), exc.code
    logger.exception("unhandled error")
    return jsonify(error="internal server error"), 500


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/api/shoes", methods=["GET"])
def list_shoes():
    like = f"%{request.args.get('q', '')}%"
    rows = query(f"{SELECT} WHERE stock > 0 AND (brand ILIKE %s OR model ILIKE %s) ORDER BY id", (like, like))
    return jsonify([row_to_dict(r) for r in rows])


@app.route("/api/shoes/<int:id>", methods=["GET"])
def get_shoe(id):
    row = query(f"{SELECT} WHERE id = %s", (id,), "one")
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(row_to_dict(row))


@app.route("/api/shoes", methods=["POST"])
def create_shoe():
    d = request.get_json()
    row = query(
        "INSERT INTO shoes (brand, model, size, color, price, stock) VALUES (%s, %s, %s, %s, %s, %s) "
        "RETURNING id, brand, model, size, color, price, stock",
        (d["brand"], d["model"], d["size"], d["color"], d["price"], d["stock"]),
        "one",
    )
    return jsonify(row_to_dict(row)), 201


@app.route("/api/shoes/<int:id>", methods=["PUT"])
def update_shoe(id):
    d = request.get_json()
    row = query(
        "UPDATE shoes SET brand = %s, model = %s, size = %s, color = %s, price = %s, stock = %s "
        "WHERE id = %s RETURNING id, brand, model, size, color, price, stock",
        (d["brand"], d["model"], d["size"], d["color"], d["price"], d["stock"], id),
        "one",
    )
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(row_to_dict(row))


@app.route("/api/shoes/<int:id>", methods=["DELETE"])
def delete_shoe(id):
    query("DELETE FROM shoes WHERE id = %s", (id,), None)
    return "", 204


@app.route("/api/shoes/import", methods=["POST"])
def import_shoes():
    items = yaml.safe_load(request.data)
    for d in items:
        query(
            "INSERT INTO shoes (brand, model, size, color, price, stock) VALUES (%s, %s, %s, %s, %s, %s)",
            (d["brand"], d["model"], d["size"], d["color"], d["price"], d["stock"]),
            None,
        )
    return jsonify(imported=len(items)), 201


@app.route("/api/export")
def export_file():
    name = request.args.get("file", "shoes.csv")
    return send_from_directory(config.EXPORT_DIR, name, mimetype="text/plain")


@app.route("/api/shoes/<int:id>/checksum")
def checksum(id):
    row = query("SELECT brand, model, size, color, price FROM shoes WHERE id = %s", (id,), "one")
    digest = hashlib.sha256(str(row).encode()).hexdigest()
    return jsonify(id=id, checksum=digest)


@app.route("/api/shoes/<int:id>/label")
def label(id):
    row = query(f"{SELECT} WHERE id = %s", (id,), "one")
    if row is None:
        return jsonify(error="not found"), 404
    s = row_to_dict(row)
    return Response(f"{s['brand']} {s['model']} - {s['size']}", mimetype="text/plain")


@app.route("/api/tools/ping")
def ping():
    host = request.args.get("host", "localhost")
    if not HOSTNAME_RE.match(host):
        return jsonify(error="invalid host"), 400
    try:
        address = socket.gethostbyname(host)
    except socket.gaierror:
        return jsonify(error="host not found"), 404
    return jsonify(output=f"{host} resolves to {address}")


@app.route("/api/catalog")
def catalog():
    page = request.args.get("page", 1, type=int)
    resp = requests.get(
        config.CATALOG_URL,
        params={"page": page},
        headers={"X-Api-Key": config.CATALOG_API_KEY},
        timeout=5,
        allow_redirects=False,
    )
    return resp.text, resp.status_code


if __name__ == "__main__":
    init_db()
    app.run(host=os.environ.get("HOST", "127.0.0.1"), port=5000)
