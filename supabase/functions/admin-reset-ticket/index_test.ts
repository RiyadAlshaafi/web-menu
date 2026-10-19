// Run: deno test --allow-env supabase/functions/admin-reset-ticket/index_test.ts
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { handle, ticketMessage } from "./index.ts";

const pair = (await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"])) as CryptoKeyPair;
const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
Deno.env.set("ADMIN_RESET_PRIVATE_KEY", btoa(String.fromCharCode(...pkcs8)));

const nonce = "ab".repeat(32);
const post = (body: unknown) =>
  new Request("http://local/admin-reset-ticket", { method: "POST", body: JSON.stringify(body) });
const fromHex = (hex: string) => Uint8Array.from(hex.match(/../g)!, (b) => parseInt(b, 16));

Deno.test("the right password gets a ticket the public key accepts", async () => {
  const response = await handle(post({ password: "seller", nonce }), async (p) => p === "seller");
  assertEquals(response.status, 200);
  const ticket = await response.json();
  assertEquals(ticket.nonce, nonce);
  assert(Math.abs(Date.parse(ticket.issued) - Date.now()) < 60_000, "issued is the server time");
  const ok = await crypto.subtle.verify("Ed25519", pair.publicKey, fromHex(ticket.sig),
    new TextEncoder().encode(ticketMessage(ticket.nonce, ticket.issued)));
  assert(ok, "the signature checks out");
});

Deno.test("a wrong password gets nothing", async () => {
  const response = await handle(post({ password: "guess", nonce }), async () => false);
  assertEquals(response.status, 403);
  assertEquals((await response.json()).sig, undefined);
});

Deno.test("a failed password check gets nothing", async () => {
  assertEquals((await handle(post({ password: "seller", nonce }), async () => null)).status, 502);
});

Deno.test("bad requests are refused before the password check", async () => {
  let checked = false;
  const check = async () => (checked = true);
  for (const body of [{ password: "seller", nonce: "short" }, { nonce }, { password: "", nonce }, "x"]) {
    assertEquals((await handle(post(body), check)).status, 400);
  }
  assertEquals((await handle(new Request("http://local/", { method: "GET" }), check)).status, 405);
  assert(!checked, "no password check for a bad request");
});
