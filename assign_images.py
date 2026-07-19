"""
assign_images.py — Asigna imágenes a los productos que no tienen una.
Fuente principal: Wikipedia API (upload.wikimedia.org thumbnails).
Fallback: placehold.co con color por categoría.
Uso: python assign_images.py
"""
import sqlite3, os, uuid, time, requests

DB_PATH    = "instance/app.db"
UPLOAD_DIR = os.path.join("app", "static", "uploads")

WIKI_API = "https://en.wikipedia.org/w/api.php"

WIKI_API_HEADERS = {
    "User-Agent": "VentaIA/1.0 (educational project) python-requests/2.x",
}

WIKI_DOWNLOAD_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "image/jpeg,image/png,image/webp,image/*,*/*",
    "Referer": "https://en.wikipedia.org/",
    "Accept-Language": "en-US,en;q=0.9",
}

# Color por categoría para placehold.co (bg/text)
CATEGORY_COLORS = {
    "Snacks":       ("4CAF50", "ffffff"),
    "Dulces":       ("E91E63", "ffffff"),
    "Alimentos":    ("FF9800", "ffffff"),
    "Bebidas":      ("2196F3", "ffffff"),
    "Sabritas":     ("F44336", "ffffff"),
    "Helados":      ("00BCD4", "ffffff"),
    "Energéticas":  ("8BC34A", "ffffff"),
    "Energeticas":  ("8BC34A", "ffffff"),
    "Jugos":        ("FF6F00", "ffffff"),
    "Café":         ("795548", "ffffff"),
    "Cafe":         ("795548", "ffffff"),
    "Lácteos":      ("90CAF9", "333333"),
    "Lacteos":      ("90CAF9", "333333"),
}

# Mapeo: fragmento normalizado del nombre de producto → artículo Wikipedia
WIKI_MAP = {
    "papas fritas":          "Potato chip",
    "chocolate":             "Chocolate bar",
    "sandwich":              "Sandwich",
    "jugo de naranja":       "Orange juice",
    "galletas":              "Cookie",
    "sabritas sal":          "Frito-Lay",
    "sabritas limon":        "Frito-Lay",
    "cheetos flamin":        "Cheetos",
    "cheetos torciditos":    "Cheetos",
    "ruffles":               "Ruffles (snack)",
    "doritos nacho":         "Doritos",
    "doritos flamin":        "Doritos",
    "takis":                 "Takis (snack)",
    "fritos sal":            "Fritos",
    "pringles":              "Pringles",
    "magnum classic":        "Magnum (ice cream)",
    "magnum almendras":      "Magnum (ice cream)",
    "cornetto":              "Cornetto (ice cream)",
    "pinguino":              "Grupo Bimbo",
    "bimbo":                 "Grupo Bimbo",
    "diablito":              "Paletería",
    "bon ice":               "Paleta (food)",
    "helado bon":            "Paleta (food)",
    "pepsi":                 "Pepsi",
    "sprite":                "Sprite (drink)",
    "fanta":                 "Fanta",
    "mirinda":               "Mirinda",
    "coca-cola 2l":          "Coca-Cola",
    "coca-cola sin":         "Coca-Cola Zero Sugar",
    "agua ciel":             "Ciel (water)",
    "gatorade limon":        "Gatorade",
    "gatorade naranja":      "Gatorade",
    "powerade":              "Powerade",
    "electrolit":            "Electrolit",
    "red bull":              "Red Bull",
    "monster energy":        "Monster Energy",
    "boost":                 "Boost (drink)",
    "vive 100":              "Vive 100",
    "del valle":             "Del Valle (drink)",
    "jumex":                 "Jumex",
    "florida natural":       "Florida's Natural",
    "v8 vegetal":            "V8 (beverage)",
    "frappe nescafe":        "Nescafé",
    "frapp":                 "Nescafé",
    "nescafe":               "Nescafé",
    "lipton":                "Lipton",
    "nestea":                "Nestea",
    "leche lala":            "Lala (company)",
    "yakult":                "Yakult",
    "yoplait":               "Yoplait",
}


def normalize(text):
    import unicodedata
    n = unicodedata.normalize("NFD", text.lower())
    return "".join(c for c in n if unicodedata.category(c) != "Mn")


def wiki_article_for(product_name):
    n = normalize(product_name)
    for key, article in WIKI_MAP.items():
        if key in n:
            return article
    return None


def get_wiki_image_url(article, retries=3):
    """Return a Wikimedia thumbnail URL for the given article title."""
    for attempt in range(retries):
        try:
            r = requests.get(WIKI_API, params={
                "action": "query",
                "titles": article,
                "prop": "pageimages",
                "pithumbsize": 400,
                "format": "json",
                "redirects": 1,
            }, headers=WIKI_API_HEADERS, timeout=15)
            if r.status_code == 429:
                wait = 3 * (attempt + 1)
                print(f"  [rate limit API, espera {wait}s] ", end="", flush=True)
                time.sleep(wait)
                continue
            if r.status_code != 200 or not r.content:
                return None
            data = r.json()
            pages = data.get("query", {}).get("pages", {})
            for page in pages.values():
                url = page.get("thumbnail", {}).get("source")
                if url:
                    return url
            return None
        except Exception as e:
            print(f"  wiki_api_error: {e}")
            if attempt < retries - 1:
                time.sleep(2)
    return None


def download_image(url, retries=3):
    """Download an image and save to uploads/. Returns local path or None."""
    for attempt in range(retries):
        try:
            r = requests.get(url, headers=WIKI_DOWNLOAD_HEADERS, timeout=20, stream=True)
            if r.status_code == 429:
                wait = 3 * (attempt + 1)
                print(f"  [rate limit DL, espera {wait}s] ", end="", flush=True)
                time.sleep(wait)
                continue
            if r.status_code != 200:
                return None
            ct = r.headers.get("content-type", "")
            if "html" in ct or "text" in ct:
                return None
            ext = "jpg"
            if "png" in ct:
                ext = "png"
            elif "webp" in ct:
                ext = "webp"
            elif "gif" in ct:
                ext = "gif"
            elif "svg" in ct:
                ext = "svg"
            else:
                last = url.split("?")[0].rsplit(".", 1)
                if len(last) == 2 and last[1].lower() in ("jpg", "jpeg", "png", "webp", "gif", "svg"):
                    ext = last[1].lower()
            filename = f"{uuid.uuid4().hex}.{ext}"
            filepath = os.path.join(UPLOAD_DIR, filename)
            total = 0
            with open(filepath, "wb") as f:
                for chunk in r.iter_content(8192):
                    f.write(chunk)
                    total += len(chunk)
            if total < 500:
                os.remove(filepath)
                return None
            return f"/static/uploads/{filename}"
        except Exception as e:
            print(f"  download_error: {e}")
            if attempt < retries - 1:
                time.sleep(2)
    return None


def placeholder_url(name, category):
    """Generate a colored placehold.co URL for the product."""
    colors = CATEGORY_COLORS.get(category) or CATEGORY_COLORS.get(normalize(category))
    bg, fg = colors if colors else ("9E9E9E", "ffffff")
    label = normalize(name)[:20].replace(" ", "+")
    return f"https://placehold.co/400x400/{bg}/{fg}?text={label}"


def main():
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT id, name, category FROM products "
        "WHERE image_url IS NULL OR image_url = '' OR image_url LIKE '%placehold.co%' "
        "ORDER BY id"
    )
    products = cur.fetchall()
    print(f"Productos sin imagen: {len(products)}\n")

    ok_wiki = ok_placeholder = fail = 0

    for pid, name, category in products:
        print(f"[{pid}] {name}", end=" ... ", flush=True)

        article = wiki_article_for(name)
        wiki_url = None
        if article:
            wiki_url = get_wiki_image_url(article)
            time.sleep(1.0)  # respeta rate limit de Wikipedia

        if wiki_url:
            local = download_image(wiki_url)
            if local:
                cur.execute("UPDATE products SET image_url = ? WHERE id = ?", (local, pid))
                conn.commit()
                print(f"OK Wikipedia ({article}) -> {local}")
                ok_wiki += 1
                continue
            else:
                print(f"  [wiki DL failed, usando placehold] ", end="", flush=True)

        # Fallback: placehold.co (URL externa, sin descarga)
        ph = placeholder_url(name, category)
        cur.execute("UPDATE products SET image_url = ? WHERE id = ?", (ph, pid))
        conn.commit()
        print(f"placehold.co -> {ph[:70]}")
        ok_placeholder += 1

    conn.close()
    print(f"\nListo: {ok_wiki} Wikipedia, {ok_placeholder} placehold.co, {fail} sin imagen.")


if __name__ == "__main__":
    main()
