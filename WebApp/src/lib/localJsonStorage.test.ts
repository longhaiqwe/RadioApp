import { beforeEach, describe, expect, it, vi } from "vitest";
import { readJson, writeJson } from "./localJsonStorage";

describe("localJsonStorage", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("returns fallback when key is missing", () => {
    expect(readJson("missing", ["fallback"])).toEqual(["fallback"]);
  });

  it("writes and reads JSON", () => {
    writeJson("items", [{ id: "one" }]);
    expect(readJson("items", [])).toEqual([{ id: "one" }]);
  });

  it("returns fallback for invalid JSON", () => {
    window.localStorage.setItem("broken", "{");
    expect(readJson("broken", [])).toEqual([]);
  });

  it("swallows storage write failures", () => {
    const setItemSpy = vi
      .spyOn(Storage.prototype, "setItem")
      .mockImplementation(() => {
        throw new DOMException("QuotaExceededError", "QuotaExceededError");
      });

    expect(() => writeJson("items", [{ id: "one" }])).not.toThrow();

    setItemSpy.mockRestore();
  });
});
