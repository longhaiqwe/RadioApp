import { beforeEach, describe, expect, it, vi } from "vitest";
import { createSupabaseAdminClient } from "./supabaseAdmin";

const createClientMock = vi.fn();

vi.mock("@supabase/supabase-js", () => ({
  createClient: (...args: unknown[]) => createClientMock(...args),
}));

describe("createSupabaseAdminClient", () => {
  const originalEnv = { ...process.env };

  beforeEach(() => {
    vi.clearAllMocks();
    process.env = { ...originalEnv };
    delete process.env.SUPABASE_URL;
    delete process.env.SUPABASE_SERVICE_ROLE_KEY;
    delete process.env.SUPABASE_SECRET_KEY;
  });

  it("prefers the service-role key when present", () => {
    process.env.SUPABASE_URL = "https://example.supabase.co";
    process.env.SUPABASE_SERVICE_ROLE_KEY = "service-role-key";
    process.env.SUPABASE_SECRET_KEY = "legacy-key";

    createSupabaseAdminClient();

    expect(createClientMock).toHaveBeenCalledWith(
      "https://example.supabase.co",
      "service-role-key",
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      },
    );
  });

  it("falls back to the legacy secret key name", () => {
    process.env.SUPABASE_URL = "https://example.supabase.co";
    process.env.SUPABASE_SECRET_KEY = "legacy-key";

    createSupabaseAdminClient();

    expect(createClientMock).toHaveBeenCalledWith(
      "https://example.supabase.co",
      "legacy-key",
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      },
    );
  });

  it("throws when the server env is incomplete", () => {
    process.env.SUPABASE_URL = "https://example.supabase.co";

    expect(() => createSupabaseAdminClient()).toThrow(
      "Missing Supabase server environment variables",
    );
  });
});
