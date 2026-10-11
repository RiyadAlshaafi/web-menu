"use client";

import { useSyncExternalStore } from "react";

// Values kept in this browser's localStorage or sessionStorage, readable during render without
// a hydration mismatch (the server snapshot is the fallback). Writes notify every reader.
type Kind = "local" | "session";
const listeners = new Set<() => void>();

function area(kind: Kind): Storage | null {
  try {
    return kind === "local" ? window.localStorage : window.sessionStorage;
  } catch {
    return null;
  }
}

export function readRaw(kind: Kind, key: string): string | null {
  try {
    return area(kind)?.getItem(key) ?? null;
  } catch {
    return null;
  }
}

export function writeRaw(kind: Kind, key: string, value: string | null): void {
  try {
    if (value === null) area(kind)?.removeItem(key);
    else area(kind)?.setItem(key, value);
  } catch {
    // Private mode or full storage.
  }
  listeners.forEach((notify) => notify());
}

function subscribe(notify: () => void) {
  listeners.add(notify);
  const onStorage = () => notify();
  window.addEventListener("storage", onStorage);
  return () => {
    listeners.delete(notify);
    window.removeEventListener("storage", onStorage);
  };
}

// Raw string snapshot (stable between renders); callers parse it with useMemo.
export function useStoredRaw(kind: Kind, key: string): string | null {
  return useSyncExternalStore(
    subscribe,
    () => readRaw(kind, key),
    () => null,
  );
}
