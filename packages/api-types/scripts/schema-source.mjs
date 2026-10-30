// One place that turns docs/api/openapi.json into the text of src/schema.ts, shared by the
// generate script and the test that proves the committed file is current.
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import openapiTS, { astToString } from "openapi-typescript";

export const SPEC_PATH = fileURLToPath(new URL("../../../docs/api/openapi.json", import.meta.url));
export const SCHEMA_PATH = fileURLToPath(new URL("../src/schema.ts", import.meta.url));

const HEADER =
  "// GENERATED from docs/api/openapi.json by `pnpm -C packages/api-types generate`. Do not edit.\n" +
  "// The backend rewrites the spec with `./gradlew updateOpenApi`.\n\n";

export async function schemaSource() {
  const spec = JSON.parse(await readFile(SPEC_PATH, "utf8"));
  const ast = await openapiTS(spec, { exportType: true, alphabetize: true });
  return HEADER + astToString(ast);
}
