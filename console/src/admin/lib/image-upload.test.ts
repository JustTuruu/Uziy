import { afterEach, expect, it, vi } from "vitest";
import { adminApi, auth, mediaUrl } from "./api";
afterEach(() => { vi.unstubAllGlobals(); localStorage.clear(); });
it("sends multipart with auth and leaves the boundary to the browser", async () => {
  const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify({ thumbnailUrl: "/public/campaigns/1/image" })));
  vi.stubGlobal("fetch", fetch); auth.setToken("test-token");
  const file = new File(["png"], "cover.png", { type: "image/png" });
  await adminApi.uploadImage(1, file);
  const [url, init] = fetch.mock.calls[0];
  expect(url).toContain("/admin/campaigns/1/image");
  expect(init.headers.Authorization).toBe("Bearer test-token");
  expect(init.headers["Content-Type"]).toBeUndefined();
  expect(init.body).toBeInstanceOf(FormData);
  expect(init.body.get("file").name).toBe("cover.png");
});
it("resolves media from API host while keeping external URLs", () => {
  expect(mediaUrl("/public/campaigns/1/image?v=2")).toBe("http://localhost:8080/public/campaigns/1/image?v=2");
  expect(mediaUrl("https://cdn.example.com/a.png")).toBe("https://cdn.example.com/a.png");
});
