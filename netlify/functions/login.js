// netlify/functions/login.js
import { USERS } from "./users.js";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { serialize } from "cookie";
import { createHash } from "crypto";

const COOKIE_NAME = "driver_auth";
const MAX_AGE = 60 * 60 * 8; // 8 hours

function isSha256Hex(x) {
  return typeof x === "string" && /^[0-9a-f]{64}$/i.test(x);
}
function sha256Hex(s) {
  return createHash("sha256").update(s, "utf8").digest("hex");
}

export async function handler(event) {
  if (event.httpMethod !== "POST") {
    return { statusCode: 405, body: "Method Not Allowed" };
  }

  const ct = event.headers["content-type"] || "";
  if (!ct.includes("application/x-www-form-urlencoded")) {
    return { statusCode: 400, body: "Bad Request" };
  }

  const params = new URLSearchParams(event.body);
  const username = (params.get("username") || "").toLowerCase().trim();
  const password = (params.get("password") || "").trim();

  const hash = USERS[username];
  if (!hash) {
    return { statusCode: 302, headers: { Location: "/login?error=nohash" }, body: "" };
  }

  // Accept both legacy SHA256 hex and bcrypt
  let ok = false;
  try {
    if (isSha256Hex(hash)) {
      ok = sha256Hex(password) === hash;
    } else {
      ok = bcrypt.compareSync(password, hash);
    }
  } catch (e) {
    // optional: add a minimal code to help debugging
    return { statusCode: 302, headers: { Location: "/login?error=compare" }, body: "" };
  }

  if (!ok) {
    return { statusCode: 302, headers: { Location: "/login?error=1" }, body: "" };
  }

  const JWT_SECRET = process.env.JWT_SECRET || "CHANGE_ME_IN_NETLIFY_ENV";
  const token = jwt.sign({ user: username }, JWT_SECRET, { expiresIn: MAX_AGE });

  const cookie = serialize(COOKIE_NAME, token, {
    httpOnly: true,
    secure: true,
    sameSite: "Lax",
    path: "/",
    maxAge: MAX_AGE
  });

  return {
    statusCode: 302,
    headers: { "Set-Cookie": cookie, Location: `/drivers/${username}.html` },
    body: ""
  };
}
