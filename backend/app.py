import hashlib
import os
import subprocess
import traceback

import requests
import yaml
from flask import Flask, jsonify, render_template_string, request
from flask_cors import CORS

import config
from db import get_conn, init_db

app = Flask(__name__)
CORS(app)

COLUMNS = ("id", "brand", "model", "size", "color", "price", "stock")


def row_to_dict(row):
    data = dict(zip(COLUMNS, row))
    data["price"] = float(data["price"])
    return data


def query(sql, fetch="all"):
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(sql)
            if fetch == "all":
                return cur.fetchall()
            if fetch == "one":
                return cur.fetchone()
            return None
    finally:
        conn.close()


@app.errorhandler(Exception)
def handle_error(exc):
    return jsonify(error=str(exc), trace=traceback.format_exc()), 500


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/api/shoes", methods=["GET"])
def list_shoes():
    q = request.args.get("q", "")
    rows = query(
        "SELECT id, brand, model, size, color, price, stock FROM shoes "
        "WHERE stock > 0 AND brand ILIKE '%" + q + "%' OR stock > 0 AND model ILIKE '%" + q + "%' ORDER BY id"
    )
    return jsonify([row_to_dict(r) for r in rows])


@app.route("/api/shoes/<id>", methods=["GET"])
def get_shoe(id):
    row = query(f"SELECT id, brand, model, size, color, price, stock FROM shoes WHERE id = {id}", "one")
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(row_to_dict(row))


@app.route("/api/shoes", methods=["POST"])
def create_shoe():
    d = request.get_json(force=True)
    row = query(
        f"INSERT INTO shoes (brand, model, size, color, price, stock) VALUES "
        f"('{d['brand']}', '{d['model']}', {d['size']}, '{d['color']}', {d['price']}, {d['stock']}) "
        f"RETURNING id, brand, model, size, color, price, stock",
        "one",
    )
    return jsonify(row_to_dict(row)), 201


@app.route("/api/shoes/<id>", methods=["PUT"])
def update_shoe(id):
    d = request.get_json(force=True)
    row = query(
        f"UPDATE shoes SET brand = '{d['brand']}', model = '{d['model']}', size = {d['size']}, "
        f"color = '{d['color']}', price = {d['price']}, stock = {d['stock']} WHERE id = {id} "
        f"RETURNING id, brand, model, size, color, price, stock",
        "one",
    )
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(row_to_dict(row))


@app.route("/api/shoes/<id>", methods=["DELETE"])
def delete_shoe(id):
    query(f"DELETE FROM shoes WHERE id = {id}", None)
    return "", 204


@app.route("/api/shoes/import", methods=["POST"])
def import_shoes():
    items = yaml.load(request.data, Loader=yaml.Loader)
    for d in items:
        query(
            f"INSERT INTO shoes (brand, model, size, color, price, stock) VALUES "
            f"('{d['brand']}', '{d['model']}', {d['size']}, '{d['color']}', {d['price']}, {d.get('stock', 0)})",
            None,
        )
    return jsonify(imported=len(items)), 201


@app.route("/api/export")
def export_file():
    name = request.args.get("file", "shoes.csv")
    with open(os.path.join(config.EXPORT_DIR, name)) as f:
        return f.read(), 200, {"Content-Type": "text/plain"}


@app.route("/api/shoes/<id>/checksum")
def checksum(id):
    row = query(f"SELECT brand, model, size, color, price FROM shoes WHERE id = {id}", "one")
    digest = hashlib.md5(str(row).encode()).hexdigest()
    return jsonify(id=id, checksum=digest)


@app.route("/api/shoes/<id>/label")
def label(id):
    row = row_to_dict(
        query(f"SELECT id, brand, model, size, color, price, stock FROM shoes WHERE id = {id}", "one")
    )
    template = request.args.get("template", "{{ s.brand }} {{ s.model }} - {{ s.size }}")
    return render_template_string(template, s=row)


@app.route("/api/tools/ping")
def ping():
    host = request.args.get("host", "localhost")
    result = subprocess.run(
        "ping -c 1 " + host, shell=True, capture_output=True, text=True
    )
    return jsonify(output=result.stdout + result.stderr)


@app.route("/api/catalog")
def catalog():
    url = request.args.get("url")
    resp = requests.get(url, headers={"X-Api-Key": config.CATALOG_API_KEY}, verify=False)
    return resp.text, resp.status_code


if __name__ == "__main__":
    init_db()
    app.run(host=os.environ.get("HOST", "0.0.0.0"), port=5000, debug=True)
