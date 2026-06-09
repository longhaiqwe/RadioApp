export const LOCAL_JSON_STORAGE_EVENT = "radioapp:local-json-storage";

export function readJson<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;

  try {
    const raw = window.localStorage.getItem(key);
    if (raw === null) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export function writeJson<T>(key: string, value: T): void {
  if (typeof window === "undefined") return;

  try {
    window.localStorage.setItem(key, JSON.stringify(value));
    window.dispatchEvent(
      new CustomEvent(LOCAL_JSON_STORAGE_EVENT, {
        detail: { key },
      })
    );
  } catch {
    // Ignore storage write failures in restricted browser modes.
  }
}

export function subscribeJsonStorage(
  key: string,
  onChange: () => void
): () => void {
  if (typeof window === "undefined") {
    return () => {};
  }

  const handleStorage = (event: StorageEvent) => {
    if (event.key === null || event.key === key) {
      onChange();
    }
  };

  const handleLocalEvent = (
    event: Event & { detail?: { key?: string } }
  ) => {
    if (event.detail?.key === key) {
      onChange();
    }
  };

  window.addEventListener("storage", handleStorage);
  window.addEventListener(
    LOCAL_JSON_STORAGE_EVENT,
    handleLocalEvent as EventListener
  );

  return () => {
    window.removeEventListener("storage", handleStorage);
    window.removeEventListener(
      LOCAL_JSON_STORAGE_EVENT,
      handleLocalEvent as EventListener
    );
  };
}
