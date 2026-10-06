import time

import psycopg2

import config


def get_conn():
    return psycopg2.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        dbname=config.DB_NAME,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
    )


def init_db(retries=30):
    for _ in range(retries):
        try:
            conn = get_conn()
            break
        except psycopg2.OperationalError:
            time.sleep(2)
    else:
        raise RuntimeError("database unavailable")

    with conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS shoes (
                id SERIAL PRIMARY KEY,
                brand VARCHAR(80) NOT NULL,
                model VARCHAR(120) NOT NULL,
                size INTEGER NOT NULL,
                color VARCHAR(40) NOT NULL,
                price NUMERIC(10, 2) NOT NULL
            )
            """
        )
        cur.execute("SELECT COUNT(*) FROM shoes")
        if cur.fetchone()[0] == 0:
            cur.execute(
                """
                INSERT INTO shoes (brand, model, size, color, price) VALUES
                ('Nike', 'Air Max 90', 42, 'Branco', 799.90),
                ('Adidas', 'Ultraboost', 40, 'Preto', 999.90),
                ('Puma', 'Suede Classic', 41, 'Azul', 449.90)
                """
            )
    conn.close()
