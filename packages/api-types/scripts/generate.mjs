import { writeFile } from "node:fs/promises";
import { SCHEMA_PATH, schemaSource } from "./schema-source.mjs";

await writeFile(SCHEMA_PATH, await schemaSource());
console.log(`wrote ${SCHEMA_PATH}`);
