// netlify/edge-functions/protect.mjs
import jwt from "jsonwebtoken";

const COOKIE_NAME = "driver_auth";

export default async (request, context) => {
  const url = new URL(request.url);

  // Only protect /drivers/*
  if (!url.pathname.startsWith("/drivers/")) return context.next();

  // pattern: /drivers/<name>.html
  const m = url.pathname.match(/^\/drivers\/([a-z0-9_-]+)\.html$/i);
  if (!m) return new Response("Not found", { status: 404 });

  const target = m[1].toLowerCase();

  // read cookie
  const cookieHeader = request.headers.get("cookie") || "";
  const token = cookieHeader
    .split(";")
    .map(v => v.trim())
    .find(v => v.startsWith(`${COOKIE_NAME}=`))
    ?.split("=")[1];

  if (!token) return Response.redirect(new URL("/login", url), 302);

  try {
    const JWT_SECRET = Deno.env.get("JWT_SECRET") || "CHANGE_ME_IN_NETLIFY_ENV";
    const payload = jwt.verify(token, JWT_SECRET);
    const user = (payload.user || "").toLowerCase();
    if (user !== target) return new Response("Unauthorized", { status: 401 });
    return context.next(); // OK
  } catch {
    return Response.redirect(new URL("/login", url), 302);
  }
};
