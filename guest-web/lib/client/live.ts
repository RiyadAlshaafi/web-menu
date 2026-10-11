// Live pings from Supabase Realtime: public broadcasts that carry only the changed table's
// name, never row data (supabase/migrations/20261013100000_live_update_pings.sql). The client
// library is loaded after the page is interactive so it stays out of the first bundle.
export type Ping = { topic: string; table: string };

export function subscribeLive(topics: string[], onPing: (ping: Ping) => void): () => void {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key || topics.length === 0) return () => {};
  let stopped = false;
  let cleanup = () => {};
  import("@supabase/realtime-js")
    .then(({ RealtimeClient }) => {
      if (stopped) return;
      const client = new RealtimeClient(`${url.replace(/\/+$/, "")}/realtime/v1`, { params: { apikey: key } });
      const channels = topics.map((topic) =>
        client
          .channel(topic, { config: { broadcast: { self: false }, private: false } })
          .on("broadcast", { event: "change" }, (message: { payload?: { table?: unknown } }) => {
            const table = typeof message.payload?.table === "string" ? message.payload.table : "";
            onPing({ topic, table });
          })
          .subscribe(),
      );
      cleanup = () => {
        for (const channel of channels) void client.removeChannel(channel);
        client.disconnect();
      };
    })
    .catch(() => {
      // Realtime unavailable: the page keeps polling.
    });
  return () => {
    stopped = true;
    cleanup();
  };
}

// cafe:<id> pings fire for every change in the cafe; only these change what a guest sees on
// the menu (decision Q6: staff changes reach the guest within seconds).
export const MENU_TABLES = new Set(["restaurants", "menu_items", "menu_categories", "payment_types"]);
