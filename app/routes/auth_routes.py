"""
auth_routes.py — Rutas de autenticación básica.
Login/logout con sesión Flask + endpoint JSON para apps móviles.
"""
from flask import Blueprint, render_template, request, redirect, url_for, session, flash, jsonify

auth_bp = Blueprint("auth", __name__)

# Credenciales hardcodeadas para demo (en producción usar BD + hash)
DEMO_USER = "admin"
DEMO_PASS = "admin123"

@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        if request.form["username"] == DEMO_USER and request.form["password"] == DEMO_PASS:
            session["user"] = DEMO_USER
            return redirect(url_for("analytics.dashboard"))
        flash("Credenciales incorrectas", "error")
    return render_template("login.html")

@auth_bp.route("/api/auth/login", methods=["POST"])
def api_login():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "JSON inválido"}), 400
    username = (data.get("username") or "").strip()
    password = (data.get("password") or "").strip()
    if username == DEMO_USER and password == DEMO_PASS:
        return jsonify({"ok": True, "user": username, "token": "demo-token-2024"}), 200
    return jsonify({"error": "Credenciales incorrectas"}), 401

@auth_bp.route("/logout")
def logout():
    session.pop("user", None)
    return redirect(url_for("auth.login"))

@auth_bp.route("/")
def index():
    if "user" in session:
        return redirect(url_for("analytics.dashboard"))
    return redirect(url_for("auth.login"))
