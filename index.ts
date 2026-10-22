import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { PDFDocument } from "https://esm.sh/pdf-lib@1.17.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "POST required." }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return reply({ error: "Server configuration is incomplete." }, 500);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const authHeader = req.headers.get("Authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  let userId: string | null = null;
  if (token && token !== anonKey) {
    const authClient = createClient(url, anonKey, { auth: { persistSession: false } });
    const { data } = await authClient.auth.getUser(token);
    userId = data.user?.id || null;
  }

  let input: { resource_id?: string; mode?: string };
  try { input = await req.json(); } catch { return reply({ error: "Invalid request body." }, 400); }
  const resourceId = input.resource_id;
  const mode = input.mode || "view";
  if (!resourceId || !["view", "download", "preview"].includes(mode)) return reply({ error: "Missing document or invalid access mode." }, 400);

  const { data: resource, error: resourceError } = await admin
    .from("resources")
    .select("id,title,price_ugx,file_path,status")
    .eq("id", resourceId)
    .eq("status", "approved")
    .maybeSingle();
  if (resourceError || !resource) return reply({ error: "Document not found or not approved." }, 404);
  if (!resource.file_path) return reply({ error: "This resource has no attached file." }, 404);

  const paid = Number(resource.price_ugx || 0) > 0;
  if (mode === "download" && !userId) return reply({ error: "Sign in or create an account to download this document." }, 401);
  if (paid && mode !== "preview") {
    if (!userId) return reply({ error: "Create an account or sign in to continue reading this paid document." }, 401);
    const { data: purchase } = await admin.from("document_purchases")
      .select("id,status")
      .eq("user_id", userId)
      .eq("resource_id", resource.id)
      .eq("status", "approved")
      .maybeSingle();
    if (!purchase) return reply({ error: "Full access has not been approved for this account yet." }, 403);
  }

  const { data: file, error: storageError } = await admin.storage.from("education-files").download(resource.file_path);
  if (storageError || !file) return reply({ error: "The document file could not be retrieved." }, 500);

  let bytes = new Uint8Array(await file.arrayBuffer());
  if (paid && mode === "preview") {
    try {
      const original = await PDFDocument.load(bytes);
      const preview = await PDFDocument.create();
      const pageCount = Math.min(2, original.getPageCount());
      const copied = await preview.copyPages(original, Array.from({ length: pageCount }, (_, i) => i));
      copied.forEach(page => preview.addPage(page));
      bytes = await preview.save();
    } catch {
      return reply({ error: "A two-page preview is available for PDF documents only. Please sign in to request full access." }, 415);
    }
  }

  const disposition = mode === "download" ? "attachment" : "inline";
  const safeName = String(resource.title || "wrytole-document").replace(/[^a-z0-9_-]+/gi, "-").slice(0, 80) || "wrytole-document";
  return new Response(bytes, {
    status: 200,
    headers: {
      ...cors,
      "Content-Type": "application/pdf",
      "Content-Disposition": `${disposition}; filename="${safeName}.pdf"`,
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
});
