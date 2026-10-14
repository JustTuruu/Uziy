import { afterEach, expect, it, vi } from "vitest";
import { auth, companyApi, mediaUrl } from "./api";

afterEach(() => {
  vi.unstubAllGlobals();
  localStorage.clear();
});

it("uploads the cover as multipart with auth, leaving the boundary to the browser", async () => {
  const fetch = vi.fn().mockResolvedValue(
    new Response(JSON.stringify({ thumbnailUrl: "/public/campaigns/7/image" })),
  );
  vi.stubGlobal("fetch", fetch);
  auth.setToken("test-token");
  const file = new File(["png"], "cover.png", { type: "image/png" });

  await companyApi.uploadImage(7, file);

  const [url, init] = fetch.mock.calls[0];
  expect(url).toContain("/company/campaigns/7/image");
  expect(init.method).toBe("POST");
  expect(init.headers.Authorization).toBe("Bearer test-token");
  expect(init.headers["Content-Type"]).toBeUndefined();
  expect(init.body).toBeInstanceOf(FormData);
  expect(init.body.get("file").name).toBe("cover.png");
});

it("removes the cover with DELETE", async () => {
  const fetch = vi.fn().mockResolvedValue(
    new Response(JSON.stringify({ thumbnailUrl: null })),
  );
  vi.stubGlobal("fetch", fetch);

  await companyApi.removeImage(7);

  const [url, init] = fetch.mock.calls[0];
  expect(url).toContain("/company/campaigns/7/image");
  expect(init.method).toBe("DELETE");
});

it("a JSON request still sends JSON", async () => {
  const fetch = vi.fn().mockResolvedValue(new Response("{}"));
  vi.stubGlobal("fetch", fetch);

  await companyApi.create({ title: "x" } as never);

  const init = fetch.mock.calls[0][1];
  expect(init.headers["Content-Type"]).toBe("application/json");
  expect(init.body).toBe(JSON.stringify({ title: "x" }));
});

it("resolves media paths against the API host and keeps full URLs", () => {
  expect(mediaUrl("/public/campaigns/1/image?v=2")).toBe(
    "http://localhost:8080/public/campaigns/1/image?v=2",
  );
  expect(mediaUrl("https://cdn.example.com/a.png")).toBe(
    "https://cdn.example.com/a.png",
  );
});
