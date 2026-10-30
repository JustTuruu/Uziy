import { readFile } from "node:fs/promises";
import { describe, expect, it } from "vitest";
// @ts-expect-error -- a plain .mjs helper shared with the generate script
import { SCHEMA_PATH, schemaSource } from "../scripts/schema-source.mjs";

describe("generated API types", () => {
  it("match docs/api/openapi.json (run `pnpm -C packages/api-types generate` after ./gradlew updateOpenApi)", async () => {
    expect(await readFile(SCHEMA_PATH, "utf8")).toBe(await schemaSource());
  });
});
